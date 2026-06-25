--[[
 spectrum.lua - SIMION workbench user program
 Aquires a FAIMS spectrum.  The spectrum (intensity v.s. CV) data
 is sent to the Log and also plotted in Excel.

 D.Manura, v2012-12-01, 2008-07.
 (c) 2007-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
 --]]

simion.workbench_program()


-- Load waveform library (import only one)
simion.import 'squarewavelib.lua'
--simion.import 'squarelinewavelib.lua'
--simion.import 'bisinusoidalwavelib.lua'
--simion.import 'bisinusoidallinewavelib.lua'
--simion.import 'sinusoidalwavelib.lua'
--simion.import 'experimentallinewavelib.lua'

-- Load SDS collisional model.
local SDS = simion.import 'collision_sds.lua'


-- Load plotting library.
local PLOT = simion.import '../plot/plotlib.lua'


--## BEGIN USER ADJUSTABLE VARIABLES

-- 1 = enable FAIMS optimizations (normally don't change this)
adjustable SDS_faims_mode = 1

-- 1 L/min through cross-sectional area of 5 * 0.5 mm^2.
adjustable SDS_vx_m_per_sec = 6.667

-- 0 = disable diffusion (makes FAIMS pattern clearer)
-- 1 = enable diffusion  (normal use)
adjustable SDS_diffusion = 1

-- FAIMS spectrum scan defined from begin to end voltages in steps of
-- step voltage.
adjustable SPECTRUM_CV_begin = -10
adjustable SPECTRUM_CV_end = 10
adjustable SPECTRUM_CV_step = 0.25

-- Particles that reach this x (mm) are considered detected
-- by the detector.  You may want to modify how this works.
adjustable x_detect = 5

-- Waveform parameters (overrides values in waveform library above).
--- Period of waveform (usec)
adjustable wave_period = 2.0
--- Fraction of period waveform is at high voltage.
adjustable wave_duty = 0.25
--- Dispersion voltage
adjustable wave_DV = 750
--- Compensation voltage
adjustable wave_CV = 0   -- This is controlled by the program.

-- Whether to plot results in Excel (0=no, 1=yes)
adjustable plot_enable = 1

--## END USER ADJUSTABLE VARIABLES

-- Particle count (scan intensity) for current scan.
local intensity

-- Spectrum.  This is stored as a table plottable with the Excel
-- library.
local spectrum = {
  header = {'CV', 'intensity'}, title = 'FAIMS Spectrum', lines = true
}

-- called on Fly'm to invoke a series of runs by calling `run()`. [1]
function segment.flym()
  sim_trajectory_image_control = 1 -- don't keep trajectories

  -- Normalize voltage step.
  SPECTRUM_CV_step =
    (SPECTRUM_CV_step == 0 and 1 or abs(SPECTRUM_CV_step))
    * (SPECTRUM_CV_end < SPECTRUM_CV_begin and -1 or 1)

  -- Do scans...
  for _V = SPECTRUM_CV_begin, SPECTRUM_CV_end, SPECTRUM_CV_step do
    -- Set up parameters for this run.
    wave_CV = _V
    intensity = 0   -- reset

    -- Perform trajectory calculation run.
    run()

    -- Record and store current scan result in spectrum.
    print("run=,"..ion_run..",CV=,"..wave_CV..",intensity=,"..intensity)
    spectrum[#spectrum+1] = {wave_CV, intensity}
  end
  
  -- Plot
  if plot_enable ~= 0 then
    PLOT.plot(spectrum)   -- plot spectrum in Excel.
  end
end


-- called on each time-step for each particle
local old = segment.other_actions
function segment.other_actions()
  old()

  -- Detect ions (you may want to modify how this works).
  if ion_px_mm > x_detect then
    intensity = intensity + 1
    ion_splat = 4  -- splat it
  end
end


-- Poiseuille planar flow.
-- Remove following "--[[" to enable this code.
--[[
function SDS.init()
  local FLOW = simion.import "flowlib.lua"
  adjustable SDS_pressure_torr
  adjustable SDS_temperature_K
  adjustable SDS_collision_gas_mass_amu
  assert(SDS_collision_gas_mass_amu == 28.94515,
    "FLOW assumes air but SDS_collision_gas_mass_amu not 28.94515.")
  local mu_pa_s = FLOW.compute_mu('air', SDS_temperature_K)
  print('mu=', mu_pa_s, 'Pa s')
  FLOW.define_poiseuille_planar {
    SDS = SDS,
    d_mm = 0.5,   -- Distance between plates (mm)
    x0_mm = 0,    -- X origin (mm)
    y0_mm = 0,    -- Y center (mm)
    p0_torr = SDS_pressure_torr,  -- Pressure at origin (torr)
    vx_m_psec = SDS_vx_m_per_sec, -- max velocity (m/s) in center
    mu_pa_s = mu_pa_s  -- dynamic viscosity (Pa s)
  }
  
  -- Plot gas flow.
  local CON = simion.import '../contour/contourlib81.lua'
  CON.plot{func=SDS.velocity,  npoints=21, z=0, mark=true}
  simion.sleep(1)
end
--]]

--[[
 Footnotes:
 [1] The flym/initialize_run/terminate_run segments are new in SIMION 8.1.0.40.
     See "Workbench Program Extensions in SIMION 8.1" in the supplemental
     documentation (Help menu).
--]]
