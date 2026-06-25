--[[
 random.lua - randomize ions

 The program demonstrates how to apply some randomization to the
 defined kinetic energies and velocity directions of ions originating in
 the potential array associated with this program.

 The NEW KE of each ion is randomized by a factor of
 +- (percent_energy_variation %) with respect to the defined value.

 The NEW DIRECTION of each ion is randomized within a cone of revolution
 around the defined velocity direction.  The angle of this cone
 is taken to be +- cone_half_angle degrees.

 Upon compilation, this SL program can be used as an exact replacement
 for the RANDOM.PRG program in the _Random example of SIMION 7.0.

 2012-08-15,D.Manura
 (c) 2006-2012 Scientific Instrument Services, Inc. (Licensed SIMION 8.1)
--]]

simion.workbench_program()

-- energy variation (in percent). must be in the interval [0, 100]
adjustable percent_energy_variation = 50

-- cone angle (in degrees).  must be in the interval [0, 180]
adjustable cone_half_angle =  90

-- Randomize particle's velocity (direction and magnitude)
function randomize_particle()

    -- First, let's check user input....

    -- Ensure 0 <= percent_energy_variation <= 100.
    percent_energy_variation = min(abs(percent_energy_variation),100)
    -- Ensure 0 <= cone_half_angle <= 180.
    cone_half_angle = min(abs(cone_half_angle),180)

    -- Now, let's do the actual randomization....

    -- Convert ion velocity to 3-D polar coordinates.
    local speed, az_angle, el_angle
        = rect3d_to_polar3d(ion_vx_mm, ion_vy_mm, ion_vz_mm)
 
    -- Randomize ion's defined KE.
    local new_ke = speed_to_ke(speed, ion_mass)
             * (1 + (percent_energy_variation / 100) * (2 * rand() - 1))
    -- Convert new KE back to ion speed, and set it.
    speed = ke_to_speed(new_ke, ion_mass)
 
    -- Now, to randomize the ion velocity direction, we first do the below
    -- to make the ion's possible random velocity directions fill a solid cone
    -- with vertex at the origin and axis oriented along the positive y-axis.
    -- The angle that the cone side makes with the cone axis will be
    -- the cone_half_angle value.

    -- randomize elevation angle: (90 +- cone_half_angle)
    local new_el = 90 + cone_half_angle * (2*rand()-1)
    -- randomize azimuth angle: (0 +-90)
    local new_az = 90 * (2*rand()-1)

    -- Now that we generated this randomized cone, we will rotate it
    -- so that the expected ion velocity direction matches the ion's
    -- original velocity direction.
 
    -- Convert to rectangular velocity components.
    local x, y, z = polar3d_to_rect3d(speed, new_az, new_el)
    -- Rotate back to defined elevation.
    x, y, z = elevation_rotate(-90 + el_angle, x, y, z)
    -- Rotate back to defined azimuth.
    ion_vx_mm, ion_vy_mm, ion_vz_mm = azimuth_rotate(az_angle, x, y, z)
end

-- SIMION intialize segment.  Called for each particle construction.
function segment.initialize()
    randomize_particle()
end
