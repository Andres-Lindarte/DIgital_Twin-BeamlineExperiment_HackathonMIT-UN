#=======================================================================
# tune.sl - lens tuning example.
#
# This focuses on ion #6.
#
# The electrode tuning resembles a binary search.  It searches for an
# electrode voltage that causes ions to hit within a certain radius.
# The search terminates when the goal is reached or the maximum permitted
# number of tries is exceeded.
#
# HISTORY:
# 2003-11 - ported to SL (D.J.Manura, Scientific Instrument Services, Inc.)
#           based on TUNE.PRG example in SIMION 7.0.
# $Revision: 587 $ $Date: 2004-07-17 16:54:47 -0400 (Sat, 17 Jul 2004) $
#=======================================================================

#===== variables

adjustable _abs_goal_for_y = 0.001   # goal for abs(y) bounds
 
adjustable max_voltage = 1000        # tuning voltage upper bound
adjustable min_voltage = 0           # tuning voltage lower bound
 
adjustable max_tries = 20            # rerun limit
adjustable run_number = 0            # rerun counter
 
adjustable test_voltage = 900        # electrode voltage (current run)
adjustable upper_volts = 0           # last upper bound voltage
adjustable lower_volts = 0           # last lower bound voltage
adjustable upper_y = 0               # last upper y hit
adjustable lower_y = 0               # last lower y hit

adjustable request_rerun = 1         # flag: request a rerun
 
static update_pe = 1                 # mark PE display update at start of each run.
 
#===== subroutines

 
# Set initial voltages and control reflying.
sub initialize
    if run_number == 0
        test_voltage = min_voltage      # setup voltage for first run
    endif

    # If the last run cleared the rerun flag, we'll disable further reruns.
    # (The current run will still execute.)
    rerun_flym = request_rerun
endsub
 
# Update electrode voltage.
sub fast_adjust
    adj_elect02 = test_voltage
endsub
 
# Update PE surface display.
sub other_actions
    if update_pe != 0                   # if update flagged
        update_pe = 0
        update_pe_surface = 1           # update the PE surface display
    endif
endsub
 
# Tune at end of each fly.
sub terminate                  
    if ion_number != 6                  # tune only on ion #6
        exit
    endif

    run_number = run_number + 1 

    if run_number == 1

        # save first run results
        upper_volts = test_voltage
        upper_y = ion_py_gu

        # setup voltage for second run
        test_voltage = max_voltage

    elseif run_number == 2

        # save second run results
        lower_volts = test_voltage
        lower_y = ion_py_gu

        if upper_y <= lower_y   # swap
            (upper_volts, lower_volts) = (lower_volts, upper_volts)
        endif
 
        # setup voltage for third run (mid-point)
        test_voltage = (min_voltage + max_voltage) / 2

    elseif run_number < max_tries

        if ion_py_gu < 0    # reverse tuning
            lower_volts = test_voltage
        else                # direct tuning
            upper_volts = test_voltage
        endif

        if request_rerun == 1
            # display results
            print("n = #,  y = #,  volts = #",
                  run_number, ion_py_gu, test_voltage)
 
            # goal reached?
            if _abs_goal_for_y < abs(ion_py_gu)
                # try again
                test_voltage = (lower_volts + upper_volts) / 2
            else
                print("Attained Tuning Goal of #", _abs_goal_for_y)
                print("Final Rerun to Save Trajectories")
                request_rerun = 0       #  flag termination
            endif
        endif

    else   # run_number >= max_tries

        if request_rerun == 1
            print("Aborted:  Hit Loop Limit")
        endif
        request_rerun = 0       #  flag termination (if not already)

    endif
endsub


 
 
