simion.workbench_program()

-- Check that these match your simulation.
-- local total_current = 0.013601E-3 A/mm^2
-- total total_length = 0.04 mm
-- local total_time = 0.005E-6 s
local total_charge = -2.72E-15 -- Coloumbs
local num_particles = 1000

-- Location where voltage due to space-charge is measured
--local x0,y0,z0 = 0.01,0,0  -- mm
local x0,y0,z0 = 0.0158,0,0  -- mm

-- Constant kQ in V = kQ/r.
local KQ = 9E9 * total_charge/num_particles

-- Temporary values for computing time-averaged voltage
local v_sum = 0  -- sum of voltage measurements
local v_num = 0  -- number of voltage measurements

local last_tof = -1 -- last time step time.
local sum1 = 0      -- sum of kQ/r values at current time.
local count = 0     -- counter (avoids calculating on every time-step)
function segment.other_actions()
  if ion_time_of_flight > last_tof then
    count = (count + 1) % 100
    if count == 0 then
      sum1 = sum1 * KQ
      local v = sum1; sum1 = 0
      v_num = v_num + 1
      v_sum = v_sum + v
      local v_ave = v_sum / v_num
      print(v, v_ave)
    end
  end
  if count == 0 then
    if ion_time_of_birth < ion_time_of_flight then
      local r = sqrt((ion_px_mm-x0)^2 + (ion_py_mm-y0)^2 + (ion_pz_mm-z0)^2)
      sum1 = sum1 + 1/(r*0.001)
    end
  end
  last_tof = ion_time_of_flight
end

