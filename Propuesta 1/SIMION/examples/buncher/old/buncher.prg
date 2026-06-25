;main buncher control program
;Note:  Output messages generated in target.prg user programs
 
defa Switch_Time 1.7            ; switch time in microseconds
defa Buncher_voltage 900        ; buncher deceleration voltage
 
defs update_flag 1              ; pe surface update flag set on at start
 
 
seg tstep_adjust                ; for precise control of transition
        rcl switch_time         ; recall time for transition
        rcl ion_time_of_flight  ; recall ion's current time of flight
        x>=y exit               ; exit if beyond transition
        rcl ion_time_step +     ; add planned time step
        x<=y exit               ; exit if won't exceed transition
         
        rcl switch_time         ; adjust time step to hit transition exactly
        rcl ion_time_of_flight
        - sto ion_time_step     ; requested time step
 
 
 
seg fast_adjust                 ; buncher voltage control
        rcl switch_time         ; recall time for transition
        rcl ion_time_of_flight  ; recall ion's current time of flight
        x<y goto zapit          ; jump if before transition
         
        0 sto adj_elect01 exit  ; after transition zero buncher voltage   
         
    lbl zapit                   ; before transtion use requested
        rcl buncher_voltage     ; buncher voltage to slow ions
        sto adj_elect01
 
 
 
seg other_actions               ; verifies and flags proper functioning
        gosub pe_update         ; update pe surface as required
        rcl switch_time         ; recall time for transition
        rcl ion_time_of_flight  ; recall ion's current time of flight
        x!=y exit               ; exit if not exactly at transition time
         
        ; --- note: only marks if we hit the transition perfectly --- we do!
                                ; else at exact transition time
        3 sto ion_color         ; switch ion's color to blue
        mark                    ; mark current location of ion
        1 sto update_flag       ; set pe surface update for next time step
        exit                    ; exit from segment
         
  lbl   pe_update               ; pe update subroutine
        rcl update_flag         ; get update flag
        x=0 rtn                 ; return to caller if not set
        0 sto update_flag       ; clear update flag
        1 sto Update_PE_Surface ; flag a pe surface update (if active)
        rtn                     ; return to caller
