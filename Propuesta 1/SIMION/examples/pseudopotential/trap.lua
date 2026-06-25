--[[
 trap.lua
 Workbench user program for RF voltage and pseudopotential calculation.
--]]

simion.workbench_program()

local C = require 'simionx.Constants'

adjustable max_time = 30 -- usec
adjustable V = 100  -- RF volts
adjustable U = 0    -- DC volts (zero)
adjustable frequency = 1.0E+6  -- Hz

local inst       = simion.wb.instances[1] -- PA instance of trap.
local pseudoinst = simion.wb.instances[2] -- PA instance to store pseudopotentials in

-- Gets magnitude of field (V/mm) at point (x,y,z)
-- in PA volume units (gu).
-- Optionally given adjustable electrode voltages in table `t` (may be nil).
local function field(painst, xg,yg,zg, t)
  local pa = painst.pa
  local scale = painst.scale
  local ex,ey,ez = pa:field_vc(xg,yg,zg, t)  -- V/gu
  ex,ey,ez = ex/pa.dx_mm,ey/pa.dz_mm,ez/pa.dz_mm  -- V/mm
  local E = math.sqrt(ex^2 + ey^2 + ez^2)/scale -- V/mm
  return E
end

-- Update `pseudoinst` with pseudopotentials derived from `inst`,
-- given mass (u), charge (e), and RF frequency (Hz), and optional table
-- of fast adjustable voltages `t` (may be nil).
local function calculate_pseudopotential(mass, charge, frequency, t)
  print('updating pseudopotential array...m/q='..mass..'/'..charge..', f='..frequency)
  local pa       = inst.pa
  local pseudopa = pseudoinst.pa
  
  local q = charge * C.ELEMENTARY_CHARGE_C  -- charge, C
  local m = mass   * C.UNIFIED_MASS_KG      -- mass, kg
  local omega = frequency * 2*math.pi       -- RF angular frequency, rad/s
  
  local k = q/(4*m*omega^2)  -- scaling constant in pseudopotential formula
  for xg,yg,zg in pa:points() do
    local E = field(inst, xg,yg,zg, t) * 1000  -- V/mm * (1000 mm/m)
    local pseudo = k*E^2
    pseudopa:potential(xg,yg,zg, pseudo)
  end
  pseudopa.refinable = false  -- avoid prompts to refine
end

-- Displays 3D ion-trap q & z tuning parameters (optional, just for debugging).
local function display_tune_params()
  local q = ion_charge*C.ELEMENTARY_CHARGE_C
  local m = ion_mass*C.UNIFIED_MASS_KG
  local omega = frequency * 2*math.pi
  local z0 = 7.1E-3  -- m
  local r0 = 10E-3   -- m
  local az = -16*q*U/(m*(r0^2+2*z0^2)*omega^2)
  local qz =   8*q*V/(m*(r0^2+2*z0^2)*omega^2)
  print('az='..az..', qz='..qz)
end


function segment.initialize_run()
  -- Set particle flying options.
  sim_grouped = 1             -- grouped flying.
  sim_trajectory_quality = 0  -- T.Qual zero.
end

function segment.initialize()
  -- Update potentials in trap-pseudo.pa to reflect
  -- pseudo potentials derived from trap.pa0, first particle, and RF.
  if ion_number == 1 then
    calculate_pseudopotential(ion_mass, ion_charge, frequency, {[1] = V})
    display_tune_params()
  end
end

function segment.tstep_adjust()
  -- Keep time step under some fraction of the RF period
  local dt = (0.1*1E+6)/frequency
  if ion_time_step > dt then ion_time_step = dt end
end

function segment.fast_adjust()
  -- Apply RF to ring electrode.
  adj_elect01 = U + V * sin(frequency*(1E-6*2*math.pi)*ion_time_of_flight)
end

function segment.other_actions()
  -- Terminate particles after time `max_time`.
  if ion_time_of_flight > max_time then ion_splat = 1 end

  sim_update_pe_surface = 1  -- updates PE display continually
end
