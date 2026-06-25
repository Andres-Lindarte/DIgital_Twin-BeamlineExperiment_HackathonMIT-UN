-- 
-- D.Manura, 2010-03

simion.workbench_program()

local R = 10.5
local rs = {}
local tofs = {}

-- find y for point (x,y) on linear interpolation
-- between points (x1,y1) and (x2,y2).
local function interpolate(x1,y1, x2,y2, x)
  return y1 + ((y2-y1)/(x2-x1)) * (x - x1)
end

-- for each particle at each time step...
function segment.other_actions()
  -- r = radius at end of time-step
  -- ion_time_of_flight = TOF at end of time-step
  local r = math.sqrt(ion_px_mm^2 + ion_py_mm^2 + ion_pz_mm^2)

  if r >= R and rs[ion_number] and rs[ion_number] < R then -- crossing boundary
    local tofi = interpolate(rs[ion_number], tofs[ion_number], r, ion_time_of_flight, R)
    mark()  -- draw dot
    print(ion_number, R, tofi, "=n,R,tof")
  end

  -- store current values for next time-step
  rs[ion_number] = r
  tofs[ion_number] = ion_time_of_flight
end

