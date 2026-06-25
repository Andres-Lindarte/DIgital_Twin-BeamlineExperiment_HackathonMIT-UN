-- ims.lua - ion mobility example.
--
-- This program applies an ion-neutral collision model to the
-- ion mobility system: either Stokes' Law (drag) or a hard-sphere
-- collision model (HS1).
--
-- D.Manura-2007-04.

simion.workbench_program()


-- <mode> is a global variable that selects which simulation to load
-- ("drag" or "hs1"").  You may change the default
-- mode here or override the default by entering <mode="hs1">
-- (without brackets) in the SIMION command-bar.
-- You must reload the workbench IOB after making this change.
local cmode = mode or "drag"  -- default
assert(cmode == "drag" or cmode == "hs1", string.format(
  "Invalid simulation mode <%s>. should be 'drag' or 'hs1'.", cmode))

-- Load selected model.
if     cmode == "drag" then simion.import("drag.lua")
elseif cmode == "hs1"  then simion.import("collision_hs1.lua")
end

print(cmode .. " mode loaded.")

-- Define appropriate parameters for each model.
-- (See README.html file for discussion of parameter selection.)

-- linear damping time constant (usec^-1)
-- [OVERRIDE DRAG]
adjustable linear_damping = 0.375

-- Mass of background gas particle (amu)
-- [OVERRIDE HS1]
adjustable _gas_mass_amu = 4.0

-- Background gas temperature (K)
-- [OVERRIDE HS1]
adjustable _temperature_k = 298

-- Background gas pressure (Pa)
-- Note: (Pa/mtorr) = 0.13328.
-- [OVERRIDE HS1]
adjustable _pressure_pa = 133.28

-- Collision-cross section (m^2)
-- [OVERRIDE HS1]
adjustable _sigma_m2 = 1.25E-18
