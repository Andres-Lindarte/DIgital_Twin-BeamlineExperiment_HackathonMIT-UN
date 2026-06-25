#=======================================================================
# icr.sl
#
# ICR simulation program
#
# HISTORY:
# 2003-11 - ported to SL (D.J.Manura, Scientific Instrument Services, Inc.)
# 1995 - MAG.PRG example in SIMION <= 7.0 (D.A.Dahl and A.D.Appelhans)
#=======================================================================
                 
 
#----- user adjustable variables
 
adjustable start_rht_voltage = 5     # starting right end voltage
adjustable capture_voltage   = 3     # endcap capture voltage
adjustable rf_voltage        = 20    # peak voltage on rf plates for excite phase
adjustable bx_gauss          = 30000 # magnetic field in gauss
adjustable starting_mass_amu = 950   # loser mass for rf sweep
adjustable ending_mass_amu   = 1050  # upper mass for rf sweep
adjustable rf_sweep_time_usec= 100   # rf sweep time in usec
adjustable start_delay_usec  = 80    # time delay before starting rf sweep
                               
adjustable pe_update_each_usec = 1.0 # pe surface update time step in usec

#----- static variables
  
static first =                    0   # first call flag
static starting_rf =              1   # start mass frequancy for sweep
static ending_rf =                1   # end mass frequency for sweep
static rf_Slope =                 1   # rf sweep slope (rate of frequency change)
static t_delay_usec =             0   # time delay before starting rf sweep
static t_excite_usec =            0   # time at end of excite phase
static tmark =                 1000   # time for next transition
static color =                    1   # ion color after transition
 
static next_pe_update =           0   # next time for PE update
  

#----- subroutines
         
 
# time control for transitions.
# time step adjust program segment used to precisely approach both
# sweep start and stop transitions
sub tstep_adjust
    if ion_time_of_flight < t_delay_usec
        tmark = t_delay_usec
        color = 1                       # assume next color is red
        ion_time_step = min(ion_time_step, tmark - ion_time_of_flight)
    else
        color = 2                   # assume next color is green
        tmark = t_excite_usec
        #test for sweep stop transition
        if ion_time_of_flight < tmark
            ion_time_step = min(ion_time_step, tmark - ion_time_of_flight)
        endif
    endif
endsub         

         
# control icr cell voltages.
# fast voltage adjust segment
sub fast_adjust
    # initialize parameters for excitation sweep control
    if first == 0
        first = 1                   #turn off first pass flag
          
        # convert magnetic field to tesla
        temp1 = bx_gauss / 10000
 
        # compute frequency for rf ramp start mass
        starting_rf = temp1 / starting_mass_amu * 1.6022E-19 / 1.6605E-27 / 1E6
 
        # compute frequency for rf ramp end mass
        ending_rf   = temp1 / ending_mass_amu * 1.6022E-19 / 1.6605E-27 / 1E6
 
        # calculate slope of frequency ramp
        rf_slope = (ending_rf - starting_rf) / rf_sweep_time_usec
 
        # compute and store times for start and stop of excite ramp
        t_delay_usec = start_delay_usec                     # time for ramp start
        t_excite_usec = t_delay_usec + rf_sweep_time_usec   # time for end of RF ramp
    endif # first 
 
  
    # initial
    if ion_time_of_flight <= t_delay_usec
        # set elect 1-4 to half of right voltage
        adj_elect01 = start_rht_voltage / 2
        adj_elect02 = adj_elect01
        adj_elect03 = adj_elect01
        adj_elect04 = adj_elect01
        adj_elect05 = 0                    # left entrance
        adj_elect06 = start_rht_voltage    # right entrance
    # end of rf sweep time
    elseif ion_time_of_flight > t_excite_usec
        # set electrode voltages
        adj_elect01 = 0
        adj_elect02 = 0
        adj_elect03 = 0
        adj_elect04 = 0
        adj_elect05 = capture_voltage
        adj_elect06 = capture_voltage
    else
        # calculate omega for rf voltage calculation
        omega = (ion_time_of_flight - t_delay_usec)
                * rf_slope + starting_rf
 
        # calculate rf voltage for exciter plates
        adj_elect01 = sin(omega * (ion_time_of_flight - t_delay_usec))
                      * rf_voltage
        adj_elect02 = -adj_elect01
        adj_elect03 = 0
        adj_elect04 = 0
        adj_elect05 = capture_voltage
        adj_elect06 = capture_voltage
    endif
endsub
   
 
# transition color control
sub other_actions
    if ion_time_of_flight >= next_pe_update
        next_pe_update = ion_time_of_flight + pe_update_each_usec
        update_pe_surface = 1      # request a pe surface update
    endif
    if ion_time_of_flight == tmark
       ion_color = color           # set ion's after transition color
    endif
endsub
