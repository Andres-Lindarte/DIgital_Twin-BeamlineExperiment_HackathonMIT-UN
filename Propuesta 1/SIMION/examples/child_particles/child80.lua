--[[
 child80.lua
 SIMION Lua workbench user program for creating multiple child
 particles from each parent particle.
 This version is compatible with SIMION 8.0/8.1 and uses some special tricks
 since the SIMION 8.2 particle API is not available.
 See README.html for details.

 Note: This program ASSUMES particles are flown individually
 ("Grouped" disabled).

 2007-04,2012-09-10,D.Manura
 (c) 2006-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.0/8.1)
--]]

simion.workbench_program()

-- Queue of child particles to fly for current parent particle.
local child_particles = {}

-- Scheduled value of ion_splat for next time-step (or nil if unset).
local next_ion_splat

-- Whether debug print messages are enabled (1=yes,0=no)
adjustable is_debug = 1

-- Add a new child particle using the parameters
-- in table t.  Parameters can be omitted, in which case
-- they default to the values of the current particle.
local function add_particle(t)
  local particle = {}
  particle.tob = t.tob or ion_time_of_birth
  particle.tof = t.tof or ion_time_of_flight
  particle.mass = t.mass or ion_mass
  particle.charge = t.charge or ion_charge
  particle.px = t.px or ion_px_mm
  particle.py = t.py or ion_py_mm
  particle.pz = t.pz or ion_pz_mm
  particle.vx = t.vx or ion_vx_mm
  particle.vy = t.vy or ion_vy_mm
  particle.vz = t.vz or ion_vz_mm
  particle.color = t.color or ion_color

  child_particles[#child_particles+1] = particle  -- append

  return particle
end

-- SIMION segment called by SIMION after every time-step.
function segment.other_actions()
  -- Turn trajectory recording on (in case it was previously turned off).
  sim_trajectory_image_control = 0  -- YES,YES

  -- Handle scheduled particle terminations from previous time-step.
  if next_ion_splat then
    ion_splat = next_ion_splat
    next_ion_splat = nil
  end

  if ion_splat ~= 0 then  -- particle is terminating.
    if #child_particles > 0 then  -- child particles exist
      ion_splat = 0  -- prevent termination to fly children

      -- Transform current particle into next scheduled child.
      local data = table.remove(child_particles, 1)
      if is_debug ~= 0 then print("DEBUG: init child", ion_number) end
      ion_time_of_birth  = data.tob
      ion_time_of_flight = data.tof
      ion_mass   = data.mass
      ion_charge = data.charge
      ion_px_mm  = data.px
      ion_py_mm  = data.py
      ion_pz_mm  = data.pz
      ion_vx_mm  = data.vx
      ion_vy_mm  = data.vy
      ion_vz_mm  = data.vz
      ion_color  = data.color
      -- Prevent drawing trajectory line due to manual particle movement.
      sim_trajectory_image_control = 3  -- NO,NO
      -- Add a mark at location of child particle creation.
      -- This is useful for both display and data recording (record on marks).
      mark()
    end
  end

  -- Simulate some type of interaction (just as an example).
  if ion_px_mm > 50 and ion_color == 1 then
    if is_debug ~= 0 then print("DEBUG: new children at", ion_px_mm) end
    add_particle{mass = 0.000548579903, charge = -1,
                 vx = 1, vy = 1, color = 2}
    add_particle{mass = 1, charge = 1, vx = 1, vy = -1, color = 3}
    -- splat at start of next time-step (not this one)
    next_ion_splat = -2  -- dead in water
  end
  
end
