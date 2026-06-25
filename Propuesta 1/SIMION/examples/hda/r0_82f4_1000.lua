simion.workbench_program()

-- Import other Lua file.
simion.import("r0_82f1_1000.lua")

-- Optionally, override some adjustable values from
-- imported file for this simulation.
adjustable _VL3_min  = -500    -- lens e(3) min voltage
adjustable _VL3_max  = 8500    -- lens e(3) max voltage
adjustable _VL3_step = 250     -- lens e(3) step votage
adjustable _VL4_min  = -500    -- lens e(4) min voltage
adjustable _VL4_max  = 5000    -- lens e(4) max voltage
adjustable _VL4_step = 250     -- lens e(4) step voltage
