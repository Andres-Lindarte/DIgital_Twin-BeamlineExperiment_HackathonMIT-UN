-- lens_curves_75.lua - SIMION Lua workbench user program.
-- Generates "zoom lens" curve.

simion.workbench_program()

-- Import basic zoom lens curve behavior.
simion.import "zoom_lens_curve.lua"

-- Override parameters for this system.
adjustable _VA_min = 1/20
adjustable _VA_max = 20
adjustable _VB_min = 1/20
adjustable _VB_max = 20
adjustable _D_mm   = 100
adjustable _P_D = -3.475
adjustable _Q_D = 2.975