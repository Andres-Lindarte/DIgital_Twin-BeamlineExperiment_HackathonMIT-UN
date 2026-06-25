--[[
 SIMION Lua workbench program for octupole simulation with space-charge
 (using Poisson solver and piclib).
 
 The octupole rod oscillation is taken from the "octuopole" example.
 See that example for further details.

 D.Manura-2011-12,2007-09
 (c) 2007-2011 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]

simion.workbench_program()

-- Load particle-in-cell (PIC) code.
local PIC = simion.import "../piclib.lua"
PIC.load('current')

adjustable PIC_enable
adjustable PIC_iterations = 5
adjustable PIC_refine_convergence

-- Average A per mm in z per particle.
-- ion_cwf units are A (3D and 2D cylindrical) or A/mm in z (2D planar).
adjustable A_per_mm_per_particle =
  0.02E-6        -- total current (A)
   / 20          -- length of current (mm) in Z direction
   / 100         -- number of particles (unitless)
   / 2           -- divide by 2 for y mirroring since -y particles also
                 --   deposit into +y region of space-charge array.
   / 2           -- divide by 2 for z mirroring since -z particles also
                 --   deposit into +z region of space-charge array.

adjustable phase_angle_deg = 0.0    -- entry phase angle of ion (deg)
adjustable frequency_hz   = 1.1E6  -- RF frequency (Hz)
adjustable rfvolts = 100    -- RF voltage for octupole
adjustable dcvolts = 0      -- DC voltage for octupole; typically zero for RF-only octupoles

function segment.initialize_run()
  print('A_per_mm_per_particle=', A_per_mm_per_particle)
  PIC.segment.initialize_run()
end

function segment.initialize()
  PIC.segment.initialize()
  -- Assign charge to particle (used by PIC Poisson solving code).
  if PIC_enable ~= 0 then
    ion_cwf = A_per_mm_per_particle
  end
end

-- called to override time-step size on each time-step.
function segment.tstep_adjust()
   -- Keep time step size <= X usec.
   ion_time_step = min(ion_time_step, 0.1)  -- X usec
end

-- called to set adjustable electrode voltages
function segment.fast_adjust()
  local omega = frequency_hz * (1E-6 * 2 * math.pi)
  local theta = phase_angle_deg * (math.pi / 180)
  local tempvolts = sin(ion_time_of_flight * omega + theta) * rfvolts + dcvolts

  -- Apply adjustable voltages to rod electrodes.
  adj_elect01 =   tempvolts
  adj_elect02 = - tempvolts
end

function segment.terminate_run()
  PIC.segment.terminate_run()
  print('end of run', ion_run, 'V0=', simion.wb.instances[2].pa:potential(0,0,0))
end
