-- run.lua
-- SIMION batch mode program.
-- Computes multipole components from potentials for
-- a number of PAs.

assert(simion.pas, 'This example requires SIMION 8.1.')

-- Load multipole expansion code.
local ME = dofile "multipole_expansion.lua"

-- Radius of circle (in gu) over which to analyze potentials for
-- multipole expansion.
local radius = 100

-- Base names of PA files (i.e. without the ".pa" extension).
local gems = {
  "trap_endholes",
  "trap_stretched",
  "trap_truncated3",
  "trap_ringslot",
  "trap_truncated3_mirror"
}

-- Ensure PA with name <name> .. ".pa" is created from GEM file
-- <name> .. ".gem" and refined.
function ensure_created(name)
  local fh = io.open(name .. ".pa")
  if fh then
    fh:close() -- file exists already
  else
    simion.command("gem2pa " .. name .. ".gem")
    simion.command("refine --convergence=1e-5 " .. name .. ".pa")
  end
end

-- Ensure all PAs are created and refined.
for _,name in ipairs(gems) do
  ensure_created(name)
end

local pa = assert(simion.pas:open("trap_truncated3.pa"))
ME.print_result(ME.resolve {
  potential=pa,
  origin={1200,0},
  radius=radius,
  npoints=30,
  rscale=400,
  vscale=1000
})
pa:close()

local pa = assert(simion.pas:open("trap_truncated3_mirror.pa"))
ME.print_result(ME.resolve {
  potential=pa,
  origin={0,0},
  radius=radius,
  npoints=30,
  rscale=400,
  vscale=1000
})
pa:close()

local pa = assert(simion.pas:open("trap_stretched.pa"))
ME.print_result(ME.resolve {
  potential=pa,
  origin={1200,0},
  radius=radius,
  npoints=30,
  rscale=400,
  vscale=1000
})
pa:close()

local pa = assert(simion.pas:open("trap_ringslot.pa"))
ME.print_result(ME.resolve {
  potential=pa,
  origin={1200,0},
  radius=radius,
  npoints=30,
  rscale=400,
  vscale=1000
})
pa:close()


local pa = assert(simion.pas:open("trap_endholes.pa"))
ME.print_result(ME.resolve {
  potential=pa,
  origin={1200,0},
  radius=radius,
  npoints=30,
  rscale=400,
  vscale=1000
})
pa:close()

