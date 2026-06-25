simion.workbench_program()

-- Enable beam repulsion.
sim_repulsion = 'beam'
sim_repulsion_amount = 0.2E-3 * 2  -- A  (note: x2 for image charge)

-- radius of on-axis cylinder
local R = 50 -- mm

local xs = {}
local ys = {}
local zs = {}
local charges = {}

function segment.other_actions()
  -- Force the locations of the last 100 particles
  -- to be at the theoretical image charge locations
  -- of the first 100 particles.
  if ion_number <= 100 then
    xs[ion_number] = ion_px_mm
    ys[ion_number] = ion_py_mm
    zs[ion_number] = ion_pz_mm
    charges[ion_number] = ion_charge
  elseif ion_number <= 200 then
    local xd = xs[ion_number - 100]
    local yd = ys[ion_number - 100]
    local zd = zs[ion_number - 100]
    local q =  charges[ion_number - 100]
    local r = math.sqrt(yd^2 + zd^2)
    local ri = R^2 / r
    ion_px_mm = xd
    ion_py_mm = yd * (ri/r)
    ion_pz_mm = zd * (ri/r)
    ion_charge = -q
    ion_splat = 0 -- never terminate these
  else
    error 'unexpected number of particles'
  end
end
