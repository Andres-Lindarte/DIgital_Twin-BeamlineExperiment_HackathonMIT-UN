--[[
 SIMION Lua workbench user program for creating multiple child
 particles from each parent particle.
 This uses the new particle API available in SIMION 8.2 early access mode.
 See README.html for details.

 2012-09-10,2007-04,D.Manura
 (c) 2006-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1/8.2)
--]]

simion.workbench_program()

-- Early access mode required for simion.experimental.add_particles.
-- http://simion.com/info/early_access_mode.html
simion.early_access(8.2)

local add_particles = simion.experimental.add_particles

-- SIMION segment called by SIMION after every time-step.
function segment.other_actions()
  -- Simulate some type of interaction (just as an example).
  if ion_splat == -1 and ion_color ~= 5 then
    for i=1,3 do
      add_particles {vy=-ion_vy_mm * (1 + rand()*0.1)}
    end
  end
  if ion_px_mm > 20 and ion_color == 1 then
    add_particles {mass = 0.000548579903, charge = -1, vx = 1, vy = 1, color = 2}
    add_particles {mass = 1, charge = 1, vx = 1, vy = -1, color = 3}
    -- splat at start of next time-step (not this one)
    ion_splat = -2  -- dead in water
    mark()
  end
end

-- optionally, observe how these segments behave
function segment.initialize()
  print('initializing particle', ion_number)
  if ion_number == 1 then add_particles {x=50,y=1, color=8} end
end
function segment.initialize_run()
  add_particles {x=50, color=8}
  
  -- Add .FLY2 definitions.  Note: all FLY2 objects must be prefixed by 'F.' .
  local F = simion.fly2
  add_particles {
    F.particles {
      F.standard_beam {
        n=10,x=10,y=10,z=0,color = 5,
        direction=F.cone_direction_distribution {
          axis = F.vector(0, 1, 0),
          half_angle = 10,
          fill = false
  } } } }
  -- alternately, use short-hand for standard beams:
  add_particles {
    n=10,x=10,y=-10,z=0,color = 5,
    direction=F.cone_direction_distribution {
      axis = F.vector(0, -1, 0),
      half_angle = 10,
      fill = false
  } }
end
