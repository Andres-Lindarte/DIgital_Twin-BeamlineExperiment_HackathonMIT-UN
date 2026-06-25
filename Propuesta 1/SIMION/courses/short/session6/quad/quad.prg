; quadrupole demo program
; David A. Dahl 1995
 
 
; definition of user adjustable variables  -----------------------
 
        ; ---------- adjustable during flight -----------------
 
defa _Percent_tune            97.0    ; percent of optimum tune
defa _AMU_Mass_per_Charge    100.0    ; mass tune point in amu/unit charge
defa _Quad_Entrance_Voltage    0.0    ; voltage of quad entrance
defa _Quad_Axis_Voltage       -8.0    ; voltage of quad axis
defa _Quad_Exit_Voltage     -100.0    ; voltage of quad exit
defa _Detector_Voltage     -1500.0    ; voltage of detector
 
        ; ---------- adjustable at beginning of flight -----------------
 
defa PE_Update_each_usec       0.05   ; potential energy surface update time step in usec
defa Phaze_Angle_Deg           0.0    ; entry phase angle of ion
defa Freqency_Hz               1.1E6  ; rf frequency of quad in (hz)
defa Effective_Radius_in_cm    0.40   ; effective quad radius r0 in cm
 
 
 
; definition of static variables -----------------------------
 
defs scaled_rf                 0.0    ; scaled rf base
defs rfvolts                 100.0    ; rf voltage
defs dcvolts                   0.0    ; dc voltage
defs omega                     1.0    ; freq in radians / usec
defs theta                     0.0    ; phase offset in radians
 
defs Next_PE_Update            0.0    ; next time to update pe surface
 
 
; program segments below --------------------------------------------
 
 
 
;------------------------------------------------------------------------
seg Fast_Adjust                     ; generates quad rf with fast adjust
 
    rcl scaled_rf
    rcl _AMU_Mass_per_Charge *      ; multiply by mass per unit charge
    sto rfvolts                     ; save rf voltage
 
    rcl scaled_rf
    rcl _AMU_Mass_per_Charge *      ; multiply by mass per unit charge
    rcl _Percent_tune *             ; substitute dc tune point
    100 /
    0.1678399 *                     ; constants for dimensions 
    sto dcvolts                     ; save dc voltage
 
    rcl Ion_Time_of_Flight          ; current tof in micro seconds
    rcl omega *                     ; omega * tof
    rcl theta +                     ; add phasing angle
    sin                             ; sin(theta + (omega * tof))
    rcl rfvolts *                   ; times rf voltage
    rcl dcvolts +                   ; add dc voltage
    sto tempvolts                   ; save rf dc voltage
    rcl _Quad_Axis_Voltage +        ; add quad axis voltage
    sto Adj_Elect01                 ; electrode 1 voltage
    rcl _Quad_Axis_Voltage          ; rcall quad axis voltage
    rcl tempvolts -                 ; subtract rf dc from it
    sto Adj_Elect02                 ; electrode 2 voltage
    exit                            ; exit program segment
 
 
 
 
 
;------------------------------------------------------------------------
seg Other_Actions                   ; used to control pe surface updates
    rcl Next_PE_Update              ; recall time for next pe surface update
    rcl ion_time_of_flight          ; recall ion's time of flight
    x<y exit                        ; exit if tof less than next pe update
    rcl PE_Update_each_usec         ; recall pe update increment
    + sto next_pe_update            ; add to tof and store as next pe update
    1 sto Update_PE_Surface         ; request a pe surface update
 
