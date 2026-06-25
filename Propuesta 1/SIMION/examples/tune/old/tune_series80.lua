-- note: This is like tune_series.lua but uses a SIMION 8.0 compatible
-- approach (without new segments).

simion.workbench_program()

adjustable A_begin = 50
adjustable B_begin = 50
adjustable A_step = 100
adjustable B_step = 100
adjustable A_n = 10
adjustable B_n = 10
adjustable excel_enable = 1

local run_number = 0
local A_pos = 0
local B_pos = math.huge
local last_ion
local A_voltage
local B_voltage
local nhits
local excel
local excel_wb
local excel_ws


function segment.initialize()
  if excel_enable ~= 0 and not excel then
    excel = luacom.CreateObject("Excel.Application")
    excel.Visible = true
    excel_wb = excel.Workbooks:Add()
    excel_ws = excel_wb.Worksheets(1)
  end

  if ion_number == 1 then
    run_number = run_number + 1

    if B_pos >= B_n then
      B_pos = 1
      A_pos = A_pos + 1
    else
      B_pos = B_pos + 1
    end

    A_voltage = A_begin + (A_pos - 1) * A_step
    B_voltage = B_begin + (B_pos - 1) * B_step

    print('run', B_pos, A_pos)

    nhits = 0
  end

  last_ion = ion_number
end


function segment.fast_adjust()
  adj_elect03 = A_voltage
  adj_elect02 = B_voltage
end


function segment.terminate()
  -- Acceptance criteria
  if ion_px_mm > 90 and sqrt(ion_py_mm^2+ion_pz_mm^2) < 5 then
     nhits = nhits + 1
  end

  if ion_number == last_ion then
     sim_rerun_flym = (B_pos == B_n and A_pos == A_n) and 0 or 1

     -- Record results.
     if excel_enable ~= 0 then
       excel_ws.Cells(1, A_pos+1).Value2 = A_voltage
       excel_ws.Cells(B_pos+1, 1).Value2 = B_voltage
       excel_ws.Cells(B_pos+1, A_pos+1).Value2 = nhits
     else
       print('result', A_voltage, B_voltage, nhits)
     end
  end
end
