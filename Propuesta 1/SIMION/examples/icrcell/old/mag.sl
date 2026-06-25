#=======================================================================
# mag.sl
#
# ICR simulation program (creates magnetic field)
#
# HISTORY:
# 2003-11 - ported to SL (D.J.Manura, Scientific Instrument Services, Inc.)
# 1995 - MAG.PRG example in SIMION <= 7.0 (D.A.Dahl and A.D.Appelhans)
#
#=======================================================================
 
#----- adjustable variables
 
adjustable bx_gauss = 30000                 # magnetic field in gauss
                               
adjustable percent_energy_variation = 90.0  # (+- 10%) random energy variation
adjustable cone_angle_off_vel_axis  = 20.0  # (+- 5 deg) cone angle - sphere
adjustable random_offset_mm         =  3.0  # del start position (y,z) in mm
adjustable random_tob               =  1.0  # random time of birth
  

#----- subroutines
 
# randomize ion's position, KE, and direction
sub initialize
    # restrict 0 <= percent_energy_variation <= 100
    percent_energy_variation = min(abs(percent_energy_variation), 100)
 
    # restrict 0 <= cone_angle_off_vel_axis <= 180
    cone_angle_off_vel_axis = min(abs(cone_angle_off_vel_axis), 180)


    # convert velocity to 3D polar coords
    (speed, az_angle, el_angle)
        = rect3d_to_polar3d(ion_vx_mm, ion_vy_mm, ion_vz_mm)

    # calculate ion's defined KE
    kinetic_energy = speed_to_ke(speed, ion_mass)
 
    # compute new randomized KE
    ke_new = kinetic_energy
             * (percent_energy_variation / 100 * (2*rand()-1) + 1)
 
    # convert new KE to new speed
    speed = ke_to_speed(ke_new, ion_mass)
 
    # compute randomized el angle change 90 +- cone_angle_off_vel_axis
    # we assume elevation of 90 degrees for mean
    # so cone can be generated via rotating az +- 90
    new_el = cone_angle_off_vel_axis * (2* rand() - 1) + 90
 
    # compute randomized az angle change
    # this gives 360 effective because of +- elevation angles
    new_az = 180 * rand() - 90
 
 
    # convert to rectangular velocity components
    (x, y, z) = polar3d_to_rect3d(speed, new_az, new_el)
    # el rotate back to starting elevation
    (x, y, z) = elevation_rotate(-90 + el_angle, x, y, z)
    # az rotate back to starting azimuth
    (ion_vx_mm, ion_vy_mm, ion_vz_mm) = azimuth_rotate(az_angle, x, y, z)
 
    # randomize ion's position components 
    ion_px_mm = ion_px_mm + random_offset_mm * (rand() - 0.5)
    ion_py_mm = ion_py_mm + random_offset_mm * (rand() - 0.5)
    ion_pz_mm = ion_pz_mm + random_offset_mm * (rand() - 0.5)
 
    # randomize ion's time of birth
    ion_time_of_birth = abs(random_tob) * rand()
endsub

# magnetic field adjust
sub mfield_adjust
    ion_bfieldx_gu = bx_gauss
    ion_bfieldy_gu = 0
    ion_bfieldz_gu = 0
endsub
