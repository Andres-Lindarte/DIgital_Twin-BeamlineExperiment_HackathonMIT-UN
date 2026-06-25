--[[
 segmentedwavelinelib.lua - Simple square waveform generation using waveformlib.lua.
 
 This is similar to squarewavelib.lua but uses waveformlib.lua to make waveform
 definition easier.
 
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
-- plots waveform if non-zero.  Value is time in microseconds to plot.
adjustable wave_plot = 0

local WAVE = simion.import 'waveformlib.lua'

function M.segment.initialize_run()
  -- Note the extra time time-step around each voltage transition avoids
  -- accuracy issues from floating point equality tests.
  -- It would be nice to eliminate this though.
  local TOL = 1E-7  -- [2]
  assert(TOL >= 1E-16)
  local TOL2 = wave_period * TOL

  -- Set up waveform.
  local Vlow = -wave_DV * (wave_duty / (1 - wave_duty)) -- low voltage in cycle
  WAVE.set_waveforms(
    -- Define waveform for each adjustable electrode.  Times in microsec.
    WAVE.waveforms {
      WAVE.electrode(2) {
        WAVE.loop(math.huge) {
          WAVE.lines {
            {time=0,                            potential=wave_CV + Vlow};
            {time=TOL,                          potential=wave_CV + wave_DV};
            {time=wave_period * wave_duty-TOL2, potential=wave_CV + wave_DV};
            {time=wave_period * wave_duty+TOL2, potential=wave_CV + Vlow};
            {time=wave_period-TOL2,             potential=wave_CV + Vlow};
          };
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

--[[
 Footnotes:
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
