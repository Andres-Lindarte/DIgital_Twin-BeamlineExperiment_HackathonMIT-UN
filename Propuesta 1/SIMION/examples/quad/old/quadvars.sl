#=======================================================================
# quadvars.sl - Quadrupole variables.
#
# Global variables used by the quadrupole programs (quadin.sl, quad.sl,
#   and quadout.sl).
#
# HISTORY:
# 2003-11 - ported to SL (D.J.Manura, Scientific Instrument Services, Inc.)
#           Based on variables in QUAD*.PRG examples in SIMION 7.0
#           (David A. Dahl)
# $Revision$ $Date$
#=======================================================================

#----- adjustable during flight
 
adjustable _percent_tune =          97.0    # percent of optimum tune
adjustable _amu_mass_per_charge =  100.0    # mass tune point (in amu/charge)
adjustable _quad_entrance_voltage =  0.0    # quad entrance voltage
adjustable _quad_axis_voltage =     -8.0    # quad axis voltage
adjustable _quad_exit_voltage =   -100.0    # quad exit voltage
adjustable _detector_voltage =   -1500.0    # detector voltage
 
#----- adjustable at beginning of flight
 
adjustable pe_update_each_usec =      0.05  # PE display update time step (in usec)
adjustable phase_angle_deg     =      0.0   # entry phase angle of ion
adjustable frequency_hz        =      1.1E6 # RF frequency of quad in (hz)
adjustable effective_radius_in_cm =   0.40  # effective quad radius (in cm)

adjustable percent_energy_variation =10.0   # randomized ion energy variation (+- %)
adjustable cone_angle_off_vel_axis =  5.0   # randomized ion trajectory cone angle (+- degrees)
adjustable random_offset_mm =         0.1   # randomized initial ion offset position (in mm)
                                            #   with mid-point at zero offset.
adjustable random_tob =          0.909091   # max randomized time of birth over
                                            #   one cycle (in usec)
 
#----- static variables

static scaled_rf =                  0.0    # scaled RF base
static omega =                      1.0    # frequency (in radians/usec)
static theta =                      0.0    # phase offset (in radians)
