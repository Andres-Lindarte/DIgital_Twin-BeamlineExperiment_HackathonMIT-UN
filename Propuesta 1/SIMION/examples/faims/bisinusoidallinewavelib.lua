--[[
 bisinusoidallinewavelib.lua - Bisinuoisal waveform generation using waveformlib.lua.
 
 This is similar to bisinusoidalwavelib.lua but expresses it as a series of line
 line segments using waveformlib.lua.
 The main purpose of this example is to demonstrate the accuracy of
 waveformlib.lua for a continuous waveform that has been digitized
 (via comparison with bisinusoidalwavelib.lua results).
 
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
adjustable wave_timesteps = 16
-- constants for bisinusoidal shape
local h = 2
local F = 2
local PI = math.pi
-- plots waveform if non-zero.  Value is time in microseconds to plot.
adjustable wave_plot = 0

local WAVE = simion.import 'waveformlib.lua'

function M.segment.initialize_run()
  -- Note: unlike in segmentedwavelib.lua, we omit TOL since there are no
  -- abrupt voltage transitions.

  -- Set up waveform.  Times in microsec.
  local W = (1/wave_period) * 2 * PI
  local points = {}
  local N = wave_timesteps
  for i = 0,N do
    local t = wave_period * (i/N)
    local V = wave_CV + (F*sin(W*t) + sin(h*W*t - 0.5*PI))*wave_DV/(F + 1)
    points[#points+1] = {time=t, potential=V}
  end
  WAVE.set_waveforms(
    WAVE.waveforms {
      WAVE.electrode(2) {
        WAVE.loop(math.huge) {
          WAVE.lines(points)
        };
      };
    }
  )
  WAVE.set_recommended_timestep(wave_timesteps ~= 0 and wave_period/wave_timesteps or nil)
  -- Plot waveform (this is optional and can be removed).
  if wave_plot ~= 0 then WAVE.plot_waveform(nil, wave_plot) end
end

-- merge segments with any previous ones.
WAVE.install()
WAVE.install_segment(M.segment)

return M
