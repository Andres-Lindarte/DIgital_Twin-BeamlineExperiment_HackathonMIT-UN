-- drag.lua
--
-- Demonstrates plotting electric field lines and equi-potential
-- contour lines using contourlib.lua.
--
-- Here, we simply load the contouring library.
-- Note: In SIMION's particle definitions, you should define
-- particles that will trace the field lines.
--

simion.workbench_program()

-- Load contouring library.
simion.import 'contourlib.lua'
