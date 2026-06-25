-- group.lua - ion trap demo program for demonstrating ion grouping inside trap.
--
-- D.Manura-2006-08 - based on PRG code from SIMION 7.0 - David A. Dahl 1995
-- (c) 2006 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)
--=======================================================================
simion.workbench_program()

print "NOTE: Before use, set TQual = 0 or -1, enable "
print "Grouped flying, set Repulsion to Factor = 1, and"
print "enable Dots flying at maximum speed (use slider)."

local TRAP = simion.import("traputil.lua") -- load default ion trap behavior
local STOKES = simion.import("collision_stokes.lua")
                           -- Stoke's law viscous effects

TRAP.install_segments {
    TRAP.segment,
    STOKES.segment
}
