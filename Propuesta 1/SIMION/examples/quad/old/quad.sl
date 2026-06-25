#=======================================================================
# quad.sl - Quadrupole poles.
#
# Controls the voltage oscillations on the quadrupole poles
# and updates potential energy surface display.
#
# HISTORY:
# 2003-11 - ported to SL (D.J.Manura, Scientific Instrument Services, Inc.)
#           Based on QUAD.PRG example in SIMION 7.0 (David A. Dahl)
# $Revision$ $Date$
#=======================================================================

import "quadvars.sl"

#===== variables

static next_pe_update = 0.0    # next PE surface update time.

#===== subroutines 

# Generate trap rf.
sub fast_adjust
    # Set electrode potentials.

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
    if ion_time_of_flight >= next_pe_update
        next_pe_update = ion_time_of_flight + pe_update_each_usec
        update_pe_surface = 1
    endif
endsub
