; This PRG file was automatically generated from SL source code
; using the SIS Simplified SIMION Compiler (SL) 1.0.1-2004-01-12.
; WARNING: This file will be overwritten if you recompile.

; # collision_hs1.sl
; # A hard-sphere, elastic, ion-neutral collision model for SIMION 7 (or 6).
; #
; # Note to SIMION 8 Users: A slightly more updated and documented
; #   Lua version of this code is included in SIMION 8
; #   (collision_hs1 example).  It's recommended you use that version instead.
; #
; # The code implements a rather complete hard-sphere collision model.
; # Collision models are useful for simulating non-vacuum conditions, in
; # which case ions collide against a background gas and are deflected
; # randomly.
; #
; # Features and assumptions of the model:
; # - Ion collisions follow the hard-sphere collision model.
; # - Ion collisions are elastic.
; # - Background gas is assumed neutral in charge.
; # - Background gas velocity follows the Maxwell-Boltzmann distribution.
; # - Background gas mean velocity may be non-zero.
; # - Kinetically cooling and heating collisions are simulated.
; # - Background gas as a whole is unaffected by ion collisions.
; #
; # Note on time-steps: each individual ion-gas collision is modeled,
; # which requires the time-step to be some fraction of mean-free-path.
; # Therefore, simulations with frequent collisions (i.e. higher
; # pressure) can be computationally intensive.
; #
; # This code does not account for absorptions (e.g. when using electrons
; # rather than ions).  That can be easily supported by setting ion_splat,
; # likely as a function of impact_offset.
; #
; # The code has been influenced by a variety of prior SIMION hard-sphere
; # collision models:
; #
; # [Dahl] _Trap/INJECT.PRG in SIMION 7.0
; # [Dahl2] http://www.simion.com/examples/dahl_drag.prg
; # [Appelhans2001] http://dx.doi.org/10.1016/S1387-3806(02)00627-9
; # [Ding2002] http://dx.doi.org/10.1016/S1387-3806(02)00921-1
; # [Ling1997] http://dx.doi.org/10.1002/(SICI)1097-0231(19970830)11:13<1467::AID-RCM54>3.0.CO;2-X
; #
; # HISTORY:
; #   REV-4 made this correction:
; #   Issue I362 - HS1 collision model does not accurately thermalize.
; #   http://www.simion.com/issue/362
; #
; # David Manura.  REV-4 (200702)
; # (c) Scientific Instrument Services, Inc. 2006-2007.
; 
; # Mean free path (MFP) (mm)
; # Set to -1 to calculate this automatically from pressure and temperature.
; adjustable _mean_free_path_mm =   -1
DEFA _mean_free_path_mm -1
; 
; 
; # Mean number of time steps per MFP.
; adjustable _steps_per_MFP = 20.0
DEFA _steps_per_mfp 20.0
; 
; 
; # Mass of background gas particle (amu)
; adjustable _gas_mass_amu = 4.0
DEFA _gas_mass_amu 4.0
; 
; 
; # Background gas temperature (K)
; adjustable _temperature_k = 273.0
DEFA _temperature_k 273.0
; 
; 
; # Collision marker flag.
; # If non-zero, markers will be placed at the collisions.
; adjustable _mark_collisions = 1
DEFA _mark_collisions 1
; 
; 
; # Background gas pressure (Pa)
; # Note: (Pa/mtorr) = 0.13328.
; adjustable _pressure_pa = 0.53
DEFA _pressure_pa 0.53
; 
; 
; # Collision-cross section (m^2)
; # (The collision diameter is roughly the sum of the diameters
; #  of the colliding ion and buffer gas particles.)
; # (2.1E-19 is roughly for two Helium atoms--Atkins1998-Table 1.3)
; adjustable _sigma_m2 = 2.27E-18
DEFA _sigma_m2 2.27E-18
; 
; 
; 
; # Mean background gas velocity (mm/usec) in x,y,z directions.
; # Normally, these are zero.
; adjustable _vx_bar_gas_mmusec = 0
DEFA _vx_bar_gas_mmusec 0
; 
; adjustable _vy_bar_gas_mmusec = 0
DEFA _vy_bar_gas_mmusec 0
; 
; adjustable _vz_bar_gas_mmusec = 0
DEFA _vz_bar_gas_mmusec 0
; 
; 
; #-- Internal variables
; 
; # Statistics
; adjustable[100] ion_ke_totals
ADEFA ion_ke_totals 100
; 
; adjustable[100] ion_distance_totals
ADEFA ion_distance_totals 100
; 
; adjustable[100] ion_collision_totals
ADEFA ion_collision_totals 100
; 
; 
; # Currently used mean-free path (-1 = undefined).
; static effective_mean_free_path_mm = -1
DEFS effective_mean_free_path_mm -1
; 
; 
; # Last known ion speed (-1 = undefined).
; static last_speed_ion = -1
DEFS last_speed_ion -1
; 
; 
; # Last known ion number (-1 = undefined).
; static last_ion_number = -1
DEFS last_ion_number -1
; 
; 
; # Error function (erf).
; #   erf(z) = (2/sqrt(PI)) * integral[0..z] exp(-t^2) dt
; # This algorithm is quite accurate.  It is based on
; # "Q-Function Handout" by Keith Chugg:
; #   http://tesla.csl.uiuc.edu/~koetter/ece361/Q-function.pdf
; # See also http://www.theorie.physik.uni-muenchen.de/~serge/erf-approx.pdf
; # I also find that the following makes a reasonable approximation:
; #   1 - exp(-(2/sqrt(PI))x - (2/PI)x^2)
; 
; 
; 
; 
; 
; 
; 
; #sub efield_adjust
; #     # For testing, apply a quadratic potential well
; #     # to trap ions in.  The kinetic cooling of the buffer
; #     # gas causes ions to collect near the center of the well.
; #     #   V(x,y,z) = x*x + y*y* + z*z = r*r
; #     #   E(x,y,z) = -(2*x, 2*y, 2*z)
; #    r_max = 100   # radius
; #    V_max = 10    # voltage at r_max
; #    a = 2 * V_max / (r_max * r_max)
; #    ion_dvoltsx_gu = ion_px_gu * a
; #    ion_dvoltsy_gu = ion_py_gu * a
; #    ion_dvoltsz_gu = ion_pz_gu * a
; #endsub
; 
DEFA call_stack_idx__ 0
ADEFA call_stack__ 1000
; sub initialize
SEG initialize
    EXIT
; end segment
; sub tstep_adjust
SEG tstep_adjust
    ; # Ensure time steps are sufficiently small.  They should be some
    ; # fraction of mean-free-path so that collisions are not missed.
    ; if effective_mean_free_path_mm > 0
    0
    RCL effective_mean_free_path_mm
    X<=Y
    GTO label27__
    RLUP
    RLUP
        ; # Get speed
        ; (speed, unused, unused) =
        RCL ion_vz_mm
        RCL ion_vy_mm
        RCL ion_vx_mm
        RECT3D_TO_POLAR3D
        STO speed
        RLUP
        STO unused
        RLUP
        STO unused
        RLUP
        ; 
        ; # Limit time-step
        ; tmax = effective_mean_free_path_mm / speed / _steps_per_MFP
        RCL effective_mean_free_path_mm
        RCL speed
        /
        RCL _steps_per_mfp
        /
        STO tmax
        RLUP
        ; if ion_time_step > tmax
        RCL tmax
        RCL ion_time_step
        X<=Y
        GTO label25__
        RLUP
        RLUP
            ; ion_time_step = tmax
            RCL tmax
            STO ion_time_step
            RLUP
        ; begin else
        GTO label26__
        LBL label25__
        RLUP
        RLUP
        LBL label26__
        ; end if
        ; 
    ; begin else
    GTO label28__
    LBL label27__
    RLUP
    RLUP
    LBL label28__
    ; end if
    ; 
    ; unused = unused
    RCL unused
    STO unused
    RLUP
    EXIT
; end segment
; sub other_actions
SEG other_actions
0 STO z
STO res
RLUP
    ; if _pressure_pa == 0  # if collisions disabled
    0
    RCL _pressure_pa
    X!=Y
    GTO label31__
    RLUP
    RLUP
        ; effective_mean_free_path_mm = -1
        1
        CHS
        STO effective_mean_free_path_mm
        RLUP
        ; exit
        EXIT
    ; begin else
    GTO label32__
    LBL label31__
    RLUP
    RLUP
    LBL label32__
    ; end if
    ; 
    ; 
    ; # Define constants
    ; k = 1.3806505e-23       # Boltzmann constant (J/K)
    1.3806505e-23 STO k
    RLUP
    ; #  R = 8.3145            # Ideal gas constant (J/(mol*K))
    ; kg_amu = 1.6605402e-27  # (kg/amu) conversion factor
    1.6605402e-27 STO kg_amu
    RLUP
    ; PI = 3.1415926535       # PI constant
    3.1415926535 STO pi
    RLUP
    ; #eV_J = 6.2415095e+18    # (eV/J) conversion factor
    ; 
    ; # Translate ion velocity (mm/us) frame of reference such
    ; # that mean background gas velocity is zero.
    ; # This simplifies the subsequent analysis.
    ; vx = ion_vx_mm - _vx_bar_gas_mmusec
    RCL ion_vx_mm
    RCL _vx_bar_gas_mmusec
    -
    STO vx
    RLUP
    ; vy = ion_vy_mm - _vy_bar_gas_mmusec
    RCL ion_vy_mm
    RCL _vy_bar_gas_mmusec
    -
    STO vy
    RLUP
    ; vz = ion_vz_mm - _vz_bar_gas_mmusec
    RCL ion_vz_mm
    RCL _vz_bar_gas_mmusec
    -
    STO vz
    RLUP
    ; 
    ; # Convert ion velocity vector to polar coordinates (mm/us).
    ; speed_ion = sqrt(vx*vx + vy*vy + vz*vz)
    RCL vx
    RCL vx
    *
    RCL vy
    RCL vy
    *
    +
    RCL vz
    RCL vz
    *
    +
    SQRT
    STO speed_ion
    RLUP
    ; if speed_ion < 1E-7
    1E-7
    RCL speed_ion
    X>=Y
    GTO label35__
    RLUP
    RLUP
        ; speed_ion = 1E-7  # prevent divide by zero and such effects later on
        1E-7 STO speed_ion
        RLUP
    ; begin else
    GTO label36__
    LBL label35__
    RLUP
    RLUP
    LBL label36__
    ; end if
    ; 
    ; 
    ; #=== Notes on Mean-Free-Path ===
    ; # The mean-free-path (lambda) is generally a function of the mean
    ; # relative speed (c_bar_rel) between the ion and moving background
    ; # gas:
    ; #   lambda = (c_ion/c_bar_rel) / (n * sigma)
    ; # where
    ; #   c_ion is ion speed
    ; #   c_bar_rel is the mean relative speed between ion and moving
    ; #     background gas
    ; #   n is the number of gas particles per unit volume
    ; #   sigma is the collision cross section (roughly, the area with
    ; #      a diameter equal to the sum of the diameters of the
    ; #      colliding ion and gas particles)
    ; #
    ; # Mean relative speed (c_bar_rel) is formally determined by
    ; #   c_bar_rel = tripple_integral |v_ion - v_gas| * f(v_gas) dv_gas
    ; # where
    ; #   f(v) is the product of the one-dimensional Maxwell
    ; #   in all three dimensions:
    ; #     f(v) = (m_gas / (2*pi*k*T))^(3/2) * exp(-m*v^2 / (2*k*T))
    ; # which evaluates to
    ; #   c_bar_rel = c_bar_gas * (s + 1/(2*s)) * 0.5 * sqrt(PI) * erf(s) +
    ; #                            (1/2)*exp(-s^2))      (s > 0)
    ; # where
    ; #   s = c_ion/c_star_gas
    ; #   c_bar_gas  = sqrt(8*k*T_b/pi/m_b) is the mean gas speed
    ; #   c_star_gas = sqrt(2*k*T_b/m_b)    is the median gas speed
    ; #
    ; # This approach is recommended by Ding2002.
    ; #
    ; # Ling1997 uses a simpler (and almost as suitable)
    ; # approximation for c_bar_rel:
    ; #   c_bar_rel ~= sqrt(c_ion^2 + c_bar_gas^2)
    ; #===
    ; 
    ; # Compute effective mean-free-path (or use a specific value).
    ; if _mean_free_path_mm < 0   #...using current ion velocity
    0
    RCL _mean_free_path_mm
    X>=Y
    GTO label45__
    RLUP
    RLUP
        ; # Note: only recompute mean-free-path if speed_ion has
        ; # changed significantly. This is intended to speed up the
        ; # calculation a bit.  Handles flying ions by groups too.
        ; if last_ion_number != ion_number or
        RCL ion_number
        RCL last_ion_number
        X!=Y
        GTO label39__
        RLUP
        RLUP
        0
        GTO label40__
        LBL label39__
        RLUP
        RLUP
        1
        LBL label40__
        0.05
        RCL speed_ion
        RCL last_speed_ion
        /
        1
        -
        ABS
        X>Y
        GTO label41__
        RLUP
        RLUP
        0
        GTO label42__
        LBL label41__
        RLUP
        RLUP
        1
        LBL label42__
        +
        X=0
        GTO label43__
        RLUP
            ; # Compute mean gas speed (mm/us)
            ; c_bar_gas = sqrt(8*k*_temperature_k/PI/(_gas_mass_amu * kg_amu)) / 1000
            8
            RCL k
            *
            RCL _temperature_k
            *
            RCL pi
            /
            RCL _gas_mass_amu
            RCL kg_amu
            *
            /
            SQRT
            1000
            /
            STO c_bar_gas
            RLUP
            ; 
            ; # Compute median gas speed (mm/us)z
            ; c_star_gas = sqrt(2*k*_temperature_k/(_gas_mass_amu * kg_amu)) / 1000
            2
            RCL k
            *
            RCL _temperature_k
            *
            RCL _gas_mass_amu
            RCL kg_amu
            *
            /
            SQRT
            1000
            /
            STO c_star_gas
            RLUP
            ; 
            ; # Compute mean relative speed (mm/us)
            ; s = speed_ion / c_star_gas
            RCL speed_ion
            RCL c_star_gas
            /
            STO s
            RLUP
            ; c_bar_rel = c_bar_gas * (
            RCL c_bar_gas
            RCL s
            1
            2
            RCL s
            *
            /
            +
            0.5
            *
            RCL pi
            SQRT
            *
            RCL s
            GSB erf
            *
            0.5
            RCL s
            CHS
            RCL s
            *
            E^X
            *
            +
            *
            STO c_bar_rel
            RLUP
            ; 
            ; # Compute mean-free-path (mm)
            ; effective_mean_free_path_mm = 1000 * k * _temperature_k *
            1000
            RCL k
            *
            RCL _temperature_k
            *
            RCL speed_ion
            RCL c_bar_rel
            /
            *
            RCL _pressure_pa
            RCL _sigma_m2
            *
            /
            STO effective_mean_free_path_mm
            RLUP
            ; 
            ; last_speed_ion = speed_ion
            RCL speed_ion
            STO last_speed_ion
            RLUP
            ; last_ion_number = ion_number
            RCL ion_number
            STO last_ion_number
            RLUP
        ; begin else
        GTO label44__
        LBL label43__
        RLUP
        LBL label44__
        ; end if
        ; 
    ; begin else
    GTO label46__
    LBL label45__
    RLUP
    RLUP
        ; effective_mean_free_path_mm = _mean_free_path_mm
        RCL _mean_free_path_mm
        STO effective_mean_free_path_mm
        RLUP
    LBL label46__
    ; end if
    ; 
    ; #print("DEBUG:ion[c=#],gas[c_bar=#],c_bar_rel=#, MFP=#",
    ; #      speed_ion, c_bar_gas, c_bar_rel, effective_mean_free_path_mm)
    ; 
    ; # Compute collision probability per distance traveled
    ; collision_prob = 1 -
    1
    RCL speed_ion
    CHS
    RCL ion_time_step
    *
    RCL effective_mean_free_path_mm
    /
    E^X
    -
    STO collision_prob
    RLUP
    ; 
    ; # Was there a collision?
    ; if rand() > collision_prob
    RCL collision_prob
    RAND
    X<=Y
    GTO label49__
    RLUP
    RLUP
        ; exit
        EXIT
    ; begin else
    GTO label50__
    LBL label49__
    RLUP
    RLUP
    LBL label50__
    ; end if
    ; 
    ; 
    ; #--- collisions
    ; 
    ; # Compute standard deviation of gas velocity in one dimension (mm/us).
    ; # The following is derived from kinetic gas theory.
    ; vr_stdev_gas =
    RCL k
    RCL _temperature_k
    *
    RCL _gas_mass_amu
    RCL kg_amu
    *
    /
    SQRT
    1000
    /
    STO vr_stdev_gas
    RLUP
    ; 
    ; # Compute a normalized Gaussian random variable (-inf, +inf).
    ; # This uses the Box-Muller algorithm.
    ; # rand1-3 are Gaussian random variables.
    ; s = 1
    1 STO s
    RLUP
    ; while s >= 1
    LBL label53__
    1
    RCL s
    X<Y
    GTO label54__
    RLUP
    RLUP
        ; v1 = 2*rand() - 1
        2
        RAND
        *
        1
        -
        STO v1
        RLUP
        ; v2 = 2*rand() - 1
        2
        RAND
        *
        1
        -
        STO v2
        RLUP
        ; s = v1*v1 + v2*v2
        RCL v1
        RCL v1
        *
        RCL v2
        RCL v2
        *
        +
        STO s
        RLUP
    GTO label53__
    LBL label54__
    RLUP
    RLUP
    ; end while loop
    ; 
    ; # (assume divide by zero improbable?)
    ; rand1 = v1*sqrt(-2*ln(s) / s)
    RCL v1
    2
    CHS
    RCL s
    LN
    *
    RCL s
    /
    SQRT
    *
    STO rand1
    RLUP
    ; rand2 = v2*sqrt(-2*ln(s) / s)
    RCL v2
    2
    CHS
    RCL s
    LN
    *
    RCL s
    /
    SQRT
    *
    STO rand2
    RLUP
    ; s = 1
    1 STO s
    RLUP
    ; while s >= 1
    LBL label57__
    1
    RCL s
    X<Y
    GTO label58__
    RLUP
    RLUP
        ; v1 = 2*rand() - 1
        2
        RAND
        *
        1
        -
        STO v1
        RLUP
        ; v2 = 2*rand() - 1
        2
        RAND
        *
        1
        -
        STO v2
        RLUP
        ; s = v1*v1 + v2*v2
        RCL v1
        RCL v1
        *
        RCL v2
        RCL v2
        *
        +
        STO s
        RLUP
    GTO label57__
    LBL label58__
    RLUP
    RLUP
    ; end while loop
    ; 
    ; rand3 = v1*sqrt(-2*ln(s) / s)
    RCL v1
    2
    CHS
    RCL s
    LN
    *
    RCL s
    /
    SQRT
    *
    STO rand3
    RLUP
    ; 
    ; vx_gas = rand1 * vr_stdev_gas
    RCL rand1
    RCL vr_stdev_gas
    *
    STO vx_gas
    RLUP
    ; vy_gas = rand2 * vr_stdev_gas
    RCL rand2
    RCL vr_stdev_gas
    *
    STO vy_gas
    RLUP
    ; vz_gas = rand3 * vr_stdev_gas
    RCL rand3
    RCL vr_stdev_gas
    *
    STO vz_gas
    RLUP
    ; 
    ; # Or a slightly more correct thing might be to make probability
    ; # of (vx_gas,vy_gas,vz_gas) proportional to
    ; # |v_gas - v_ion| as well (see Lua version)
    ; 
    ; # Translate velocity reference frame so that colliding
    ; # background gas particle is stationary.
    ; # > This simplifies the subsequent analysis.
    ; vx = vx - vx_gas
    RCL vx
    RCL vx_gas
    -
    STO vx
    RLUP
    ; vy = vy - vy_gas
    RCL vy
    RCL vy_gas
    -
    STO vy
    RLUP
    ; vz = vz - vz_gas
    RCL vz
    RCL vz_gas
    -
    STO vz
    RLUP
    ; 
    ; # > Notes on collision orientation
    ; #   A collision of the ion in 3D can now be reasoned in 2D since
    ; #   the ion remains in some 2D plane before and after collision.
    ; #   The ion collides with an gas particle initially at rest (in the
    ; #   current velocity reference frame).
    ; #   For convenience, we define a coordinate system (r, t) on the
    ; #   collision plane.  r is the radial axis through the centers of
    ; #   the colliding particles, with the positive direction indicating
    ; #   approaching particles.  t is the tangential axis perpendicular to r.
    ; #   An additional coordinate theta defines the the rotation of the
    ; #   collision plane around the ion velocity axis.
    ; 
    ; # Compute randomized impact offset [0, 1) as a fraction
    ; # of collisional cross-section diameter.
    ; # The probability of a given impact_offset is made
    ; # proportional to impact_offset^2.
    ; # Note: 0 is a head-on collision; 1 would be a near miss.
    ; impact_offset = sqrt(0.999999999 * rand())
    0.999999999
    RAND
    *
    SQRT
    STO impact_offset
    RLUP
    ; 
    ; # Compute randomized impact angle [0, +PI/2) (radians)
    ; # between ion velocity vector and radial axis.
    ; # Note: 0 is a head-on collision; +PI/2 would be a near miss.
    ; impact_angle = asin(impact_offset)
    RCL impact_offset
    ASIN
    STO impact_angle
    RLUP
    ; 
    ; # Compute randomized angle [0, 2*PI] for rotation of collision
    ; # plane around radial axis.
    ; # Note: all angles are equally likely.
    ; impact_theta = 2*PI*rand()
    2
    RCL pi
    *
    RAND
    *
    STO impact_theta
    RLUP
    ; 
    ; # Compute polar coordinates in current velocity reference frame.
    ; (speed_ion_r, az_ion_r, el_ion_r) = rect3d_to_polar3d(vx, vy, vz)
    RCL vz
    RCL vy
    RCL vx
    RECT3D_TO_POLAR3D
    STO speed_ion_r
    RLUP
    STO az_ion_r
    RLUP
    STO el_ion_r
    RLUP
    ; 
    ; # Compute ion velocity components (mm/us).
    ; # Note: this choice of coordinates ensures that the vector is
    ; # always in the first (+/+) quadrant.
    ; vr_ion = speed_ion_r * cos(impact_angle)    #.. radial velocity
    RCL speed_ion_r
    RCL impact_angle
    COS
    *
    STO vr_ion
    RLUP
    ; vt_ion = speed_ion_r * sin(impact_angle)    #.. normal velocity
    RCL speed_ion_r
    RCL impact_angle
    SIN
    *
    STO vt_ion
    RLUP
    ; 
    ; # Attenuate ion velocity due to elastic collision.
    ; # This is the standard equation for a one-dimensional
    ; # elastic collision, assuming the other particle is initially at rest
    ; # (in the current reference frame).
    ; # Note that the force acts only in the radial direction, which is
    ; # normal to the surfaces at the point of contact.
    ; vr_ion2 = (vr_ion * (ion_mass - _gas_mass_amu))
    RCL vr_ion
    RCL ion_mass
    RCL _gas_mass_amu
    -
    *
    RCL ion_mass
    RCL _gas_mass_amu
    +
    /
    STO vr_ion2
    RLUP
    ; 
    ; # Rotate velocity frame of reference so that original ion velocity
    ; # vector is on the +y axis.
    ; # Note: The angle of the new velocity vector with respect to the
    ; # +y axis then represents the deflection angle.
    ; (vx, vy, vz) = elevation_rotate(
    0
    RCL vt_ion
    RCL vr_ion2
    90
    RCL impact_angle
    >DEG
    -
    ELEVATION_ROTATE
    STO vx
    RLUP
    STO vy
    RLUP
    STO vz
    RLUP
    ; 
    ; # Rotate velocity frame of reference around +y axis.
    ; # This rotates the deflection angle and in effect chooses the
    ; # collision plane (impact_theta), which was left unchosen before.
    ; (vx, vy, vz) = azimuth_rotate(degrees(impact_theta), vx, vy, vz)
    RCL vz
    RCL vy
    RCL vx
    RCL impact_theta
    >DEG
    AZIMUTH_ROTATE
    STO vx
    RLUP
    STO vy
    RLUP
    STO vz
    RLUP
    ; 
    ; # Rotate velocity frame of reference back to the original.
    ; (vx, vy, vz) = elevation_rotate(-90 + el_ion_r, vx, vy, vz)
    RCL vz
    RCL vy
    RCL vx
    90
    CHS
    RCL el_ion_r
    +
    ELEVATION_ROTATE
    STO vx
    RLUP
    STO vy
    RLUP
    STO vz
    RLUP
    ; (vx, vy, vz) = azimuth_rotate(az_ion_r, vx, vy, vz)
    RCL vz
    RCL vy
    RCL vx
    RCL az_ion_r
    AZIMUTH_ROTATE
    STO vx
    RLUP
    STO vy
    RLUP
    STO vz
    RLUP
    ; 
    ; # Translate velocity frame of reference back to the original.
    ; # This undoes the prior two translations that make velocity
    ; # relative to the colliding gas particle.
    ; vx = vx + vx_gas + _vx_bar_gas_mmusec
    RCL vx
    RCL vx_gas
    +
    RCL _vx_bar_gas_mmusec
    +
    STO vx
    RLUP
    ; vy = vy + vy_gas + _vy_bar_gas_mmusec
    RCL vy
    RCL vy_gas
    +
    RCL _vy_bar_gas_mmusec
    +
    STO vy
    RLUP
    ; vz = vz + vz_gas + _vz_bar_gas_mmusec
    RCL vz
    RCL vz_gas
    +
    RCL _vz_bar_gas_mmusec
    +
    STO vz
    RLUP
    ; 
    ; # Set new velocity vector.
    ; (ion_vx_mm, ion_vy_mm, ion_vz_mm) = (vx, vy, vz)
    RCL vz
    RCL vy
    RCL vx
    STO ion_vx_mm
    RLUP
    STO ion_vy_mm
    RLUP
    STO ion_vz_mm
    RLUP
    ; 
    ; # Now lets compute some statistics
    ; 
    ; # Calculate new ion speed and KE.
    ; (speed_ion2, unused, unused) =
    RCL ion_vz_mm
    RCL ion_vy_mm
    RCL ion_vx_mm
    RECT3D_TO_POLAR3D
    STO speed_ion2
    RLUP
    STO unused
    RLUP
    STO unused
    RLUP
    ; ke2_ion = speed_to_ke(speed_ion2, ion_mass)
    RCL ion_mass
    RCL speed_ion2
    SPEED_TO_KINETIC_ENERGY
    STO ke2_ion
    RLUP
    ; 
    ; # Compute mean gas KE
    ; #ke_bar_gas = (
    ; #    (3/2) * k * _temperature_k +
    ; #    (1/2) * (_gas_mass_amu * kg_amu) * (
    ; #        _vx_bar_gas_mmusec*_vx_bar_gas_mmusec +
    ; #        _vy_bar_gas_mmusec*_vy_bar_gas_mmusec +
    ; #        _vz_bar_gas_mmusec*_vz_bar_gas_mmusec
    ; #    ) * 1e+6
    ; #) * eV_j
    ; #print("DEBUG:ion[ke=#],gas[ke=#]", ke2_ion, ke_bar_gas)
    ; 
    ; # Record KE after collisions.  This is later used to compute average KE.
    ; if ion_number <= 100
    100
    RCL ion_number
    X>Y
    GTO label61__
    RLUP
    RLUP
        ; ion_ke_totals[ion_number] = ion_ke_totals[ion_number] + ke2_ion
        RCL ion_number
        ARCL ion_ke_totals
        RCL ke2_ion
        +
        RCL ion_number
        ASTO ion_ke_totals
        RLUP
        ; ion_collision_totals[ion_number] = ion_collision_totals[ion_number] + 1
        RCL ion_number
        ARCL ion_collision_totals
        1
        +
        RCL ion_number
        ASTO ion_collision_totals
        RLUP
    ; begin else
    GTO label62__
    LBL label61__
    RLUP
    RLUP
    LBL label62__
    ; end if
    ; 
    ; 
    ; if _mark_collisions != 0
    0
    RCL _mark_collisions
    X=Y
    GTO label65__
    RLUP
    RLUP
        ; mark()
        MARK
    ; begin else
    GTO label66__
    LBL label65__
    RLUP
    RLUP
    LBL label66__
    ; end if
    ; 
    ; unused = unused
    RCL unused
    STO unused
    RLUP
    EXIT
; end segment
; sub erf(z) returns(res)
LBL erf
    RCL call_stack_idx__
    1
    +
    RCL z
    X><Y
    ASTO call_stack__
    RLUP
    RCL call_stack_idx__
    2
    +
    RCL res
    X><Y
    ASTO call_stack__
    RLUP
    STO z
    RLUP
    RCL call_stack_idx__
    3
    +
    ASTO call_stack__
    RLUP
    RCL call_stack_idx__
    4
    +
    ASTO call_stack__
    RLUP
    RCL call_stack_idx__
    5
    +
    ASTO call_stack__
    RLUP
    RCL call_stack_idx__
    6
    +
    ASTO call_stack__
    RLUP
    RCL call_stack_idx__
    7
    +
    ASTO call_stack__
    RLUP
    RCL call_stack_idx__
    8
    +
    ASTO call_stack__
    RLUP
    RCL call_stack_idx__
    9
    +
    ASTO call_stack__
    RLUP
    RCL call_stack_idx__
    9
    +
    STO call_stack_idx__
    RLUP
    ; z2 = abs(z)
    RCL z
    ABS
    STO z2
    RLUP
    ; t = 1 / (1 + 0.32759109962 * z2)
    1
    1
    0.32759109962
    RCL z2
    *
    +
    /
    STO t
    RLUP
    ; res = (    - 1.061405429 ) * t
    1.061405429
    CHS
    RCL t
    *
    STO res
    RLUP
    ; res = (res + 1.453152027 ) * t
    RCL res
    1.453152027
    +
    RCL t
    *
    STO res
    RLUP
    ; res = (res - 1.421413741 ) * t
    RCL res
    1.421413741
    -
    RCL t
    *
    STO res
    RLUP
    ; res = (res + 0.2844966736) * t
    RCL res
    0.2844966736
    +
    RCL t
    *
    STO res
    RLUP
    ; res =((res - 0.254829592 ) * t) * exp(-z2*z2)
    RCL res
    0.254829592
    -
    RCL t
    *
    RCL z2
    CHS
    RCL z2
    *
    E^X
    *
    STO res
    RLUP
    ; res = res + 1
    RCL res
    1
    +
    STO res
    RLUP
    ; if z < 0
    0
    RCL z
    X>=Y
    GTO label19__
    RLUP
    RLUP
        ; res = -res
        RCL res
        CHS
        STO res
        RLUP
    ; begin else
    GTO label20__
    LBL label19__
    RLUP
    RLUP
    LBL label20__
    ; end if
    ; 
    RCL call_stack_idx__
    ARCL call_stack__
    RCL call_stack_idx__
    1
    -
    ARCL call_stack__
    RCL call_stack_idx__
    2
    -
    ARCL call_stack__
    RCL call_stack_idx__
    3
    -
    ARCL call_stack__
    RCL call_stack_idx__
    4
    -
    ARCL call_stack__
    RCL call_stack_idx__
    5
    -
    ARCL call_stack__
    RCL call_stack_idx__
    6
    -
    ARCL call_stack__
    RCL res
    RCL call_stack_idx__
    7
    -
    ARCL call_stack__
    STO res
    RLUP
    RCL call_stack_idx__
    8
    -
    ARCL call_stack__
    STO z
    RLUP
    RCL call_stack_idx__
    9
    -
    STO call_stack_idx__
    RLUP
    RTN
; end subroutine
; sub terminate
SEG terminate
    ; # Display some statistics.
    ; # Note: At equilibrium, the ion and gas KE become roughly equal.
    ; if ion_number <= 100
    100
    RCL ion_number
    X>Y
    GTO label69__
    RLUP
    RLUP
        ; k = 1.3806505e-23       # Boltzmann constant (J/K)
        1.3806505e-23 STO k
        RLUP
        ; eV_J = 6.2415095e+18    # (eV/J) conversion factor
        6.2415095e+18 STO ev_j
        RLUP
        ; 
        ; ke_bar = ion_ke_totals[ion_number] /
        RCL ion_number
        ARCL ion_ke_totals
        RCL ion_number
        ARCL ion_collision_totals
        1E-10
        +
        /
        STO ke_bar
        RLUP
        ; T_bar = ke_bar / eV_J / (1.5 * k)
        RCL ke_bar
        RCL ev_j
        /
        1.5
        RCL k
        *
        /
        STO t_bar
        RLUP
        ; print("ion=#, collisions=#, mean KE=# eV, mean T=# K",
        RCL t_bar
        RCL ke_bar
        RCL ion_number
        ARCL ion_collision_totals
        RCL ion_number
        MESS ;ion=#, collisions=#, mean KE=# eV, mean T=# K
        RLUP
        RLUP
        RLUP
        RLUP
    ; begin else
    GTO label70__
    LBL label69__
    RLUP
    RLUP
    LBL label70__
    ; end if
    ; 
    EXIT
; end segment

