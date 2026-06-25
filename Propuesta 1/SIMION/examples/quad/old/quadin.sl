#=======================================================================
# quadin.sl - Quadrupole entrance electrode.
#
# HISTORY:
# 2003-11 - ported to SL (D.J.Manura, Scientific Instrument Services, Inc.)
#           Based on QUADIN.PRG example in SIMION 7.0 (David A. Dahl).
# $Revision$ $Date$
#=======================================================================

import "quadvars.sl" 

#===== variables

static first = 1    # first call flag
static next_pe_update_in =  0.0   # next PE surface update time.

#===== subroutines 

# Randomize ion's KE, velocity direction, and position.
sub initialize

    # First, let's check user input....

    # Ensure 0 <= percent_energy_variation <= 100.
    percent_energy_variation = min(abs(percent_energy_variation), 100)
    # Ensure 0 <= cone_angle_off_vel_axis <= 180.
    cone_angle_off_vel_axis = min(abs(cone_angle_off_vel_axis), 180)
 
    # Convert ion velocity to 3-D polar coordinates.
    (speed, az_angle, el_angle)
        = rect3d_to_polar3d(ion_vx_mm, ion_vy_mm, ion_vz_mm)

    #-----
    # Here we randomize the ion's KE and direction.  (This code is near
    # identical to the code in random.sl.)
 
    # Randomize ion's defined KE.
    kinetic_energy = speed_to_ke(speed, ion_mass)
        * (1 + (percent_energy_variation / 100) * (2 * rand() - 1))
    # Convert new KE back to ion speed, and set it.
    speed = ke_to_speed(kinetic_energy, ion_mass)

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
 
    # Randomize ion's position components.
    ion_py_mm = ion_py_mm + random_offset_mm * (rand() - (1/2))
    ion_pz_mm = ion_pz_mm + random_offset_mm * (rand() - (1/2))
 
    # Randomize ion's time of birth.
    ion_time_of_birth = abs(random_tob) * rand()
endsub 
 
# Generate trap RF.
sub fast_adjust
    if first == 1    # initialize values
        first = 0
 
        # Initialize constants.
        scaled_rf = effective_radius_in_cm * effective_radius_in_cm
            * frequency_hz * frequency_hz * 7.11016e-12
        theta = radians(phase_angle_deg)
        omega = frequency_hz * 6.28318E-6
    endif

    # Set electrode potentials.

    adj_elect03 = _quad_entrance_voltage

    # Note: these can be adjusted during the simulation, so they
    # must be recalculated.
    rfvolts = scaled_rf * _amu_mass_per_charge
    dcvolts = rfvolts * _percent_tune / 100 * 0.1678399
 
    tempvolts = sin(ion_time_of_flight * omega + theta) * rfvolts + dcvolts
    adj_elect01 = _quad_axis_voltage + tempvolts
    adj_elect02 = _quad_axis_voltage - tempvolts
endsub
 
 
 
# Update potential energy surface display periodically.
sub other_actions
    if ion_time_of_flight >= next_pe_update_in 
        next_pe_update_in = ion_time_of_flight + pe_update_each_usec
        update_pe_surface = 1       # Request a PE surface display update.
    endif
endsub
