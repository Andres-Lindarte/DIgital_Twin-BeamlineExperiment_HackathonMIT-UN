--[[
 SIMION Lua workbench program for octupole simulation.
 This oscillates octupole rod potentials
 (and also updates PE display periodically).

 D.Manura-2007-09
 (c) 2007 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)
--]]

simion.workbench_program()

-- Variables adjustable during flight:

adjustable pe_update_each_usec      = 0.05   -- potential energy display
                                             -- update period (microsec)
                                             -- (for display purposes only)

-- Variables adjustable only at beginning of flight:

adjustable effective_radius_mm      = 3.0    -- half the minimum distance between
                                             -- opposite rods (mm)
adjustable phase_angle_deg          = 0.0    -- entry phase angle of ion (deg)
adjustable _frequency_hz            = 1.1E6  -- RF frequency (Hz)

adjustable _rfvolts = 100    -- RF voltage for octupole
adjustable _dcvolts = 0      -- DC voltage for octupole;
                             --    typically zero for RF-only octupoles

-- internal variables
local last_pe_update = 0.0 -- last potential energy surface update time (usec)


-- SIMION segment called by SIMION to set adjustable electrode voltages
-- in the current potential array instance.
-- NOTE: this is called frequently, multiple times per time-step (by
-- Runge-Kutta), so performance concerns here can be important.
function segment.fast_adjust()
  local omega = _frequency_hz * (1E-6 * 2 * math.pi)
  local theta = phase_angle_deg * (math.pi / 180)

  local tempvolts =
    sin(ion_time_of_flight * omega + theta) * _rfvolts + _dcvolts

  -- Apply adjustable voltages to rod electrodes.
  adj_elect01 =   tempvolts
  adj_elect02 = - tempvolts
end
-- See also the README.html for how memory usage might be further
-- reduced by 1/3 or 2/3 by sharing electrode solution arrays.


-- SIMION segment called by SIMION after every time-step.
local is_initialized
function segment.other_actions()
  if not is_initialized then
    -- Convert to SI units.
    local q = ion_charge * 1.602176462*10^-19 -- (C/e)
    local m = ion_mass * 1.66053886*10^-27    -- (kg/u)
    local omega = _frequency_hz * 2 * math.pi -- (rad/cycle)
    local r0 = effective_radius_mm / 1000 -- (m/mm)

    -- Compute octupole stability constants [Hagg 1986]
    local a4 = 32 * q * _dcvolts / (m * omega^2 * r0^2)
    local q4 = 16 * q * _rfvolts / (m * omega^2 * r0^2)

    -- Print stability constants.
    print(string.format("m/z=%g,a4=%g,q4=%g", ion_mass/ion_charge, a4, q4))
    is_initialized = true -- only execute once
  end

  -- Update potential energy surface display periodically.
  -- The performance overhead of this in non-PE views is only a few percent.
  -- NOTE: the value inside abs(...) can be negative when a new ion is flown.
  if abs(ion_time_of_flight - last_pe_update) >= pe_update_each_usec then
    last_pe_update = ion_time_of_flight
    sim_update_pe_surface = 1    -- Request a PE surface display update.
  end
end

-- SIMION segment called by SIMION to override time-step size on each time-step.
function segment.tstep_adjust()
   -- Keep time step size <= X usec.
   ion_time_step = min(ion_time_step, 0.1)  -- X usec
end
