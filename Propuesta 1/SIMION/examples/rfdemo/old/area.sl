#=======================================================================
# elect.sl
#
# HISTORY:
# 2003-11 - ported to SL (D.J.Manura, Scientific Instrument Services, Inc.)
# 1994 - SIMION 6.0 equivalent of a SIMION 4.0 .AR? user program (D.A. DAHL)
# 
# area.pa has two parallel plate electrodes
# one set to 100 volts and the other set to -100 volts
# voltages in the potential array are totally ignored!!!
# this efield_adjust seg defines an explicit rf field between the plates
#======================================================================= 
 
adjustable omega = 1.0         # anuglar velocity in radians/micro second
adjustable rf_voltage = 100.0  # rf voltage
 
# start of efield_adjust program segment
sub efield_adjust
 
    # first we calculate the potential of the left electrode
    v_left = sin(ion_time_of_flight * omega) * rf_voltage
 
    # next we calculate the electrostatic field (-) in the x direction
    dV_dx = V_left / -21.5
    ion_dvoltsx_gu = dV_dx
    ion_dvoltsy_gu = 0
    ion_dvoltsz_gu = 0
 
    # then we calculate the potential at the current ion location
    ion_volts = 22.5 - ion_px_gu * dV_dx + V_left
endsub
