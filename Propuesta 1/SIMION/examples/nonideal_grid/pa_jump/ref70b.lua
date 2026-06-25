-- SIMION workbench user program.
-- 
-- Simulation of non-ideal grid lensing using PA instance jumping.
--
-- (c) 2008 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0).
-- D.Manura, 2008-10 (created)

simion.workbench_program()


assert(simion.pas, 'This example requires SIMION 8.1.')

-- number of grid units in X and Y directions (in fine grid PA volume
-- coordinates) in which fine grid repeats.
local DUX = 92
local DUY = 92

-- some PA instance numbers.  Note: a couple blank PA instances (or perhaps a
-- large one containing the entire workbench) may be added to ensure the user
-- program segments get called in certain regions of space (since user program
-- segments execute only within the context of PA instances).  Blank PA
-- instances should have lower priority (lower instance numbers) than any
-- other PA instances they overlap so that the particles see the fields from
-- the real PA instances instead.  Note: fine nonideal grid PA instances
-- should have priority (higher instance numbers) than any coarse ideal grid
-- PA instances approximating them so that particles in the overlap region see
-- the more accurate fields from the fine PA instances instead.
local N_MIRROR_BLANK = 1
local N_SOURCE_BLANK = 2
local N_SOURCE = 3
local N_MIRROR = 4

-- potential array (PA) instance objects (located by PA instance number)
local grid1a_pa = simion.wb.instances[6]
local grid1b_pa = simion.wb.instances[7]
local grid2a_pa = simion.wb.instances[8]
local grid2b_pa = simion.wb.instances[9]
local grid3a_pa = simion.wb.instances[10]
local grid3b_pa = simion.wb.instances[11]
local grid4a_pa = simion.wb.instances[12]
local grid4b_pa = simion.wb.instances[13]


-- This effectively repeats the PA instance a_pa every (DUX, DUY) units in the
-- X-Y plane (in PA volume coordinates of a_pa).  It does this by moving a
-- second PA instance b_pa (which is assumed to be a duplicate of a_pa and
-- doesn't require any additional memory) into the repeating position closest
-- to the current particle position (ion_px_mm, ion_py_mm, ion_pz_mm), which
-- presumably is near where the particle is expected to hit.
local function pa_repeat_action(a_pa, b_pa)
  -- Optional: Plot marker dots as a check to ensure that all particles see
  -- this code.
  mark()
  -- Transform current particle's workbench coordinates (mm) into potential
  -- array instance volume coordinates (gu) of a_pa.
  local x,y,z = a_pa:wb_to_pa_coords(ion_px_mm, ion_py_mm, ion_pz_mm)
  -- Trancate to nearest multiple of (DUX, DUY).  This is the shift.  Note:
  -- the negative is because we will shift the PA instance working origin
  -- (ox,oy,oz) coordinate system.
  local newox = - math.modf(x / DUX) * DUX
  local newoy = - math.modf(y / DUY) * DUY
  if newox ~= b_pa.ox or newoy ~= b_pa.oy then
    -- Move the instance.  It is convenient to shift the PA instance working
    -- origin (ox,oy,oz) rather than the PA instance workbench origin (x,y,z)
    -- since the former is in units of grid units and oriented in the
    -- direction of the shift.
    b_pa.ox = newox
    b_pa.oy = newoy
    -- Optional: Redraw screen after PA instance moved.  We can watch the PA
    -- instance move during the fly'm.  To improve performance, we only do
    -- this when the instance actually moves.
    redraw_screen()
  end
end

function segment.other_actions()
  -- Perform pa_repeat_action for fine nonideal grids.  For performance or
  -- necessity, we restrict these to certain PA instances and/or volume
  -- regions.  These regions must be large enough to contain at least one
  -- time-step for each particle entering/exiting the fine grid PA instance so
  -- that a PA instance is properly positioned before the particle enters its
  -- region.  The marker dots (see above) can help check this.
  if ion_instance == N_SOURCE or ion_instance == N_SOURCE_BLANK then
    if ion_pz_mm > 11.5 and ion_pz_mm < 13.5 then
      pa_repeat_action(grid1a_pa, grid1b_pa)
    elseif ion_pz_mm > 23.6 and ion_pz_mm < 25.5 then
      pa_repeat_action(grid2a_pa, grid2b_pa)
    end
  elseif ion_instance == N_MIRROR or ion_instance == N_MIRROR_BLANK then
    if ion_pz_mm > 497 and ion_pz_mm < 503 then
      pa_repeat_action(grid3a_pa, grid3b_pa)
    elseif ion_pz_mm > 510 and ion_pz_mm < 512.5 then
      pa_repeat_action(grid4a_pa, grid4b_pa)
    end
  end
end
