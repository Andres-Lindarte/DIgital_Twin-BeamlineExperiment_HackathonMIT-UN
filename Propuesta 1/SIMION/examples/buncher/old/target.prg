; this user program outputs termination messages for buncher demo
 
defa first_ion 0                        ; flag for first ion
defa max_time 0                         ; holds max tof
defa min_time 0                         ; holds min tof
 
        
seg terminate                           ; terminate message generation
        rcl first_ion x!=0 goto compute ; compute if not first ion
        1 sto first_ion                 ; flag first ion
        rcl ion_time_of_flight          ; recall ion's tof
        sto max_time                    ; store as starting max and min tof
        sto min_time
        exit                            ; no printing for first ion
        
        lbl compute                     ; for other ions
        rcl max_time                    ; if tof > max_time
        rcl ion_time_of_flight
        x>y sto max_time                ; store tof as new max_time
        rcl min_time                    ; if tof < min_time
        rcl ion_time_of_flight
        x<y sto min_time                ; store tof as new min_time
        rcl max_time
        rcl min_time -                  ; delta tof of max and min
        rcl max_time
        rcl min_time + 2 /              ; average tof of max and min
                                        ; output status message
        mess                            ;Avg TOF = #, Delta TOF = # usec
