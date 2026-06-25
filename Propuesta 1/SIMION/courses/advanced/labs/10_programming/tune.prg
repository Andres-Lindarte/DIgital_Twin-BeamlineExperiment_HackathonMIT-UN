;------------------ demo of simple lens tuning program ------------
; -------- designed to focus ion 6 on y-axis of lens at splat -------
 
defa _ABS_Goal_For_y  0.001             ; tuning goal for abs y
 
defa Max_Voltage 1000                   ; max voltage allowed for tuning
defa Min_Voltage 0                      ; min voltage allowed for tuning
 
defa max_trys 20                        ; rerun limit
defa current_try 0                      ; rerun counter
 
defa test_voltage 900                   ; current run's electrode test voltage
defa upper_volts 0                      ; volts of last upper bounds
defa lower_volts 0                      ; volts of last lower bounds
defa upper_y 0                          ; y values of initial upper and lower
defa lower_y 0                          ; bounds
 
defa terminate_after_run 0              ; terminates after run if set
 
defs update_pe 1                        ; set update pe flag for each run
 
 
 
 ; -------------------- sets voltage for first run only --------------
seg initialize                          ; only used for first try
        rcl terminate_after_run
        x=0 goto next_init_test
        0 sto rerun_flym                ; terminate at end of run
 
    lbl next_init_test
        rcl current_try x!=0 exit       ; if not first try exit
        rcl min_voltage                 ; else use _min_voltage for first try
        sto test_voltage
        1 sto rerun_flym                ; assume looping for a rerun
 
 
 
 ; --------------------- sets electrode 2's voltage -----------------
seg fast_adjust                         ; sets electode's voltage
        rcl test_voltage                ; set electrode 2 to test_voltage
        sto adj_elect02
 
 ; --------------------- used to update pe surface display ------------
seg other_actions
        rcl update_pe                   ; get pe update flag
        x=0 exit                        ; exit if already updated
        0 sto update_pe                 ; reset pe update flag
        1 sto Update_PE_Surface         ; update the pe surface
 
 
 
 ; --------------------- tuning control module ------------------
seg terminate                           ; tuning control segment
        rcl ion_number 6 x!=y exit      ; exit if not ion number 6
 
        rcl current_try 1 +             ; add one to try number
        sto current_try
        rcl max_trys x>y goto check_run ; check_run if not greater than max trys
        rcl terminate_after_run         ; if not already aborted
        x=0                             ; display abort message
        mess                            ; Aborted:  Hit Loop Limit
        1 sto terminate_after_run       ; else flag termination
        exit                            ; exit and terminate
 
 
    lbl check_run                       ; begin check of results
        rcl current_try                 ; recall try number
        2 x<y goto next_guess           ; next_guess if not run 1 or 2
        x!=y goto first_point           ; if not run 2 save first point
 
        ; ---------- storing data from second run
        rcl test_voltage                ; recall test_voltage
        sto lower_volts                 ; save as lower_volts
        rcl ion_py_gu                   ; recall ion y stop point
        sto lower_y                     ; store as lower_y
 
        rcl upper_y x>y goto check_run2 ; jump if y max and y min not reversed
        rcl lower_volts                 ; reverse voltages
        rcl upper_volts                 ; so will tune properly
        sto lower_volts rlup
        sto upper_volts
 
        ; ----------- setting voltage for third run --------------
    lbl check_run2                      ; sets
        rcl min_voltage
        rcl max_voltage
        + 2 /
        sto test_voltage                ; use avg of max and min for run 3
        exit
 
        ; ---------- storing data from first run
    lbl first_point
        rcl test_voltage                ; recall test_voltage
        sto upper_volts                 ; save as upper_volts
        rcl ion_py_gu                   ; recall ion y stop point
        sto upper_y                     ; store as upper_y
        rcl max_voltage
        sto test_voltage                ; use max for run 2
        exit
 
        ; ------------ service for runs 3 and above
    lbl next_guess
        rcl ion_py_gu                   ; recall y splat
        x<0 goto reverse                ; if < 0 use reverse tuning
        ; -------------- direct tuning ----------
        rcl test_voltage                ; use current voltage as new
        sto upper_volts                 ; upper bounds
        goto compute_next_try
        ; -------------- reverse tuning ----------
    lbl reverse
        rcl test_voltage                ; use current voltage as new
        sto lower_volts                 ; lower bounds
 
        ; ---------- display results and compute next try --------------
    lbl compute_next_try
        rcl terminate_after_run         ; if terminated run exit
        x!=0 exit
 
        rcl test_voltage                ; display current results
        rcl ion_py_gu
        rcl current_try
        mess  ;n = #,  y = #,  volts = #
 
                                        ; test for abs y goal
        rcl ion_py_gu abs
        rcl _ABS_Goal_For_y
        x<y goto try_again              ; loop again if not close enough
 
        mess                            ;Attained Tuning Goal of #
        mess                            ;Final Rerun to Save Trajectories
        1 sto terminate_after_run       ; else flag termination
        exit
                                        ; next try is mean of upper and lower
    lbl try_again
        rcl lower_volts rcl upper_volts + 2 /
        sto test_voltage
