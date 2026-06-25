--[[
 quad.lua - SIMION Lua workbench program for quadrupole simulation.
 This oscillates quadrupole rod potentials

 Based on "quad" example (see that example for more details).
 (c) 2006-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()

local C = require 'simionx.Constants'
 
adjustable _percent_tune          =    99.8  -- percent of optimum tune.
                                             -- (typically just under 100)
adjustable _amu_mass_per_charge   =   100.0  -- mass/charge tune point (u/e)
                                             -- (particles of this m/z pass)
adjustable _quad_axis_voltage     =    -8.0  -- quad axis voltage

adjustable effective_radius_in_cm   = 0.5    -- half the distance between rods (cm)
adjustable phase_angle_deg          = 0.0    -- quad entry phase angle of ion (deg)
adjustable freqency_hz              = 1.1E6  -- RF frequency of quad (Hz)

adjustable max_time = 100  -- microseconds

local q_max = 0.70600         -- Mathieu max stable q (estimated)
local a_max = 0.23699         -- Mathieu max stable a (estimated)
local unit_convert =
  C.UNIFIED_MASS_KG           -- kg/u
  * C.ELEMENTARY_CHARGE_C^-1  -- (C/e)^-1
  * (2*math.pi)^2             -- (rad/cycle)^2
  * (0.01)^2                  -- (m/cm)^2
local const = (1/4)*unit_convert*q_max
--print('constant=', const)

function segment.load()
  -- Set grouped flying and T.Qual = 0 as defaults on load.
  sim_trajectory_quality = 0
  sim_grouped = 1
end

function segment.fast_adjust()
    local scaled_rf = effective_radius_in_cm^2 * freqency_hz^2 * const
    local theta = phase_angle_deg * (math.pi / 180)   -- radians
    local omega = freqency_hz * (1E-6 * 2 * math.pi)  -- radians/usec

    local rfvolts = scaled_rf * _amu_mass_per_charge
    local dcvolts = rfvolts * _percent_tune * ((1/100) * (1/2)*(a_max/q_max))
    local tempvolts = sin(ion_time_of_flight * omega + theta) * rfvolts + dcvolts

    -- Finally, apply adjustable voltages to rod electrodes.
    adj_elect01 = _quad_axis_voltage + tempvolts
    adj_elect02 = _quad_axis_voltage - tempvolts
end

function segment.tstep_adjust()
   -- Keep time step size <= X usec.
   ion_time_step = min(ion_time_step, 0.1)  -- X usec
end

function segment.other_actions()
  -- Prevent simulation from running forever.
  if ion_time_of_flight > max_time then
    print('prematurely terminating ion at time', max_time)
    ion_splat = 1
  end
end
