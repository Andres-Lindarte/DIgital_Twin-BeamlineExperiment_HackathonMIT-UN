-- test-sds-hs1.lua
-- This is an example of merging the SDS and HS1 models
-- into the same simulation.
-- Here we use it to compare SDS and HS1 side-by-side.

simion.workbench_program()

-- Load SDS collision model.
local SDS = simion.import("collision_sds.lua")

-- Load HS1 collision model.
local HS1 = simion.import("collision_hs1.lua")

-- HS1
adjustable _temperature_k = 273.0
adjustable _pressure_pa = 0.53 * 1000
adjustable _gas_mass_amu = 28.94515
adjustable _sigma_m2 = 8.76E-19
adjustable _mark_collisions = 0

-- SDS
adjustable SDS_temperature_K = 273.0
adjustable SDS_pressure_torr = 0.00398 * 1000
adjustable SDS_collision_gas_mass_amu = 28.94515
adjustable SDS_collision_gas_diameter_nm = 0.366 

function segment.initialize()
  if ion_number % 2 == 0 then
    ion_py_mm = ion_py_mm + 100
  end

  -- note: always init SDS (in case ion in HS1 region enters SDS region.
  SDS.segment.initialize()
  HS1.segment.initialize()
end

function segment.tstep_adjust()
  if ion_py_mm < 50 then
    SDS.segment.tstep_adjust()
  else
    HS1.segment.tstep_adjust()
  end
end

function segment.other_actions()
  if ion_py_mm < 50 then
    SDS.segment.other_actions()
  else
    HS1.segment.other_actions()
  end
end

function segment.accel_adjust()
  if ion_py_mm < 50 then
    SDS.segment.accel_adjust()
  else
    assert(not HS1.segment.accel_adjust)
  end
end

function segment.terminate()
  if ion_py_mm < 50 then
    assert(not SDS.segment.terminate)
  else
    HS1.segment.terminate()
  end
end

-- Apply background gas velocity.
-- Caution: HS1 and SDS currently use different units.
function HS1.velocity() -- mm/usec
  return 0, 0.1, 0
end
function SDS.velocity() -- m/sec
  return 0, 0.1*1000, 0
end


-- Note: to test for even-numbered particles, use
--   ion_number % 2 == 0

