--[[
 SIMION Lua workbench user program for space-charge handling.

 Note: this example uses positive ions (not electrons like the
 other Pierce gun examples).  The charge is decreased and the
 TOF is increased.

 D.Manura, 2012-09-04,2008-02.
--]]

simion.workbench_program()


-- Decide which modules to load.  If you like, you may change the mode
-- without editing this file by setting the 'mode' global variable to
-- a space-delimited list of modules ('pic', 'hs1', and 'sds').  For
-- example, enter "mode='pic sds'" (without double-quotes) in the
-- bottom SIMION command-bar and click Fly'm (or reload the IOB).
local mode = getfenv().mode or 'pic hs1'
local load_pic = mode:find 'pic'
local load_hs1 = mode:find 'hs1'
local load_sds = mode:find 'sds'
assert(not(load_hs1 and load_sds),
       "HS1 and SDS should not both be installed")
print("mode is [".. tostring(mode) .. "].")


-- Load HS1 collision model code.
if load_hs1 then
  print "Loading HS1..."
  local HS1 = simion.import("../../collision_hs1/collision_hs1.lua")
  adjustable HS1_pressure_pa = 1
  adjustable HS1_mark_collisions = 0 -- not useful with Grouped enabled
else
  print "Not loading HS1."
  adjustable HS1_enable = 0
end

-- Load SDS collision model code.
if load_sds then
  print "Loading SDS..."
  local SDS = simion.import("../../collision_sds/collision_sds.lua")
  adjustable SDS_pressure_torr = 760
else
  print "Not loading SDS."
  adjustable SDS_enable = 0
end

-- Load particle-in-cell (PIC) code.
local PIC
if load_pic then
  print "Loading PIC..."
  PIC = simion.import("../piclib.lua")
  PIC.load('charge')
  adjustable PIC_refine_convergence = 1e-4
  adjustable PIC_refine_period = 2
  PIC.is_init = false  -- used to verify that initialize is called
else
  adjustable PIC_enable = 0
  -- ensure no space-charge in solution
  local pa = simion.pas[2]
  pa:refine{convergence=1e-5}
end
adjustable PIC_enable

-- Average Coulombs per particle.
-- ion_cwf units are C (3D and 2D cylindrical) or C/mm in z (2D planar).
adjustable C_per_particle =
   0.00122239E-6 -- current density (A mm^-2 = C sec^-1 mm^-2)
   * 12.0E-6     -- emission duration (sec), i.e. TOB range
   * math.pi*2^2 -- emission area (mm^2)
   / 1000        -- number of particles (unitless)


local old_initialize_run = segment.initialize_run
function segment.initialize_run()
  if old_initialize_run then old_initialize_run() end
  print('C_per_particle=', C_per_particle)
end


-- Called for each particle created inside an array.
local old_initialize = segment.initialize
function segment.initialize()
  if old_initialize then old_initialize() end

  -- Compute relative weighting used to distribute charges in
  -- particles.
  --  
  -- Depending how your particles to be traced are defined, these
  -- particles may each represent a different relative quantity of
  -- real/physical particles.
  --
  -- If the field and particles both have 2D cylindrical symmetry and
  -- the particles are equidistantly spaced along a radius or diameter
  -- (e.g. pierce2dcylindrical.fly2), then the charges assigned to the
  -- particles should be weighted proportionately to their distance
  -- from axis to represent the fact the each particle at radius r0
  -- represents particles that would actually exist over an entire
  -- circle having circumference 2*PI*r0.  WARNING: you would need to
  -- adjust r_mean if using a different beam size.
  --
  local r_mean = 1.0  -- half radius (mm)
  local r = sqrt(ion_py_mm^2 + ion_pz_mm^2) -- distance from axis.
  local weight = r / r_mean
  -- If the field and particles both have 2D cylindrical symmetry and
  -- the particles are (1) uniformly distributed over a 2D surface
  -- (e.g. pierce2dcylindrical-3d.fly2) or (2) non-equally spaced
  -- along a radius or diameter with density proportional to their
  -- distance from the axis, then the charges assigned to the
  -- particles should be equally weighted.
  --
  -- local weight = 1

  -- Assign charge to particle (used by PIC Poisson solving code).
  if PIC and PIC_enable ~= 0 then
    ion_cwf = C_per_particle * weight
  end

  if PIC then PIC.is_init = true end
end

