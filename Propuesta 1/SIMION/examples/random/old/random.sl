#=======================================================================
# random.sl - randomize ions
#
# The program demonstrates how to apply some randomization to the
# defined kinetic energies and velocity directions of ions originating in
# the potential array associated with this program.
#
# The NEW KE of each ion is randomized by a factor of
# +- (percent_energy_variation %) with respect to the defined value.
#
# The NEW DIRECTION of each ion is randomized within a cone of revolution
# around the defined velocity direction.  The angle of this cone
# is taken to be +- cone_angle_off_vel_axis degrees.
#
# Upon compilation, this SL program can be used as an exact replacement
# for the RANDOM.PRG program in the _Random example of SIMION 7.0.
#
# HISTORY:
# 2003-11 - ported to SL (D.J.Manura, Scientific Instrument Services, Inc.)
#           Based on the RANDOM.PRG example in SIMION 7.0.
# $Revision$ $Date$
#=======================================================================

#===== variables

# energy variation (in percent). must be in the interval [0, 100]
adjustable percent_energy_variation = 50

# cone angle (in degrees).  must be in the interval [0, 180]
adjustable cone_angle_off_vel_axis =  90

#===== subroutines

# Initialize ion's velocity and direction at the start of simulation.
sub initialize

    # First, let's check user input....

    # Ensure 0 <= percent_energy_variation <= 100.
    percent_energy_variation = min(abs(percent_energy_variation),100)
    # Ensure 0 <= cone_angle_off_vel_axis <= 180.
    cone_angle_off_vel_axis = min(abs(cone_angle_off_vel_axis),180)

    # Now, let's do the actual randomization....

    # Convert ion velocity to 3-D polar coordinates.
    (speed, az_angle, el_angle)
        = rect3d_to_polar3d(ion_vx_mm, ion_vy_mm, ion_vz_mm)
 
    # Randomize ion's defined KE.
    new_ke = speed_to_ke(speed, ion_mass)
             * (1 + (percent_energy_variation / 100) * (2 * rand() - 1))
    # Convert new KE back to ion speed, and set it.
    speed = ke_to_speed(new_ke, ion_mass)
 
    # Now, to randomize the ion velocity direction, we first do the below
    # to make the ion's possible random velocity directions fill a solid cone
    # with vertex at the origin and axis oriented along the positive y-axis.
    # The angle that the cone side makes with the cone axis will be
    # the cone_angle_off_vel_axis value.

    # randomize elevation angle: (90 +- cone_angle_off_vel_axis)
    new_el = 90 + cone_angle_off_vel_axis * (2*rand()-1)
    # randomize azimuth angle: (0 +-90)
    new_az = 90 * (2*rand()-1)

    # Now that we generated this randomized cone, we will rotate it
    # so that the expected ion velocity direction matches the ion's
    # original velocity direction.
 
    # Convert to rectangular velocity components.
    (x, y, z) = polar3d_to_rect3d(speed, new_az, new_el)
    # Rotate back to defined elevation.
    (x, y, z) = elevation_rotate(-90 + el_angle, x, y, z)
    # Rotate back to defined azimuth.
    (ion_vx_mm, ion_vy_mm, ion_vz_mm) = azimuth_rotate(az_angle, x, y, z)

endsub
