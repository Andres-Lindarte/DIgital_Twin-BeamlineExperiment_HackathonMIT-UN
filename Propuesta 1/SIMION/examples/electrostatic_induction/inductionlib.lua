--[[
 inductionlib.lua
 Lua library for detecting induced charge or current on electrodes
 due to charged particles in space.

 D.Manura-2011-11-30,2008-05
 (c) 2008 Scientific Instrument Services, Inc. (Licensed under SIMION 8.1)
--]]


local M = {}


assert(simion.pas, 'This example requires SIMION 8.1.')


-- List of PA instances in workbench
local instances = simion.wb.instances


-- Table that maps PA instance number to another table that maps
-- electrode number (in that instance) to potential on that electrode
-- as required for computing the "weighting potential" and "weighting
-- field".  Electrodes being measured are set to 1 V, and all others
-- are set to 0 V.  Example: to measure induced charge/current on
-- electrode 2 in instance 1, assuming instance 1 has three electrodes
-- 1, 2, and 3, this value would be {[1] = {[1] = 0, [2]=1, [3]=0}.
-- This variable is defined automatically by the "measure" function.
local weighting_potentials_of_instance


-- SIMION segment called on each time-step.
local i_sum = 0  -- total induced current from all particles.
local q_sum = 0  -- total induced charge from all particles.
function segment.other_actions()
  -- Retrieve weighting potentials for electrodes in current instance.
  -- Assume no induced charge/currents if not exist.
  local weighting_potentials = weighting_potentials_of_instance[ion_instance]
  if not weighting_potentials then  -- not defined
    M.tof = ion_time_of_flight
    M.current = 0
    M.charge  = 0
    return
  end

  -- Detect advance in time-step.  This will complete the calculation.
  -- Note: In Grouped flying, this function will be called for each
  -- particle before advancing the time-step.
  if ion_time_of_flight ~= M.tof then
    -- Store result.
    M.tof = ion_time_of_flight
    M.current = i_sum
    M.charge  = q_sum
    -- Reset parameters for new time-step.
    i_sum = 0
    q_sum = 0
  end

  -- PA instance object that ion is currently located in.
  local pa = instances[ion_instance].pa

  -- Measure position and velocity of current ion.
  local x,y,z = ion_px_gu, ion_py_gu, ion_pz_gu    -- (gu)
  local vx,vy,vz = ion_vx_mm, ion_vy_mm, ion_vz_mm -- (mm/usec)

  -- Measure weighting potential (unitless).
  -- This is found by measuring the potential in the current PA as
  -- observed at the current ion position, assuming electrodes are set
  -- as defined in weighting_potentials.
  local Vw = pa:potential_vc(x,y,z, weighting_potentials)

  -- Measure weighting field (1/mm) at current ion position.
  -- This is found by measuring the field in the current PA as
  -- observed at the current ion position, assuming electrodes are set
  -- as defined in weighting_potentials.
  local ewx,ewy,ewz = pa:field_vc(x,y,z, weighting_potentials)  -- (1/gu)
  local f = 1/ion_mm_per_grid_unit  -- (gu/mm)  converts units
  ewx,ewy,ewz = f*ewx,f*ewy,f*ewz   -- (1/mm)


  -- Compute image current from the current ion (j in 1..N) by the
  -- Shockley-Ramo theorem.
  -- i_k = sum j=1,N of q_j (v_j * E_k(r_j))
  -- Current in units of (A).
  local ELEMENTARY_CHARGE_C = 1.602176487e-19   -- (C/e)
  local MSEC_PER_MMUSEC = 1000  -- (m/sec) / (mm/usec)
  local MM_PER_M = 1000         -- (m/mm)
  local i =   ion_effective_charge        -- (e)
            * ELEMENTARY_CHARGE_C         -- (C/e)
            * (vx*ewx + vy*ewy + vz*ewz)  -- (mm/usec)*(1/mm)
            * MSEC_PER_MMUSEC             -- (m/sec)/(mm/usec)
            * MM_PER_M                    -- (mm/m)
                                          -- (A = C/sec)
  i_sum = i_sum + i

  -- Compute image charge from the current ion (j in 1..N) by the
  -- Shockley-Ramo theorem.
  -- q_k = sum j=1,N of -q_j V_k(r_j)
  -- Charge in units of (C).
  local q = - ion_effective_charge        -- (e)
            * ELEMENTARY_CHARGE_C         -- (C/e)
            * Vw                          -- (1)
                                          -- (C)
  q_sum = q_sum + q
end
M.other_actions = segment.other_actions


-- Declares which electrodes induced charges/currents are measured on.
-- t is an array of tables. Each table contains these fields:
--   instance  - instance number
--   electrode - electrode number
-- Example: to measure induced charge/current on electrode 2 in
-- instance 1, let t = {{instance = 1, electrode = 2}}.
function M.measure(t)
  local function assert(a,b) return a or error(b, 3) end
  assert(type(t) == 'table')

  local weights = {}  -- new value of weighting_potentials_of_instance

  -- Set measured electrodes to 1 V.
  for i,tt in ipairs(t) do
    assert(type(tt) == 'table')
    local iinstance = assert(tt.instance, "instance not specified")
    local ielectrode = assert(tt.electrode, "electrode not specified")

    weights[iinstance] = weights[iinstance] or {}
    weights[iinstance][ielectrode] = 1   -- (V)
    weights[iinstance].exclusive = true -- sets all other electrodes to 0 V
  end

  -- Define weighting_potentials_of_instance variable.
  weighting_potentials_of_instance = weights
end

return M
