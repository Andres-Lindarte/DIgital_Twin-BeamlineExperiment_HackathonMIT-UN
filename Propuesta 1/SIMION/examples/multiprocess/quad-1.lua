-- quad-1.lua
-- SIMION Lua workbench program illustrating how to teleport particles
-- between PAs running on different communicating SIMION processes
-- (instances of simion.exe in memory).
--
-- See the README.html for details on this example.
--
-- This particular example is based on the "quad" example on SIMION.
-- The source comments from that example have been largely removed in
-- the interest of simplicity to focus attention only on the details
-- of particle teleportation.  Refer to the comments in the regular
-- "quad" example for details specific to quadrupole simulations.
--
-- [1] http://en.wikipedia.org/wiki/Teleportation
--
-- D.Manura-2008-03.
-- (c) 2008 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)

simion.workbench_program()

-- SIMION process number.  This is a unique number that identifies the
-- current SIMION process and differentiates it from the others.
local simion_number = simion_number or 1

-- See the regular quad example for an explanation of these variables. 
adjustable _percent_tune          =    97.0
adjustable _amu_mass_per_charge   =   100.0
adjustable _quad_entrance_voltage =     0.0
adjustable _quad_axis_voltage     =    -8.0
adjustable _quad_exit_voltage     =  -100.0
adjustable _detector_voltage      = -1500.0
adjustable pe_update_each_usec      = 0.05 
adjustable effective_radius_in_cm   = 0.40
adjustable phase_angle_deg          = 0.0
adjustable freqency_hz              = 1.1E6
local scaled_rf
local omega
local theta
local last_pe_update = 0.0

-- Load and configure the ion teleportation code.
local teleportutil = simion.import "teleportutil.lua" {
    -- See the comments in teleportutil.lua above "configure" for an
    -- explanation of these parameters.  You would need to adjust
    -- these if you modifies the numbers of PA instances or numbers or
    -- locations of SIMION processes.
    jumps = {
        [1] = {[1] = 2               };
        [2] = {[1] = 'pause', [2] = 1};
    };
    addresses = {
        [1] = '127.0.0.1:54001';
        [2] = '127.0.0.1:54002';
    };
    simion_number = simion_number;
}

-- SIMION calls this segment when initializing an ion inside
-- a PA instance.
function segment.initialize()

    -- Call teleportation code.
    teleportutil.initialize()
end

-- SIMION calls this segment at the start of ion flight for each
-- potential array instance to initialize adjustable electrode
-- voltages.
function segment.init_p_values()

    -- See comments in original quad.lua (slightly modified
    -- by testing on simion_number rather than ion_instance).
    if simion_number == 1 then      -- entrance PA
        adj_elect03 = _quad_entrance_voltage
    elseif simion_number == 3 then  -- exit PA
        adj_elect03 = _quad_exit_voltage
        adj_elect04 = _detector_voltage
    end
end

-- SIMION calls this segment during ion flight to set adjustable
-- electrode voltages (in the current potential array instance).
function segment.fast_adjust()

    -- See comments in original quad.lua.
    if not scaled_rf then
        scaled_rf = effective_radius_in_cm^2 * freqency_hz^2 * 7.11016e-12
        theta = phase_angle_deg * (math.pi / 180)
        omega = freqency_hz * (1E-6 * 2 * math.pi)
    end
    local rfvolts = scaled_rf * _amu_mass_per_charge
    local dcvolts = rfvolts * _percent_tune * ((1/100) * 0.1678399)
    local tempvolts = sin(ion_time_of_flight * omega + theta)*rfvolts + dcvolts
    adj_elect01 = _quad_axis_voltage + tempvolts
    adj_elect02 = _quad_axis_voltage - tempvolts
end

-- SIMION calls this segment at the end of each time-step.
function segment.other_actions()

    -- Call teleportation code.
    teleportutil.other_actions()

    -- See comments in original quad.lua.
    if abs(ion_time_of_flight - last_pe_update) >= pe_update_each_usec then
        last_pe_update = ion_time_of_flight
        sim_update_pe_surface = 1
    end
end

-- SIMION calls this segment after proposing a time-step size,
-- allowing the time-step size to be changed.
function segment.tstep_adjust()

    -- See comments in original quad.lua.
    ion_time_step = min(ion_time_step, 0.1)
end

