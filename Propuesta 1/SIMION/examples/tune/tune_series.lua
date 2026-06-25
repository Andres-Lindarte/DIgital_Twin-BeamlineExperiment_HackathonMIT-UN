--[[
 tune_series.lua - lens tuning example, iterating over two voltages.

 This will iterate over all combinations of two electrode voltages,
 calculating particle trajectories at each iteration.

 D.Manura, 2012-08-14,2009-07
 (c) 2009-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()

adjustable V3_begin = 50   -- First V3 voltage
adjustable V2_begin = 50   -- First V2 voltage
adjustable V3_step = 100   -- V3 voltage step size
adjustable V2_step = 100   -- V2 voltage step size
adjustable V3_count = 10  -- V3 voltage number of steps
adjustable V2_count = 10  -- V2 voltage number of steps
adjustable excel_enable = 1  -- Use Excel? (1=yes, 0=no)

local V3_voltage  -- current value of voltage V3
local V2_voltage  -- current value of voltage V2
local nhits      -- number of hits detected in current run

-- Excel objects.
local excel
local function excel_begin()
  excel = simion.import '../excel/excellib.lua' . get_excel()
  excel.Visible = true
  excel_wb = excel.Workbooks:Add()
  excel_ws = excel_wb.Worksheets(1)
  excel_ws.Cells(1, 1).Value2 = "Number of particles transmitted for each combination of voltages V2,V3."
  excel_ws.Cells(2, 1).Value2 = "V2\\V3"
end

-- called on Fly'm and expected to initiate runs by calling `run()`.
function segment.flym()
  -- Initialize Excel speadsheet (if enabled).
  if excel_enable ~= 0 then
    excel_begin()
  end
  
  sim_trajectory_image_control = 1 -- don't keep trajectories
  
  -- Step through all combinations of voltages V3 and V2.
  for V3_pos = 1,V3_count do
    for V2_pos = 1,V2_count do
      -- Prepare for this run.
      V3_voltage = V3_begin + (V3_pos - 1) * V3_step
      V2_voltage = V2_begin + (V2_pos - 1) * V2_step

      -- Perform trajectory calculation run.
      run()

      -- Record results.
      print('result: V3='..V3_voltage..',V2='..V2_voltage..',nhits='..nhits)
      if excel_enable ~= 0 then
        excel_ws.Cells(2, V3_pos+1).Value2 = V3_voltage
        excel_ws.Cells(V2_pos+2, 1).Value2 = V2_voltage
        excel_ws.Cells(V2_pos+2, V3_pos+1).Value2 = nhits
      end
    end
  end
end


-- called on start of each run.
local first
function segment.initialize_run()
  first = true
  nhits = 0  -- reset for next run
end


-- called multiple times per time-step to adjust voltages.
function segment.fast_adjust()
  adj_elect03 = V3_voltage
  adj_elect02 = V2_voltage
end


-- called on every time-step for each particle in PA instance.
function segment.other_actions()
  -- Update the PE surface display on first time-step of run.
  if first then first = false; sim_update_pe_surface = 1 end
end


-- called on each particle termination inside a PA instance.
function segment.terminate()
  -- Acceptance criteria
  if ion_px_mm > 90 and sqrt(ion_py_mm^2+ion_pz_mm^2) < 5 then
     nhits = nhits + 1
  end
end


--[[
 Footnotes:
 [1] The flym/initialize_run/terminate_run segments are new in SIMION 8.1.0.40.
     See "Workbench Program Extensions in SIMION 8.1" in the supplemental
     documentation (Help menu).
--]]
