--[[
 plates.lua - SIMION workbench user program.
 Demonstrates FAIMS using an ideal planar FAIMS cell.

 D.Manura, v2012-12-01, 2008-06
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

-- 1 = enable FAIMS optimizations (normally don't change this)
adjustable SDS_faims_mode = 1

-- 1 = enable Poiseuille flow; 0 = constant gas flow
adjustable poiseuille_flow = 1

-- Waveform parameters (overrides values in waveform library above).
--- Period of waveform (usec)
adjustable wave_period = 2.0
--- Fraction of period waveform is at high voltage.
adjustable wave_duty = 0.25
--- Dispersion voltage
adjustable wave_DV = 750
--- Compensation voltage
adjustable wave_CV = 0
--- Minimum number of time-steps per waveform period.
--- Overrides T.Qual if non-zero.
adjustable wave_timesteps = 16

-- (m/s)
-- note: 6.667 m/s for 1 L/min through cross-sectional area of 5 * 0.5 mm^2
-- if assuming uniform flow.
adjustable SDS_vx_m_per_sec = 6.667

-- Whether to enable SDS randomized diffusion effect.  1=enabled,
-- 0=disabled.  WARNING! Normally, you want this enabled (1) for the
-- most realistic calculation.  However, for comprehension purposes,
-- it may be useful to temporarily disable (0) it so that only the
-- SDS mobility effect (which facilitates FAIMS) is present.
adjustable SDS_diffusion = 0

-- Terminate particles early if particle x position (mm)
-- is greater than this value.  (Speeds simulation.)
adjustable x_max = 3


-- SIMION segment called on each time step.
local old = segment.other_actions
function segment.other_actions()
  old()
  -- mark()

  if ion_px_mm > x_max then
  -- if ion_time_of_flight > 133333.3333333 then
    print('Note: User program terminating particle early to speed simulation.')
    ion_splat = -4
  end
end


function SDS.init()
  -- Poiseuille planar flow.
  if poiseuille_flow ~= 0 then
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
  end
end

