--[[
 random.lua
 Example of reloading a FLY2 file from a workbench user program
 and passing adjustable variables into that FLY2 file.
 
 Based on examples\random.
 
 2012-09-19,2012-05,D.Manura
 (c) 2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()

-- energy variation (in percent). must be in the interval [0, 100]
adjustable percent_energy_variation = 50

-- cone angle (in degrees).  must be in the interval [0, 180]
adjustable cone_half_angle = 90

-- radius of starting disc (mm).
adjustable radius = 0

-- SIMION intialize segment.  Called for each particle construction.
function segment.flym()
  -- Ensure variables within legal ranges.
  assert(percent_energy_variation >= 0 and percent_energy_variation <= 100)
  assert(cone_half_angle >= 0 and cone_half_angle <= 180)
  assert(radius >= 0)

  -- Regenerate particle definitions in case FE cathode properties changed.
  local PL = simion.import 'particlelib.lua'
  PL.reload_fly2('random.fly2', {
    -- variables to pass to FLY2 file.
    percent_energy_variation=percent_energy_variation,
    cone_half_angle=cone_half_angle,
    radius=radius
  })
  
  run()
end

-- In SIMION 8.2 (or early access mode in 8.1), you can optionally
-- use the "add_particles" function to define the FLY2 object inline
-- to the workbench user program.
-- Optionally uncomment the following code.
--[[
function segment.initialize_run()
  simion.early_access(8.2)
  local F = simion.fly2
  simion.experimental.add_particles {
    F.particles {
      F.standard_beam {
        n = 20, tob = 0, mass = 100, charge = 1, cwf = 1, color = 2,
        ke = F.uniform_distribution {
          min = 0.1 * (1 + percent_energy_variation/100),
          max = 0.1 * (1 - percent_energy_variation/100)
        },
        direction = F.cone_direction_distribution {
          axis = F.vector(1, 0, 0),
          half_angle = cone_half_angle, fill = true
        },
        position = F.circle_distribution {
          center = F.vector(2, 5, 0),
          normal = F.vector(1, 0, 0),
          radius = radius, fill = false
        }
      }
    }
  }
end
--]]
