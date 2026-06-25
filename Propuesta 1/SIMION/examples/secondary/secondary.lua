-- SIMION 8 User Program
-- Incorporates secondary emission effects when particles
-- hit electrode surfaces.
--
-- This program incorporates secondary emission effects into
-- a workbench.  When a particle hits a surface, it deflects
-- in some specified way, optionally changing mass, charge,
-- direction, and energy.
--
-- Most of the secondary emission functionality is implemented
-- in secondarylib.lua.  See the comments in that file
-- for usage info.
--
-- The example below defines two system-dependent functions
-- secondary_user_time_to_surface and secondary_user_normal.
-- These need to be defined only if the scattering code is
-- used in certain modes that require the surface and/or
-- surface normals to be defined analytically.
--
-- David Manura, 2007-01.
-- (c) 2007 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0)

simion.workbench_program()

-- Load the secondary emission support functionality.
simion.import("secondarylib.lua")

-- Compute a normal vector analytically
-- at given position (x,y,z) in mm workbench coordinates.
-- This is used by secondarylib.lua to define the surface
-- normal vector analytically.
-- This is used only if secondary_normal_mode == 2.
function secondary_user_normal(x, y, z)
  local nx, ny, nz
  if x <= 105 then -- left sphere
    nx = 105 - x; ny = 0 - y; nz = 0 - z  -- toward sphere origin
  elseif abs(sqrt(y^2 + z^2) - 100) < 0.01 then  -- lateral sides
    nx = 0; ny = -y; nz = -z  -- toward axis
  elseif abs(x - 205) < 0.01 then -- right side
    nx = -1; ny = 0; nz = 0   -- -X direction
  else
    -- unknown, so leave undefined, causing a splat.
  end
  return nx, ny, nz
end

-- Compute time (usec) it will take particle to hit surface.
-- Return nil if it will not hit.
-- This is used by secondarylib.lua to define the surface analytically.
-- This is only used if secondary_normal_mode == 2 and secondary_offset_gu > 0.
function secondary_user_time_to_surface(x, y, z, vx, vy, vz)
  return (x <= 105) and secondary_time_to_sphere(105,0,0, 100, x,y,z, vx,vy,vz)
         or nil
end

-- Incorporate secondary emission effects in this workbench.
segment.other_actions = secondary_other_actions

