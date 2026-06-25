-- ref70.lua - SIMION workbench user program.
-- 
-- Simulation of grid lensing using instance hopping (ion jumping trick).
--
-- (c) 1996-2008 Scientific Instrument Services, Inc. (Licensed under SIMION 8.0).
-- based on code by Steve Colby, 1996. converted to Lua, D.Manura, 2008-10.

simion.workbench_program()

if checkglobals() then checkglobals() end

adjustable grid_inst_x = 135   -- size of grid instance in x dim, 135 for full size
adjustable grid_inst_y = 135   -- size of grid instance in x dim, 135 for full size
adjustable grid_inst_z = 271   -- size of grid instance in x dim, 271 for full size
adjustable scaling = 0.004     -- mm/grid unit, use 0.004 for full size instance
adjustable seed_value = 4      -- for random # generation change befor runs
adjustable threshold = 0.60    -- fraction (used to detect traversal of grid)

adjustable hide_jumps = 0      -- whether to hide jumping in ion trajectory
                               -- trace (1=yes,0=no).  Set to 0 for debugging,
                               -- 1 for cleaner display.

-- These tables map ion number to some parameters for that ion.
local old_grad_x = {}      -- voltage x gradient
local old_grad_y = {}      -- voltage y gradient
local old_grad_z = {}      -- voltage z gradient
local new_grad_z = {}      -- voltage z gradient (new)
local old_posit_x = {}     -- z position
local old_posit_y = {}     -- y position
local old_posit_z = {}     -- z position
local old_TOF = {}         -- time-of-flight
local sign_changed = {}    -- changed sign of x velocity? (true/false)
local jump_state = {}      -- jump state: nil, 'outside', 'inside'
local excess_energy = {}   -- extra energy from going through grid (eV)
--local old_color = {}

local initialized          -- whether random number generator is initialized.

-- instance_class[M] identifies the class of PA instance number M.  This
-- affects how particles behave inside that instance.  Possible values are
--
--   'hop'  -- ion jumping array
--   'grid' -- fine grid
--   nil    -- other
local instance_class = {
  [1] = 'hop',
  [2] = 'hop',
  [3] = 'hop',
  [4] = 'hop',
  [5] = 'grid',
  [6] = 'hop',
  [7] = 'hop',
  [8] = nil
}
  

function segment.initialize()
  -- seed random number generator.  Note: seeding can take fairly long, so
  -- ensure it is only done once.
  if not initialized then
    initialized = true
    rand() -- avoid bug http://simion.com/514 in older SIMION's.
    seed(seed_value)
  end
end


-- Jump particle from original location to fine grid.
local function jump_in()
  local N = ion_number

  -- print("DEBUG:making jump")
  beep()

  -- save particle state upon entering grid and prior to jump.
  old_TOF[N] = ion_time_of_flight
  new_grad_z[N] = ion_dvoltsz_mm  -- gradient on other side of grid
  old_posit_x[N] = ion_px_mm
  old_posit_y[N] = ion_py_mm
  old_posit_z[N] = ion_pz_mm
  --old_color[N] = ion_color
      
  -- Jump to grid instance. 
  -- randomly position in XY (only middle opening which is 2/3 of 1/2).
  -- Z position is one grid unit in.
  -- This works because the instance is centered at 0,0,0 in grid and
  -- workbench coordinates.
  ion_py_mm = (rand() - 0.5) * grid_inst_y * (2/3) * scaling
  ion_px_mm = (rand() - 0.5) * grid_inst_x * (2/3) * scaling
  ion_pz_mm = scaling
  -- print("DEBUG:jump to", ion_px_mm, ion_py_mm, ion_px_mm)

  -- if velocity is negative, set a positive velocity and remember
  -- that we changed the sign.
  if ion_vz_mm < 0 then
    ion_vz_mm = - ion_vz_mm
    sign_changed[N] = true
  else
    sign_changed[N] = false
  end

  -- hide trajectories during jump
  if hide_jumps ~= 0 then
    sim_trajectory_image_control = 3
  end

  -- We are now inside the fine grid instance.
  jump_state[N] = 'inside'
end


-- Jump particle from fine grid back to original location.
local function jump_out()
  local N = ion_number

  -- restore particle state to values prior to jump
  ion_time_of_flight = old_TOF[N]
  ion_px_mm = old_posit_x[N]
  ion_py_mm = old_posit_y[N]
  ion_pz_mm = old_posit_z[N]
    
  -- adjust for extra energy (subtract energy from current energy)
  ion_vz_mm = ke_to_speed(speed_to_ke(ion_vz_mm, ion_mass)
                                          - excess_energy[N], ion_mass)

  -- restore if we changed sign of velocity
  if sign_changed[N] then
    ion_vz_mm = - ion_vz_mm
  end

  -- hide trajectories during jump
  if hide_jumps ~= 0 then
    sim_trajectory_image_control = 3
  end

  -- We are not outside the fine grid instance.  Note: set to nil initially
  -- (rather than "outside") to prevent jump again on the first pass back.
  jump_state[N] = nil
end


function segment.other_actions()
  if instance_class[ion_instance] == 'hop' then
    -- When particle is inside a "hop" instance, 
    -- handle particle jumping into and out of fine grid instance.

    local N = ion_number

    if jump_state[N] == 'inside' then
      -- Particle was inside fine grid instance and is not just exiting that
      -- instance.

      jump_out()

    else
      -- Particle was not inside fine grid instance.
      -- (jump_state[N] is "outside" or nil)

      -- restore trajectory recording (in case this follows a jump)
      if hide_jumps ~= 0 then
        sim_trajectory_image_control = 0
      end

      -- This code is not executed on first time through...
      if jump_state[N] == 'outside' then
        -- Look for a significant change in voltage gradient.
        -- This occurs when traversing a grid.  Jump to the fine
        -- grid instance this happens.
        local diff = abs(old_grad_z[N] - ion_dvoltsz_mm)
        --print('DEBUG',ion_px_mm,diff, old_grad_z[N], ion_dvoltsz_mm)
        if diff >= 0.0001 then
          if diff > abs(ion_dvoltsz_mm * threshold) then

            jump_in()
            return

          end
        end
      end
      jump_state[N] = 'outside'

      -- save voltage gradient prior to traversing grid.
      old_grad_x[N] = ion_dvoltsx_mm
      old_grad_y[N] = ion_dvoltsy_mm
      old_grad_z[N] = ion_dvoltsz_mm
    end

  else -- not inside "hop" instance

    -- restore trajectory recording (after any jump)
    if hide_jumps ~= 0 then
      sim_trajectory_image_control = 0
    end

  end

end


function segment.fast_adjust()
  if instance_class[ion_instance] == 'grid' then
    -- Set fine grid electrode potentials to match fields at
    -- location ion is jumping from.

    local N = ion_number

    -- distance between grid and edge.
    -- This is half the x grid units of the instance
    -- times mm/gu of grid instance.
    local dist = (grid_inst_z / 2) * ion_mm_per_grid_unit

    -- ion is moving away from this side
    adj_elect01 = - dist * old_grad_z[N]
  
    -- ion is moving toward this side
    adj_elect02 = dist * new_grad_z[N]

    -- store the z-component of the energy difference in traversing the grid.
    -- This must be subtracted from the KE after jumping.
    excess_energy[N] = adj_elect01 - adj_elect02
  end
end
   
