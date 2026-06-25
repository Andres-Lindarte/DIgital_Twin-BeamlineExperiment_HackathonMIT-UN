#=======================================================================
# buncher.sl - Buncher lens control
#
# This program controls the voltage on a Buncher lens and also keeps
# the display up-to-date.
#
# Note: output messages are generated in target.sl.
#
# Upon compilation, this SL program can be used as an exact replacement
# for the BUNCHER.PRG program in the _Buncher example of SIMION 7.0.
#
# HISTORY:
# 2003-11 - ported to SL (D.J.Manura, Scientific Instrument Services, Inc.)
#           Based on the BUNCHER.PRG example in SIMION 7.0.
# $Revision$ $Date$
#=======================================================================

#===== variables

adjustable switch_time = 1.7      # switch time (microseconds)
adjustable buncher_voltage = 900  # buncher deceleration voltage
static update_flag = 1            # flag for updating PE surface display

#===== subroutines

# Adjust time step.
sub tstep_adjust
    # Let's make sure the time step ends right on the switch time
    # when that time occurs.
    if ion_time_of_flight < switch_time
        ion_time_step = min(ion_time_step,
                            switch_time - ion_time_of_flight)
    endif
endsub

# Control buncher voltage: switch off voltage at switch time.
sub fast_adjust
    adj_elect01 = if(ion_time_of_flight < switch_time,
                     buncher_voltage, 0)
endsub

# Handle display updates.
sub other_actions
    if switch_time == ion_time_of_flight  # (transition point)
        ion_color = 3         # Set ion color to blue.
        mark()                # Mark ion location.
        update_flag = 1       # Trigger PE surface update at next time step.
    elseif update_flag == 1   # (time step immediately after transition point)
        update_flag = 0
        update_pe_surface = 1 # Mark PE display for update.
    endif
endsub
