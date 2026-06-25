# collision_hs1.sl
# A hard-sphere, elastic, ion-neutral collision model for SIMION 7 (or 6).
#
# Note to SIMION 8 Users: A slightly more updated and documented
#   Lua version of this code is included in SIMION 8
#   (collision_hs1 example).  It's recommended you use that version instead.
#
# The code implements a rather complete hard-sphere collision model.
# Collision models are useful for simulating non-vacuum conditions, in
# which case ions collide against a background gas and are deflected
# randomly.
#
# Features and assumptions of the model:
# - Ion collisions follow the hard-sphere collision model.
# - Ion collisions are elastic.
# - Background gas is assumed neutral in charge.
# - Background gas velocity follows the Maxwell-Boltzmann distribution.
# - Background gas mean velocity may be non-zero.
# - Kinetically cooling and heating collisions are simulated.
# - Background gas as a whole is unaffected by ion collisions.
#
# Note on time-steps: each individual ion-gas collision is modeled,
# which requires the time-step to be some fraction of mean-free-path.
# Therefore, simulations with frequent collisions (i.e. higher
# pressure) can be computationally intensive.
#
# This code does not account for absorptions (e.g. when using electrons
# rather than ions).  That can be easily supported by setting ion_splat,
# likely as a function of impact_offset.
#
# The code has been influenced by a variety of prior SIMION hard-sphere
# collision models:
#
# [Dahl] _Trap/INJECT.PRG in SIMION 7.0
# [Dahl2] http://www.simion.com/examples/dahl_drag.prg
# [Appelhans2001] http://dx.doi.org/10.1016/S1387-3806(02)00627-9
# [Ding2002] http://dx.doi.org/10.1016/S1387-3806(02)00921-1
# [Ling1997] http://dx.doi.org/10.1002/(SICI)1097-0231(19970830)11:13<1467::AID-RCM54>3.0.CO;2-X
#
# HISTORY:
#   REV-4 made this correction:
#   Issue I362 - HS1 collision model does not accurately thermalize.
#   http://www.simion.com/issue/362
#
# David Manura.  REV-4 (200702)
# (c) Scientific Instrument Services, Inc. 2006-2007.

# Mean free path (MFP) (mm)
# Set to -1 to calculate this automatically from pressure and temperature.
adjustable _mean_free_path_mm =   -1

# Mean number of time steps per MFP.
adjustable _steps_per_MFP = 20.0

# Mass of background gas particle (amu)
adjustable _gas_mass_amu = 4.0

# Background gas temperature (K)
adjustable _temperature_k = 273.0

# Collision marker flag.
# If non-zero, markers will be placed at the collisions.
adjustable _mark_collisions = 1

# Background gas pressure (Pa)
# Note: (Pa/mtorr) = 0.13328.
adjustable _pressure_pa = 0.53

# Collision-cross section (m^2)
# (The collision diameter is roughly the sum of the diameters
#  of the colliding ion and buffer gas particles.)
# (2.1E-19 is roughly for two Helium atoms--Atkins1998-Table 1.3)
adjustable _sigma_m2 = 2.27E-18


# Mean background gas velocity (mm/usec) in x,y,z directions.
# Normally, these are zero.
adjustable _vx_bar_gas_mmusec = 0
adjustable _vy_bar_gas_mmusec = 0
adjustable _vz_bar_gas_mmusec = 0

#-- Internal variables

# Statistics
adjustable[100] ion_ke_totals
adjustable[100] ion_distance_totals
adjustable[100] ion_collision_totals

# Currently used mean-free path (-1 = undefined).
static effective_mean_free_path_mm = -1

# Last known ion speed (-1 = undefined).
static last_speed_ion = -1

# Last known ion number (-1 = undefined).
static last_ion_number = -1

# Error function (erf).
#   erf(z) = (2/sqrt(PI)) * integral[0..z] exp(-t^2) dt
# This algorithm is quite accurate.  It is based on
# "Q-Function Handout" by Keith Chugg:
#   http://tesla.csl.uiuc.edu/~koetter/ece361/Q-function.pdf
# See also http://www.theorie.physik.uni-muenchen.de/~serge/erf-approx.pdf
# I also find that the following makes a reasonable approximation:
#   1 - exp(-(2/sqrt(PI))x - (2/PI)x^2)
sub erf(z) returns(res)
    z2 = abs(z)
    t = 1 / (1 + 0.32759109962 * z2)
    res = (    - 1.061405429 ) * t
    res = (res + 1.453152027 ) * t
    res = (res - 1.421413741 ) * t
    res = (res + 0.2844966736) * t
    res =((res - 0.254829592 ) * t) * exp(-z2*z2)
    res = res + 1
    if z < 0
        res = -res
    endif
endsub

sub initialize
endsub

sub tstep_adjust
    # Ensure time steps are sufficiently small.  They should be some
    # fraction of mean-free-path so that collisions are not missed.
    if effective_mean_free_path_mm > 0
        # Get speed
        (speed, unused, unused) =
            rect3d_to_polar3d(ion_vx_mm, ion_vy_mm, ion_vz_mm)

        # Limit time-step
        tmax = effective_mean_free_path_mm / speed / _steps_per_MFP
        if ion_time_step > tmax
            ion_time_step = tmax
        endif
    endif
    unused = unused
endsub

sub other_actions
    if _pressure_pa == 0  # if collisions disabled
        effective_mean_free_path_mm = -1
        exit
    endif

    # Define constants
    k = 1.3806505e-23       # Boltzmann constant (J/K)
    #  R = 8.3145            # Ideal gas constant (J/(mol*K))
    kg_amu = 1.6605402e-27  # (kg/amu) conversion factor
    PI = 3.1415926535       # PI constant
    #eV_J = 6.2415095e+18    # (eV/J) conversion factor

    # Translate ion velocity (mm/us) frame of reference such
    # that mean background gas velocity is zero.
    # This simplifies the subsequent analysis.
    vx = ion_vx_mm - _vx_bar_gas_mmusec
    vy = ion_vy_mm - _vy_bar_gas_mmusec
    vz = ion_vz_mm - _vz_bar_gas_mmusec

    # Convert ion velocity vector to polar coordinates (mm/us).
    speed_ion = sqrt(vx*vx + vy*vy + vz*vz)
    if speed_ion < 1E-7
         speed_ion = 1E-7  # prevent divide by zero and such effects later on
    endif

    #=== Notes on Mean-Free-Path ===
    # The mean-free-path (lambda) is generally a function of the mean
    # relative speed (c_bar_rel) between the ion and moving background
    # gas:
    #   lambda = (c_ion/c_bar_rel) / (n * sigma)
    # where
    #   c_ion is ion speed
    #   c_bar_rel is the mean relative speed between ion and moving
    #     background gas
    #   n is the number of gas particles per unit volume
    #   sigma is the collision cross section (roughly, the area with
    #      a diameter equal to the sum of the diameters of the
    #      colliding ion and gas particles)
    #
    # Mean relative speed (c_bar_rel) is formally determined by
    #   c_bar_rel = tripple_integral |v_ion - v_gas| * f(v_gas) dv_gas
    # where
    #   f(v) is the product of the one-dimensional Maxwell
    #   in all three dimensions:
    #     f(v) = (m_gas / (2*pi*k*T))^(3/2) * exp(-m*v^2 / (2*k*T))
    # which evaluates to
    #   c_bar_rel = c_bar_gas * (s + 1/(2*s)) * 0.5 * sqrt(PI) * erf(s) +
    #                            (1/2)*exp(-s^2))      (s > 0)
    # where
    #   s = c_ion/c_star_gas
    #   c_bar_gas  = sqrt(8*k*T_b/pi/m_b) is the mean gas speed
    #   c_star_gas = sqrt(2*k*T_b/m_b)    is the median gas speed
    #
    # This approach is recommended by Ding2002.
    #
    # Ling1997 uses a simpler (and almost as suitable)
    # approximation for c_bar_rel:
    #   c_bar_rel ~= sqrt(c_ion^2 + c_bar_gas^2)
    #===

    # Compute effective mean-free-path (or use a specific value).
    if _mean_free_path_mm < 0   #...using current ion velocity
        # Note: only recompute mean-free-path if speed_ion has
        # changed significantly. This is intended to speed up the
        # calculation a bit.  Handles flying ions by groups too.
        if last_ion_number != ion_number or
                abs(speed_ion / last_speed_ion - 1) > 0.05
            # Compute mean gas speed (mm/us)
            c_bar_gas = sqrt(8*k*_temperature_k/PI/(_gas_mass_amu * kg_amu)) / 1000

            # Compute median gas speed (mm/us)z
            c_star_gas = sqrt(2*k*_temperature_k/(_gas_mass_amu * kg_amu)) / 1000

            # Compute mean relative speed (mm/us)
            s = speed_ion / c_star_gas
            c_bar_rel = c_bar_gas * (
                (s + 1/(2*s)) * 0.5 * sqrt(pi) * erf(s) + 0.5 * exp(-s*s))

            # Compute mean-free-path (mm)
            effective_mean_free_path_mm = 1000 * k * _temperature_k *
                (speed_ion / c_bar_rel) / (_pressure_pa * _sigma_m2)

            last_speed_ion = speed_ion
            last_ion_number = ion_number
        endif
    else  #...using specified value
        effective_mean_free_path_mm = _mean_free_path_mm
    endif
    #print("DEBUG:ion[c=#],gas[c_bar=#],c_bar_rel=#, MFP=#",
    #      speed_ion, c_bar_gas, c_bar_rel, effective_mean_free_path_mm)

    # Compute collision probability per distance traveled
    collision_prob = 1 -
        exp(- speed_ion * ion_time_step / effective_mean_free_path_mm)

    # Was there a collision?
    if rand() > collision_prob
        exit
    endif

    #--- collisions

    # Compute standard deviation of gas velocity in one dimension (mm/us).
    # The following is derived from kinetic gas theory.
    vr_stdev_gas =
        sqrt(k * _temperature_k / (_gas_mass_amu * kg_amu)) / 1000

    # Compute a normalized Gaussian random variable (-inf, +inf).
    # This uses the Box-Muller algorithm.
    # rand1-3 are Gaussian random variables.
    s = 1
    while s >= 1
        v1 = 2*rand() - 1
        v2 = 2*rand() - 1
        s = v1*v1 + v2*v2
    endwhile
    # (assume divide by zero improbable?)
    rand1 = v1*sqrt(-2*ln(s) / s)
    rand2 = v2*sqrt(-2*ln(s) / s)
    s = 1
    while s >= 1
        v1 = 2*rand() - 1
        v2 = 2*rand() - 1
        s = v1*v1 + v2*v2
    endwhile
    rand3 = v1*sqrt(-2*ln(s) / s)

    vx_gas = rand1 * vr_stdev_gas
    vy_gas = rand2 * vr_stdev_gas
    vz_gas = rand3 * vr_stdev_gas

    # Or a slightly more correct thing might be to make probability
    # of (vx_gas,vy_gas,vz_gas) proportional to
    # |v_gas - v_ion| as well (see Lua version)

    # Translate velocity reference frame so that colliding
    # background gas particle is stationary.
    # > This simplifies the subsequent analysis.
    vx = vx - vx_gas
    vy = vy - vy_gas
    vz = vz - vz_gas

    # > Notes on collision orientation
    #   A collision of the ion in 3D can now be reasoned in 2D since
    #   the ion remains in some 2D plane before and after collision.
    #   The ion collides with an gas particle initially at rest (in the
    #   current velocity reference frame).
    #   For convenience, we define a coordinate system (r, t) on the
    #   collision plane.  r is the radial axis through the centers of
    #   the colliding particles, with the positive direction indicating
    #   approaching particles.  t is the tangential axis perpendicular to r.
    #   An additional coordinate theta defines the the rotation of the
    #   collision plane around the ion velocity axis.

    # Compute randomized impact offset [0, 1) as a fraction
    # of collisional cross-section diameter.
    # The probability of a given impact_offset is made
    # proportional to impact_offset^2.
    # Note: 0 is a head-on collision; 1 would be a near miss.
    impact_offset = sqrt(0.999999999 * rand())

    # Compute randomized impact angle [0, +PI/2) (radians)
    # between ion velocity vector and radial axis.
    # Note: 0 is a head-on collision; +PI/2 would be a near miss.
    impact_angle = asin(impact_offset)

    # Compute randomized angle [0, 2*PI] for rotation of collision
    # plane around radial axis.
    # Note: all angles are equally likely.
    impact_theta = 2*PI*rand()

    # Compute polar coordinates in current velocity reference frame.
    (speed_ion_r, az_ion_r, el_ion_r) = rect3d_to_polar3d(vx, vy, vz)

    # Compute ion velocity components (mm/us).
    # Note: this choice of coordinates ensures that the vector is
    # always in the first (+/+) quadrant.
    vr_ion = speed_ion_r * cos(impact_angle)    #.. radial velocity
    vt_ion = speed_ion_r * sin(impact_angle)    #.. normal velocity

    # Attenuate ion velocity due to elastic collision.
    # This is the standard equation for a one-dimensional
    # elastic collision, assuming the other particle is initially at rest
    # (in the current reference frame).
    # Note that the force acts only in the radial direction, which is
    # normal to the surfaces at the point of contact.
    vr_ion2 = (vr_ion * (ion_mass - _gas_mass_amu))
              / (ion_mass + _gas_mass_amu)

    # Rotate velocity frame of reference so that original ion velocity
    # vector is on the +y axis.
    # Note: The angle of the new velocity vector with respect to the
    # +y axis then represents the deflection angle.
    (vx, vy, vz) = elevation_rotate(
        90-degrees(impact_angle), vr_ion2, vt_ion, 0)

    # Rotate velocity frame of reference around +y axis.
    # This rotates the deflection angle and in effect chooses the
    # collision plane (impact_theta), which was left unchosen before.
    (vx, vy, vz) = azimuth_rotate(degrees(impact_theta), vx, vy, vz)

    # Rotate velocity frame of reference back to the original.
    (vx, vy, vz) = elevation_rotate(-90 + el_ion_r, vx, vy, vz)
    (vx, vy, vz) = azimuth_rotate(az_ion_r, vx, vy, vz)

    # Translate velocity frame of reference back to the original.
    # This undoes the prior two translations that make velocity
    # relative to the colliding gas particle.
    vx = vx + vx_gas + _vx_bar_gas_mmusec
    vy = vy + vy_gas + _vy_bar_gas_mmusec
    vz = vz + vz_gas + _vz_bar_gas_mmusec

    # Set new velocity vector.
    (ion_vx_mm, ion_vy_mm, ion_vz_mm) = (vx, vy, vz)

    # Now lets compute some statistics...

    # Calculate new ion speed and KE.
    (speed_ion2, unused, unused) =
        rect3d_to_polar3d(ion_vx_mm, ion_vy_mm, ion_vz_mm)
    ke2_ion = speed_to_ke(speed_ion2, ion_mass)

    # Compute mean gas KE
    #ke_bar_gas = (
    #    (3/2) * k * _temperature_k +
    #    (1/2) * (_gas_mass_amu * kg_amu) * (
    #        _vx_bar_gas_mmusec*_vx_bar_gas_mmusec +
    #        _vy_bar_gas_mmusec*_vy_bar_gas_mmusec +
    #        _vz_bar_gas_mmusec*_vz_bar_gas_mmusec
    #    ) * 1e+6
    #) * eV_j
    #print("DEBUG:ion[ke=#],gas[ke=#]", ke2_ion, ke_bar_gas)

    # Record KE after collisions.  This is later used to compute average KE.
    if ion_number <= 100
        ion_ke_totals[ion_number] = ion_ke_totals[ion_number] + ke2_ion
        ion_collision_totals[ion_number] = ion_collision_totals[ion_number] + 1
    endif

    if _mark_collisions != 0
        mark()
    endif
    unused = unused
endsub


sub terminate
    # Display some statistics.
    # Note: At equilibrium, the ion and gas KE become roughly equal.
    if ion_number <= 100
        k = 1.3806505e-23       # Boltzmann constant (J/K)
        eV_J = 6.2415095e+18    # (eV/J) conversion factor

        ke_bar = ion_ke_totals[ion_number] /
            (ion_collision_totals[ion_number] + 1E-10)
        T_bar = ke_bar / eV_J / (1.5 * k)
        print("ion=#, collisions=#, mean KE=# eV, mean T=# K",
              ion_number, ion_collision_totals[ion_number], ke_bar, T_bar)
    endif
endsub


#sub efield_adjust
#     # For testing, apply a quadratic potential well
#     # to trap ions in.  The kinetic cooling of the buffer
#     # gas causes ions to collect near the center of the well.
#     #   V(x,y,z) = x*x + y*y* + z*z = r*r
#     #   E(x,y,z) = -(2*x, 2*y, 2*z)
#    r_max = 100   # radius
#    V_max = 10    # voltage at r_max
#    a = 2 * V_max / (r_max * r_max)
#    ion_dvoltsx_gu = ion_px_gu * a
#    ion_dvoltsy_gu = ion_py_gu * a
#    ion_dvoltsz_gu = ion_pz_gu * a
#endsub
