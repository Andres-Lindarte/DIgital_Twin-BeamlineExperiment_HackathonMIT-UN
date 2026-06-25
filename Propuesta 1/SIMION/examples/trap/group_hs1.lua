-- group.lua - ion trap demo program for demonstrating ion grouping inside trap.
--
-- D.Manura-2006-08 - based on PRG code from SIMION 7.0 - David A. Dahl 1995
-- (c) 2006 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)
--=======================================================================
simion.workbench_program()

local TRAP = simion.import("traputil.lua") -- load default ion trap behavior

local HS1 = simion.import("collision_hs1.lua")

-- collision_hs1.lua variable overrides
adjustable _mark_collisions = 0

TRAP.install_segments {TRAP.segment, HS1.segment}
