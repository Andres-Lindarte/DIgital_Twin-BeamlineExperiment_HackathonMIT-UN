#=======================================================================
# factor.sl
#
# HISTORY:
# 2003-11 - ported to SL (D.J.Manura, Scientific Instrument Services, Inc.)
# 1994 - SIMION 6.0 equivalent of a SIMION 4.0 .FAC user program (D.A. DAHL)
#
# factor.pa has two parallel plate electrodes
# one set to 100 volts and the other set to -100 volts
# this efield_adjust program modulates the field
#=======================================================================
 
#----- adjustable variables

adjustable omega = 1.0  # angular velocity in radians/micro second

#----- subroutines
 
sub efield_adjust
    factor = sin(ion_time_of_flight * omega)
 
    ion_volts = ion_volts * factor
 
    ion_dvoltsx_gu = Ion_dvoltsx_gu * factor
    ion_dvoltsy_gu = Ion_dvoltsy_gu * factor
    ion_dvoltsz_gu = Ion_dvoltsz_gu * factor
endsub
