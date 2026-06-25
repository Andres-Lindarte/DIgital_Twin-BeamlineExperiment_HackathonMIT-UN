--[[
 squarewavelib.lua - Simple square waveform generation.
 v2012-12-01, D.Manura
 (c) 2007-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]
 
local M = {}
M.segment = {}

-- Period of waveform (usec)
adjustable wave_period = 2.0
-- Fraction of period waveform is at high voltage.
adjustable wave_duty = 0.25
-- Dispersion voltage
adjustable wave_DV = 750
-- Compensation voltage
adjustable wave_CV = 0
-- Minimum number of time-steps per waveform period.
-- Overrides T.Qual if non-zero.
adjustable wave_timesteps = 1

local TOL = 1E-10   -- [2]
assert(TOL >= 1E-16)

function M.segment.fast_adjust()
  local Vlow = - wave_DV * (wave_duty / (1 - wave_duty))
  local f = ((ion_time_of_flight) / wave_period) % 1
  local V = f < wave_duty and wave_DV or Vlow
  --print('V=',V, 't=', ion_time_of_flight, ion_time_step, ion_px_mm)
  adj_elect[2] = wave_CV + V
end

-- Improves time-step accuracy, causing time-steps to to end closer to
-- pulse edges.
local min = math.min
function M.segment.tstep_adjust()
  -- Initially, increase time-step to a fraction of the RF period.
  if wave_timesteps ~= 0 then
    ion_time_step = wave_period / wave_timesteps
  end

  -- voltage transition points as a fraction of wave_period.
  local f1 = wave_duty
  local f2 = 1

  -- current fraction of wave period.
  local f = (ion_time_of_flight / wave_period) % 1

  -- Reduce time step to hit next transition point.
  -- Set the flag _G.transition to true iff this is
  -- one of the tiny voltage transition time steps.
  if f < TOL then
    ion_time_step = 3*TOL   --[*1]
  elseif f < f1 - TOL then
    local next = (f1 - f) * wave_period
    ion_time_step = min(ion_time_step, next)
  elseif f < f1 + TOL then
    ion_time_step = 3*TOL   --[*1]
  elseif f < f2 - TOL then
    local next = (f2 - f) * wave_period
    ion_time_step = min(ion_time_step, next)
  else --f < f2 + TOL
    ion_time_step = 3*TOL
  end
  -- Safety check.
  if (ion_time_step + ion_time_of_flight) - ion_time_of_flight <= 2*TOL then
    error(string.format(
      "In the square waveform generator (squarewavelib.lua), there was a "..
      "loss in numerical accuracy when calculating (%0.17e + %0.17e) "..
      "microseconds. Double precision floating point arithmetic only has "..
      "about 16 digits of precision. You may need to increase the TOL "..
      "variable in squarewavelib.lua.",
      ion_time_of_flight, ion_time_step))
  end

  -- mark()
end


-- merge segments with any previous ones.
function M.install_segment(newsegment)
  for name,new in pairs(newsegment) do
    local old = segment[name]
    segment[name] = old and (function() old(); new() end) or new
  end
end
M.install_segment(M.segment)


--[[
 Footnotes:
 [1] 3*TOL is sufficient to ensure escape from 2*TOL voltage transition region.
 
 [2] A very small time-step (-TOL*wave_period, +TOL*wave_period) will cover
 the region of the voltage transition.  TOL can be understood as (twice)
 the fraction of the period required for the voltage transition.
 Isolating voltage transitions in this small time step allows the regular
 time steps to have constant voltages, thereby avoiding possible errors
 and complications from changing voltages during normal time-steps.
 The exponent on TOL is approximately the number of digits of precision
 that waveform transition times will have, so TOL should be small but
 not so small that numerical accuracy is lost when TOL is added to the
 current number of RF cycles.  For example, 1E+5 cycles + 1E-10 cycles
 requires 16 digits of precision.  16 digits of precision is about the
 maximum afforded by double precision floating point arithmetic in the CPU.
--]]
