--[[
  SIMION workbench user program.
  Records total distance (in mm) each particle has traveled.
  
  Caveats:
  - This won't work correctly if a particle is not flying inside
    any PA instance volume because the other_actions segment will
	not be called.
  - This also won't work correctly if magnetic and electric PA
    instances are overlapping because the other_actions segment
	will be called twice per time step.
	
  D.Manura, 2012-04.
--]]

simion.workbench_program()

-- various parameters are remembered in a table, keyed by ion_number.
-- Using tables allows this program to even work with Grouped flying enabled.
local last_x = {}  -- Particle position at end of previous time step.
local last_y = {}
local last_z = {}
local distance = {}  -- Total distance (mm) particle has traveled.

-- Computes distances between points (x1,y1,z1) and (x2,y2,z2).
local function point_distance(x1,y1,z1, x2,y2,z2)
  return math.sqrt((x1-x2)^2 + (y1-y2)^2 + (z1-z2)^2)
end

function segment.initialize()
  local x2,y2,z2 = ion_px_mm, ion_py_mm, ion_pz_mm
  last_x[ion_number], last_y[ion_number], last_z[ion_number] = x2,y2,z2
end

function segment.other_actions()
  -- Get points at beginning and end of current time step.
  local x1,y1,z1 = last_x[ion_number], last_y[ion_number], last_z[ion_number]
  local x2,y2,z2 = ion_px_mm, ion_py_mm, ion_pz_mm
  
  -- Add distance between these points to total distance.
  if x1 then  -- if exists
    local delta_distance = point_distance(x1,y1,z1, x2,y2,z2)
    distance[ion_number] = (distance[ion_number] or 0) + delta_distance
  end
  last_x[ion_number], last_y[ion_number], last_z[ion_number] = x2,y2,z2
  
  --print(ion_number, distance[ion_number])
  
  -- You optionally may use something like this to terminate particles after
  -- traveling a certain distance.
  --if distance[ion_number] > 10 then ion_splat = 1 end
end

function segment.terminate()
  print('distance', ion_number, distance[ion_number])
end
-- alternately, use "segment.terminate_run" in SIMION 8.1.
--function segment.terminate_run()
--  for i=1,table.maxn(distance) do
--    print('distance', i, distance[i])
--  end
--end
