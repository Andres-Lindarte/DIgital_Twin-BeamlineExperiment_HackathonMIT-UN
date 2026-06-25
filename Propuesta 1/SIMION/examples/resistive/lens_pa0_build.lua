--[[
 lens_build.lua - generates lens.pa#.
 
 This is an example of building a PA# file with
 resistive electrodes that are fast adjustable.
 
 Requires 8.1.0.16 or above to avoid the
 error "Wrong Reference Point Potential in lens.pa1"
 during fast adjust.
 
 D.Manura, 2012-08
 (c) 2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

-- convergence objective to use.
local convergence = 1E-7

-- Utility functions.
local function write_file(filename, data)
  local fh = assert(io.open(filename, 'wb'))
  fh:write(data)
  fh:close()
end
local function clip(x, xmin, xmax)
  return math.max(math.min(x, xmax), xmin)
end

simion.pas:close()  -- remove all PA's from RAM.

-- Generates initial .pa# file.
local gem = [[
  pa_define(251,56,1, cylindrical,, electrostatic)
  e(1) { fill { within { box(50,50,100,55) } } }
  e(2) { fill { within { box(150,50,200,55) } } }
]]
write_file('lens.gem', gem)
simion.command'gem2pa lens.gem lens.pa#'
local pa = simion.pas:open'lens.pa#'

-- Create (and possibly refine) electrode solution arrays (.pa0, .pa1, etc.).
-- We could just do `pa:refine{convergence=convergence}` here, which
-- creates AND refines all solution arrays.  However, any
-- electrode solution arrays that we edit later will need
-- to be refined after editing, so refining those arrays now is not necessary
-- (albeit not harmful).  To reduce refine time, we only refine
-- the arrays that are not edited later.
pa:refine{convergence=convergence, solutions={0}} -- craeate and refine .pa0
pa:load'lens.pa#'  -- reload
pa:refine{convergence=1E+6, solutions={1,2}} -- create but not refine .pa1 & .pa2

-- Replace electrode potentials in solutions arrays with
-- gradients and re-refine them.

pa:load'lens.pa1'
for x,y,z in pa:points() do
  if pa:electrode(x,y,z) and pa:potential(x,y,z) == 10000 then
    pa:potential(x,y,z, clip((x-50)/50, 0,1)*10000)
  end
end
pa:refine{convergence=convergence}
pa:save()

pa:load'lens.pa2'
for x,y,z in pa:points() do
  if pa:electrode(x,y,z) and pa:potential(x,y,z) == 10000 then
    pa:potential(x,y,z, clip((x-150)/50, 0,1)*10000)
  end
end
pa:refine{convergence=convergence}
pa:save()

-- Now we can load it (and optionally fast adjust).
pa:load'lens.pa0'

print 'DONE'
