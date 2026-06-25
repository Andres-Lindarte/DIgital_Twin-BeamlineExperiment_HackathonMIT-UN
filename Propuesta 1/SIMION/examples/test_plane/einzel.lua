-- einzel.lua - workbench user program
-- demonstrating data recording on special test planes using
-- utility routine (testplanelib).
simion.workbench_program()

local num_hits = 0

-- Load test plane library code.
local TP = simion.import 'testplanelib.lua'

-- Define the test planes (given point and surface normal vector).
-- These define segments that should be called inside your own segments.
local test1 = TP(20,0,0, 1,0,0)
local test2 = TP(40,0,0, 1,-1,0)
local test3 = TP(80,0,0, 1,1,0,
  -- example of function to call on reaching test plane.
  function()
    mark()
    print('In test plane 3: n=', ion_number, 'x=', ion_px_mm)
    -- ion_splat = 1  -- optionally splat particle in test plane
    num_hits = num_hits + 1  -- optionally count hits on test plane
  end)

-- The segments for each test plane are called...

function segment.tstep_adjust()
  test1.tstep_adjust()
  test2.tstep_adjust()
  test3.tstep_adjust()
end

function segment.other_actions()
  test1.other_actions()
  test2.other_actions()
  test3.other_actions()
end

function segment.terminate_run()
  print('num hits on test plan 3:', num_hits)
end
