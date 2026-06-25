--[[
 bisinusoidalwavelib.lua
 Simple bisinusoidal waveform generation.
--]]

local M = {}
M.segment = {}

-- Period of waveform (usec)
adjustable wave_period = 2.0
-- Dispersion voltage
adjustable wave_DV = 750
-- Compensation voltage
adjustable wave_CV = 0
-- Minimum number of time-steps per waveform period.
-- Overrides T.Qual if non-zero.
adjustable wave_timesteps = 16
-- constants for bisinusoidal shape
local h = 2
local F = 2
local PI = math.pi

function M.segment.fast_adjust()
  local W = (1/wave_period) * 2 * PI
  local t = ion_time_of_flight
  adj_elect[2] = wave_CV + (F*sin(W*t) + sin(h*W*t - 0.5*PI))*wave_DV/(F + 1)
  -- print('V=',adj_elect[4], 't=', ion_time_of_flight, ion_time_step,ion_px_mm)
end

-- Time-step control.  Must be a sufficiently small fraction
-- of period to fully represent wave form.
function M.segment.tstep_adjust()
  ion_time_step = wave_period / wave_timesteps
end

-- merge segments with any previous ones.
function M.install_segment(newsegment)
  for name,new in pairs(newsegment) do
    local old = segment[name]
    segment[name] = old and (function() old(); new() end) or new
  end
end
M.install_segment(M.segment)

return M
