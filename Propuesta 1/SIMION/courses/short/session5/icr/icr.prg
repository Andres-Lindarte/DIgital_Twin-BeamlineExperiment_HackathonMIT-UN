;ICR SIMULATION PROGRAM  
;D.A.Dahl and A.D.Appelhans  1995 
                 
 
; ----------------- user adjustable variables -------------------
 
defa Start_Rht_Voltage          5   ;starting right end voltage
defa Capture_Voltage            3   ;endcap capture voltage
defa Rf_Voltage                20   ;peak voltage on rf plates for excite phase
defa Bx_Gauss               30000   ;magnetic field in gauss
defa Starting_Mass_amu        950   ;lower mass for rf sweep
defa Ending_Mass_amu         1050   ;upper mass for rf sweep
defa Rf_Sweep_Time_usec       100   ;rf sweep time in usec
defa Start_Delay_usec          80   ;time delay before starting rf sweep
                               
defa PE_Update_each_usec       1.0 ; pe surface update time step in usec
; -------------------- static variables ------------------------
  
defs first                      0   ;first call flag
defs Starting_Rf                1   ;start mass frequancy for sweep
defs Ending_Rf                  1   ;end mass frequency for sweep
defs Rf_Slope                   1   ;rf sweep slope (rate of frequency change)
defs T_Delay_usec               0   ;time delay before starting rf sweep
defs T_Excite_usec              0   ;time at end of excite phase
 
defs tmark                   1000   ;time for next transition
defs color                      1   ;ion color after transition
 
defs Next_PE_Update             0   ;next time for PE update
  
 
 
 
; -------------------- user program segments -------------------
         
         
         
 
; ------------------ time control for transitions ---------------
seg Tstep_Adjust                    ;time step adjust program segment
                                    ;used to precisely approach both
                                    ;sweep start and stop transitions
        1 sto color                 ;assume next color is red
        rcl T_Delay_usec            
        sto tmark                   ;assume initial delay transition
        rcl Ion_Time_of_Flight      ;get ion's current time of flight
        x>=y goto tran2             ;jump if at or beyond first transition
        - rcl Ion_Time_Step         ;compute time to transition
        x<=y Exit                   ;if greater than time step exit
        x><y sto Ion_Time_Step      ;else use for time step
        exit                        ;return to simion
         
    lbl tran2                       ;test for sweep stop transition
        2 sto color                 ;assume next color is green
        rcl T_Excite_usec
        sto tmark                   ;assume final delay transition
        rcl Ion_Time_of_Flight      ;get ion's current time of flight
        x>=y exit                   ;exit if at or beyond first transition
        - rcl Ion_Time_Step         ;compute time to transition
        x<=y Exit                   ;if greater than time step exit
        x><y sto Ion_Time_Step      ;else use for time step
        exit                        ;return to simion
         
         
         
         
; ------------- control icr cell voltages --------------------- 
seg Fast_Adjust                     ;fast voltage adjust segment
 
        rcl first                   ;recall first pass flag
        x=0                         ;if this is first time through for run
        gosub init                  ;setup factors first --> init
  
 
        ; check if time > start delay --------------------------
 
        rcl T_Delay_usec            ;recall start delay time in usec
        rcl Ion_Time_of_Flight      ;recall Ion_Time_of_Flight in usec
        x<=y                        ;check for end of delay time
        goto Start_Voltages         ;if time <= start delay --> constant
 
        ; check for end of rf sweep time -------------------------
 
        rcl T_Excite_usec           ;recall end of sweep time in usec
        rcl Ion_Time_of_Flight      ;recall Ion_Time_of_Flight in usec
        x>y                         ;check for end of sweep time
        goto constant               ;if time > end of sweep --> constant
 
 
        ; calculate omega for rf voltage calculation --------------- 
 
        rcl Ion_Time_of_Flight      ;recall ion's tof
        rcl T_Delay_usec -          ;calculate time into rf ramp
        rcl Rf_Slope *              ;recall slope for frequency ramp
        rcl Starting_Rf             ;recall starting frequency for ramp 
        +                           ;omega = (Starting_Rf + Rf_Slope*(tof - T_Delay_usec))
 
        ; calculate rf voltage for exciter plates ------------------
 
        rcl Ion_Time_of_Flight      ;recall ion's tof
        rcl T_Delay_usec - *        ;CALCULATE TIME INTO Rf RAMP
        sin                         ;sin(omega*(tof - T_Delay_usec))
        rcl Rf_Voltage *            ;Compute rf voltage
        sto Adj_Elect01             ;store in electrode 1
        chs sto Adj_Elect02         ;store negative in electrode 2
        0                           ;zero side electrodes
        sto Adj_Elect03             ;store in electrode 3
        sto Adj_Elect04             ;store in electrode 4
        rcl Capture_voltage
        sto Adj_Elect05             ;store in electrode 5
        sto Adj_Elect06             ;store in electrode 6
        exit                        ;return to simion
   
   
    
    ; initialize parameters for excitation sweep control ----------
    
    LBL INIT                        ;entry point for init subroutine
     
        1 sto first                 ;turn off first pass flag
          
        ; convert magnetic field to tesla ------------------
         
        rcl Bx_Gauss                ;recall the magnetic field strength (gauss)
        10000 /                     ;convert to tesla
        sto temp1                   ;store magnetic field in tesla
 
        ; compute frequency for rf ramp start mass ---------
 
        rcl Starting_Mass_amu /     ;recall the frequency ramp start mass 
        1.6022E-19 *                ;convert to coulombs
        1.6605E-27 /                ;convert amu to kg
        1E6 /                       ;convert to radians/usec
        sto Starting_Rf             ;store starting ramp freq to Starting_Rf
 
        ; compute frequency for rf ramp end mass ---------------
 
        rcl temp1                   ;recall magnetic field
        rcl Ending_Mass_amu /       ;recall end mass for frequency sweep
        1.6022E-19 *                ;convert to coulombs
        1.6605E-27 /                ;convert amu to kg
        1E6 /                       ;convert to radians/usec
        sto Ending_Rf               ;store ending ramp freq to Starting_Rf
 
        ; calculate slope of frequency ramp ---------------------
 
        rcl Starting_Rf             ;recall start frequency in rad/usec
        -                           ;define frequency range ( Ending_Rf - Starting_Rf )
        rcl Rf_Sweep_Time_usec /    ;calculate rate of rf sweep (slope)
        sto Rf_Slope                ;store slope of rf sweep ramp 
 
        ; compute and store times for start ans stop of excite ramp -----
 
        rcl Start_Delay_usec        ;recall delay time before starting rf ramp
        sto T_Delay_usec            ;store in T_Delay_usec
        rcl Rf_Sweep_Time_usec      ;recall rf sweep time for rf ramp
        + sto T_Excite_usec         ;add to dalay time and store in T_Excite_usec (END OF Rf RAMP)
        rtn                         ;return to remainder of fast_adjust seg
 
 
    ; set electrodes 1, 2, 3, and 4 to zero volts --------------
     
    lbl constant                    ;constant voltage
        0                           ;use zero volts
        sto Adj_Elect01             ;set elect 1-4 to zero
        sto Adj_Elect02
        sto Adj_Elect03
        sto Adj_Elect04
        rcl Capture_voltage
        sto Adj_Elect05             ;store in electrode 5
        sto Adj_Elect06             ;store in electrode 6
        exit                        ;return to simion
     
    lbl Start_voltages              ;starting voltages
        0                           ;use zero volts
        sto Adj_Elect05             ;set left entrance to zero volts
        rcl Start_Rht_Voltage
        sto Adj_Elect06             ;set right entrance to right voltage
        2 /
        sto Adj_Elect01             ;set elect 1-4 to half of right voltage
        sto Adj_Elect02
        sto Adj_Elect03
        sto Adj_Elect04
        exit                        ;return to simion
 
 
; ------------- transition color control --------------------- 
seg Other_Actions
        rcl Next_PE_Update          ; recall time for next pe surface update
        rcl ion_time_of_flight      ; recall ion's time of flight
        x<y goto next_test          ; next test if tof less than next pe update
        rcl PE_Update_each_usec     ; recall pe update increment
        + sto next_pe_update        ; add to tof and store as next pe update
        1 sto Update_PE_Surface     ; request a pe surface update
         
    lbl next_test     
        rcl Ion_Time_of_Flight      ;recall ion's TOF
        rcl tmark                   ;recall transition time
        x!=y exit                   ;exit if not at transition
        rcl color sto Ion_color     ;set ion's after transition color
        bell
