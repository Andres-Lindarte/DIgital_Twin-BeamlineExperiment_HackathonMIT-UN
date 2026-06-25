--[[
 sinusoidalwavelib.lua
 Simple sinusoidal waveform generation.

 Note: unlike the bisinusoidal waveform (bisinusoidalwavelib.lua), this
 waveform is symmetric and therefore doesn't separate ions.
 This wareform is therefore intended mainly just for comparison.

 Note: the phase of the sinuoisdal waveform at time t=0 can
 affect the results.  Using +-cos rather than sin will put the
 particle at roughly the center of its trajectory at t=0.
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

function M.segment.fast_adjust()
  local W = (1/wave_period) * 2 * math.pi
  adj_elect[2] = wave_CV + cos(W*ion_time_of_flight) * wave_DV
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
