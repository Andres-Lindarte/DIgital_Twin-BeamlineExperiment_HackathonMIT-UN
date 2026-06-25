-- traputil.lua - Functionality shared by the ion trap demo programs.
--
-- This file provides various shared variables and global functions
-- useful for the ion trap demos.
--
-- D.Manura-2006-08 - based on PRG code from SIMION 7.0 - David A. Dahl 1995
-- (c) 2006 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)
--=======================================================================

-- if checkglobals then checkglobals() end

local TRAP = {}
TRAP.segment = {}
TRAP.randomize_x = true -- whether to randomize pariticle X positions

---- adjustable during flight

-- ion trap voltage control
adjustable _qz_tune           = 0.8      -- Mathieu Qz tuning point
adjustable _az_tune           = 0.0      -- Mathieu Az tuning point
adjustable _amu_mass_per_charge = 100.0  -- mass tune point (amu/esu)
adjustable _target_voltage    = 0.0      -- sims target voltage
adjustable _left_cap_voltage  = 0.0      -- left cap voltage
adjustable _right_cap_voltage = 0.0      -- right cap voltage

---- adjustable at beginning of flight

-- particle initial conditions
adjustable percent_energy_variation = 90.0  -- randomized ion energy variation
                                            --   (+- %)
adjustable cone_angle_off_vel_axis  = 180.0 -- randomized ion trajectory cone
                                            --   angle (+- degrees)
adjustable random_offset_mm         = 0.1   -- randomized initial ion offset
                                            --   position (in mm) with
                                            --   mid-point at zero offset.
adjustable random_tob = 0.909091            -- max randomized time of birth
                                            --  over one cycle (usec)

-- voltage control
adjustable phase_angle_deg          = 0.0   -- entry phase angle of ion (deg)
adjustable freqency_hz              = 1.1E6 -- RF frequency of quad in (hz)
adjustable effective_radius_in_cm   = 0.41  -- effective quad radius r0 (cm)

-- display
adjustable pe_update_each_usec      = 0.05  -- PE display update time step
                                            -- (usec)


-- Trigger periodic PE surface display updates.
-- This is designed to be called inside a SIMION other_actions segment.
local next_pe_update = 0.0 -- next time to update PE surface
local function pe_update()
    -- If TOF reached next PE display update time...
    if ion_time_of_flight >= next_pe_update then
        -- Request a PE surface display update.
        sim_update_pe_surface = 1
        -- Schedule next PE display update time (usec).
        next_pe_update = ion_time_of_flight + pe_update_each_usec
    end
end


-- Randomize ion's position, KE, and direction.
-- This is designed to be called inside a SIMION initialize segment.
-- For a more detailed discussion of the following code, see SIMION's
-- "random" example.
local function randomize_particles()
    -- Ensure 0 <= percent_energy_variation <= 100.
    percent_energy_variation = min(abs(percent_energy_variation), 100)
    -- Ensure 0 <= cone_angle_off_vel_axis <= 180.
    cone_angle_off_vel_axis = min(abs(cone_angle_off_vel_axis), 180)

    -- Convert ion velocity vector to 3-D polar coordinates.
    local speed, az_angle, el_angle
        = rect3d_to_polar3d(ion_vx_mm, ion_vy_mm, ion_vz_mm)

    -- Randomize ion's defined KE.
    local ke = speed_to_ke(speed, ion_mass)
        * (1 + (percent_energy_variation / 100) * (2 * rand() - 1))
    -- Convert new KE back to ion speed, and set it.
    speed = ke_to_speed(ke, ion_mass)
 

    -- Now, to randomize the ion velocity direction, we first
    -- make the ion's possible random velocity directions fill a solid cone
    -- with vertex at the origin and axis oriented along the positive y-axis.
    -- The angle that the cone side makes with the cone axis will be
    -- the cone_angle_off_vel_axis value.

    -- randomize elevation angle: (90 +- cone_angle_off_vel_axis)
    local new_el = 90 + cone_angle_off_vel_axis * (2*rand()-1)
    -- randomize azimuth angle: (0 +-90)
    local new_az = 90 * (2*rand()-1)
 
    -- Now that we generated this randomized cone, we will rotate it
    -- so that the expected ion velocity direction matches the ion's
    -- original velocity direction.

    -- Convert to rectangular velocity components.
    local x, y, z = polar3d_to_rect3d(speed, new_az, new_el)
    -- Rotate back to defined elevation.
    x, y, z = elevation_rotate(-90 + el_angle, x, y, z)
    -- Rotate back to defined azimuth.
    ion_vx_mm, ion_vy_mm, ion_vz_mm = azimuth_rotate(az_angle, x, y, z)
 
 
    -- Randomize ion's position components.
    if TRAP.randomize_x then
        ion_px_mm = ion_px_mm + random_offset_mm * (rand() - (1/2))
    end
    ion_py_mm = ion_py_mm + random_offset_mm * (rand() - (1/2))
    ion_pz_mm = ion_pz_mm + random_offset_mm * (rand() - (1/2))
 
    -- Randomize ion's time of birth.
    ion_time_of_birth = abs(random_tob) * rand()
end


-- Default SIMION initialize segment for ion trap example.
-- This segment is called on every particle creation.
function TRAP.segment.initialize()
    -- Enable rerun mode (used only for side-effect of disabling trajectory
    -- file saving).
    sim_rerun_flym = 1

    randomize_particles()
end


-- Default SIMION fast_adjust segment for ion trap example.
-- This segment is called to modify electrode voltages.
local is_first  = true   -- first call flag
local scaled_rf = 0.0    -- scaled RF base
local omega     = 1.0    -- frequency (rad/usec)
local theta     = 0.0    -- phase offset (rad)
function TRAP.segment.fast_adjust()
    ---- Generate trap RF voltages with fast adjust.

    -- For efficiency, we calculate some variables only once.
    if is_first then
        is_first = false
 
        -- scaled_rf is the scaling constant (1/4)w^2r0^2 used in
        -- the equations for DC and RF voltages U and V below.
        -- We include in it a conversion factor for SIMION units:
        --   conversion_factor ~= (1/4) * (1.66053886*10^-27 kg/amu) *
        --                                (1.602176462*10^-19 C/e)^-1 *
        --                                (2*PI rad/cycle)^2 *
        --                                (0.01 m/cm)^2
        --                     ~= 1.02291E-11 ~= 1.022442E-11
        scaled_rf = 1.022442E-11 * freqency_hz^2 * effective_radius_in_cm^2

        theta = rad(phase_angle_deg)              -- phase angle (rad)
        omega = freqency_hz * 2 * 3.14159 * 1E-6  -- frequency (rad/usec)
    end

    -- Calculate DC and RF voltages U and V from tuning factors.
    -- This uses the standard equations
    --   U = -(a_z/8)(m/e)w^2r0^2      (DC factor)
    --   V =  (q_z/4)(m/e)w^2r0^2      (RF factor)
    -- where
    --   w is angular frequency 2*PI*f given frequency f;
    --   r0 is radius of ring electrode.
    --   2*z0 is distance between end cap electrodes.
    --   r0^2 = 2*z0^2 as required for ideal (non-stretched) trap.
    -- Note: values are recalculated since the dependent variables can
    -- be adjusted during the simulation.
    local dcvolts = - 0.5 * scaled_rf * _amu_mass_per_charge * _az_tune
    local rfvolts =         scaled_rf * _amu_mass_per_charge * _qz_tune

    -- Set electrode voltages.
    adj_elect01 = _left_cap_voltage
    adj_elect03 = _right_cap_voltage
    adj_elect04 = _target_voltage
    adj_elect02 = dcvolts + rfvolts * sin(theta + ion_time_of_flight * omega)
end


-- Default SIMION time_step adjust segment for ion trap example.
-- This segment is called to override time-step size.
function TRAP.segment.tstep_adjust()
    -- Keep time step <= 0.1 usec.
    if ion_time_step > 0.1 then ion_time_step = 0.1 end
end


-- Default SIMION other_actions segment for ion trap example.
-- This segment is called on every time-step.
TRAP.segment.other_actions = pe_update


-- Default SIMION terminate segment for ion trap example.
-- This segment is called on each particle termination.
function TRAP.segment.terminate()
    -- Disable rerun mode from initialize segment
    -- (we don't really want to rerun)
    sim_rerun_flym = 0
end


-- segments is a list of tables that map segment name to segment function.
-- This merges those segments and returns a single segment map.
function TRAP.merge_segments(segments)
    local seg_merged = {}

    -- Get set of segment names.
    local is_name = {}
    for _,seg in ipairs(segments) do
        for name in pairs(seg) do
            is_name[name] = true
        end
    end

    -- Merge segments.
    for name in pairs(is_name) do
        local f_list = {}  -- list of functions
        for _,seg in ipairs(segments) do
            f_list[#f_list+1] = seg[name]
        end
        local f_merged  -- merged function
        if #f_list == 1 then
            f_merged = f_list[1]
        else
            f_merged = function()
                for i=1,#f_list do
                    f_list[i]()
                end
            end
        end
        seg_merged[name] = f_merged
    end

    return seg_merged
end


-- Merge and install SIMION segments.
-- segments is a list of tables that map segment name to segment function.
--
-- Example:
--   TRAP.install { {initialize = f1}, {initialize = f2, other_actions = f3} }
function TRAP.install_segments(segments)
    local seg = TRAP.merge_segments(segments)
    for name,f in pairs(seg) do
        segment[name] = f
    end
end


return TRAP
