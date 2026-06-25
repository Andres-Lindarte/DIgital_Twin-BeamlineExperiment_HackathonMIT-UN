#=======================================================================
# elect.sl
#
# HISTORY:
# 2003-11 - ported to SL (D.J.Manura, Scientific Instrument Services, Inc.)
# 1994 - SIMION 6.0 equivalent of a SIMION 4.0 .ELE user program (D.A. DAHL)
# 
# elect.pa0 has two parallel plate electrodes
# this fast_adjust seg creates a simple rf field between the plates
# using dynamic fast adjust
#=======================================================================

#----- adjustable variables

adjustable omega = 1.0               # anuglar velocity in radians/micro second
adjustable rf_voltage = 100.0        # rf voltage
adjustable update_pe_every_usec = 0.3  # update pe surface every 0.3 usec
 
adjustable next_pe_update = 0        # next pe update time of flight
 

# start of fast_adjust program segment
sub fast_adjust
    adj_elect01 = sin(ion_time_of_flight * omega) * rf_voltage
    adj_elect02 = -adj_elect01
endsub

# used to control pe surface updates        
sub other_actions
    if ion_time_of_flight >= next_pe_update
        next_pe_update = ion_time_of_flight + update_pe_every_usec
        update_pe_surface = 1              # flag a pe surface update
    endif
endsub
