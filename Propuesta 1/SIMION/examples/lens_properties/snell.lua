--[[
 snell.lua - SIMION Lua workbench user program.
 Demonstrates Snell's Law

 D.Manura, 2007-10-03
 (c) 2007-2011 Scientific Instrument Services, Inc. (Licensed SIMION 8.0/8.1)
--]]

simion.workbench_program()


--## SECTION: SIMION SEGMENTS


-- KE's of particles (eV)
local V1  -- before deflection
local V2  -- after deflection

-- Angles (relative to axis) of particles (rad)
local a1  -- before deflection
local a2  -- after deflection

-- Get kinetic energy of current particle.
-- Intended to be called from initialize, other_actions, or terminate segments.
local function get_ke()
  local speed = math.sqrt(ion_vx_mm^2+ion_vy_mm^2+ion_vz_mm^2)
  return speed_to_ke(speed, ion_mass)
end

-- The SIMION other_actions segment handles each particle time step.
function segment.other_actions()
  if ion_time_of_flight - ion_time_step == 0 then
    -- At start.
    V1 = get_ke()
    a1 = math.atan(ion_vy_mm / ion_vx_mm)
  elseif ion_splat ~= 0 then
    -- At termination.
    V2 = get_ke()
    a2 = math.atan(ion_vy_mm / ion_vx_mm)

    print('n=', ion_number, 'V1=', V1, 'V2=', V2, 'a1=', a1, 'a2=', a2)
    print('Test of Snell\'s Law: sqrt(V1/V2)*sin(a1)/sin(a2)=', 
          math.sqrt(V1/V2)*sin(a1)/sin(a2),
          a1 ~= 0 and '(expected = 1)' or '(a1=a2=0)')
  end
end
