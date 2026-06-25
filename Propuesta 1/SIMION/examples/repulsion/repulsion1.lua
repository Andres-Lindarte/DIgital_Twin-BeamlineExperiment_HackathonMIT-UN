-- SIMION workbench user program.
-- Computes potential contribution due to space-charge (Colombic repulsion method)
-- at a given set of points.
--
-- To get stable values, the potentials are averaged over time.
--
-- D.Manura, 2007-07-28

simion.workbench_program()

-- Check that these match your simulation.
local total_charge = -3.47E-13  -- Coloumbs
local num_particles = 1000

-- Constant for kQ in V = kQ/r.
local KQ = 9E9 * 1000 * total_charge/num_particles

-- Create list of points.  The space-charge contribution
-- to potential at each of these points will be computed.
local points = {}
for x=0,20 do
  points[#points+1] = {(x-10),0,0}
end

-- Create partial sum for each point to compute potential for.
local sums = {}
for i in ipairs(points) do sums[i] = 0 end

local last_tof = -1
local count = 0

-- Called on every time-step for each particle not yet splatted.
function segment.other_actions()
  if ion_time_of_flight > last_tof then -- next time step
    if count == 0 then -- compute enabled
      -- Print results.
      print("x,y,z,V_sp")
      for i,point in ipairs(points) do
        local v = sums[i] * KQ
        print(point[1], point[2], point[3], v)
        sums[i] = 0
      end
    end
    count = (count + 1) % 100 -- compute only periodically
  end
  if count == 0 then -- compute enabled
    if ion_time_of_birth < ion_time_of_flight then -- was created
      -- Update Coloumb's law partial sums for each compuatation point.
      for i,point in ipairs(points) do
        local x0,y0,z0 = unpack(point)
        local r = sqrt((ion_px_mm-x0)^2 + (ion_py_mm-y0)^2 + (ion_pz_mm-z0)^2)
        sums[i] = sums[i] + 1/r
      end
    end
  end
  last_tof = ion_time_of_flight
end
