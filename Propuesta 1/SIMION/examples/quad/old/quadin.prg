; ion trap demo program
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
 
defa PE_Update_each_usec        0.05  ; pe surface update time step in usec
defa Percent_Energy_Variation  10.0   ; (+- 10%) random energy variation
defa Cone_Angle_Off_Vel_Axis    5.0   ; (+- 5 deg) cone angle - sphere
defa Random_Offset_mm           0.1   ; del start position (y,z) in mm
defa Random_TOB            0.909091   ; random time of birth over one cysle
 
defa Phaze_Angle_Deg           0.0    ; entry phase angle of ion
defa Freqency_Hz               1.1E6  ; rf frequency of quad in (hz)
defa Effective_Radius_in_cm    0.40   ; effective quad radius r0 in cm
 
 
 
; definition of static variables -----------------------------
 
defs first                     0.0    ; first call flag
defs scaled_rf                 0.0    ; scaled rf base
defs rfvolts                 100.0    ; rf voltage
defs dcvolts                   0.0    ; dc voltage
defs omega                     1.0    ; freq in radians / usec
defs theta                     0.0    ; phase offset in radians
 
defs Next_PE_Update_in         0.0    ; next time to update pe surface
 
 
; program segments below --------------------------------------------
 
 
;------------------------------------------------------------------------
seg initialize      ; randomize ion's position, ke, and direction
        ;------------------- get ion's initial velocity components -------------
        rcl ion_vz_mm                   ; get ion's specified velocity components
        rcl ion_vy_mm
        rcl ion_vx_mm
 
        ;------------------- convert to 3d polar coords -------------
        >p3d                            ; convert to polar 3d
 
        ;------------------- save polar coord values ----------------
        sto speed rlup                  ; store ion's speed
        sto az_angle rlup               ; store ion's az angle
        sto el_angle                    ; store ion's el angle
 
        ;------------------- make sure Percent_Energy_Variation is legal -------------
                                ; force 0 <= Percent_Energy_Variation <= 100
        rcl Percent_Energy_Variation abs
        100 x>y rlup sto Percent_Energy_Variation
 
        ;------------------- make sure Cone_Angle_Off_Vel_Axis is legal -------------
                                ; force 0 <= Cone_Angle_Off_Vel_Axis <= 180
        rcl Cone_Angle_Off_Vel_Axis abs
        180 x>y rlup sto Cone_Angle_Off_Vel_Axis
 
        ; ---------------------- calculate ion's defined ke -------------
        rcl ion_mass                    ; get ion's mass
        rcl speed                       ; recall its total speed
        >ke                             ; convert speed to kinetic energy
        sto kinetic_energy              ; save ion's defined kinetic energy
 
        ; ---------------------- compute new randomized ke -------------
                                        ; convert from percent to fraction
        rcl Percent_Energy_Variation 100 /
        sto del_energy 2 * rand *       ; fac = 2 * del_energy * rand
        rcl del_energy - 1 +            ; fac += 1 - del_energy
        rcl kinetic_energy *            ; new ke = fac * ke
 
        ; ---------------------- convert new ke to new speed -----------
        rcl ion_mass                    ; recall ion mass
        x><y                            ; swap x any y
        >spd                            ; convert to speed
        sto speed                       ; save new speed
 
        ;-- compute randomized el angle change 90 +- Cone_Angle_Off_Vel_Axis -------
        ;-------- we assume elevation of 90 degrees for mean ----------
        ;-------- so cone can be generated via rotating az +- 90 -------
                                    ; (2 * Cone_Angle_Off_Vel_Axis * rand)
        2 rcl Cone_Angle_Off_Vel_Axis * rand *
                                    ;  - Cone_Angle_Off_Vel_Axis + 90
        rcl Cone_Angle_Off_Vel_Axis - 90 +
 
        ;-------------- compute randomized az angle change ------------
        ;--------- this gives 360 effective because of +- elevation angels ---
        180 rand * 90 -                 ;          +- 90 randomized az
 
        ;---------------------- recall new ion speed ------------------
        rcl speed                       ; recall new speed
 
        ;--------- at this point x = speed, y = az, z = el --------------
        ;------------- convert to rectangular velocity components ---------
        >r3d                            ; convert polar 3d to rect 3d
 
        ;------------- el rotate back to from 90 vertical -------------
        -90 >elr
 
        ;------------- el rotate back to starting elevation -------------
        rcl el_angle >elr
 
        ;------------- az rotate back to starting azimuth -------------
        rcl az_angle >azr
 
        ;------------- update ion's velocity components with new values --------
        sto ion_vx_mm                   ; return vx
        rlup
        sto ion_vy_mm                   ; return vy
        rlup
        sto ion_vz_mm                   ; return vz
 
        ;--------- randomize ion's position components --------
        rcl Random_Offset_mm
        2 / sto half_pos                ; save half max shift
 
        rcl ion_py_mm                   ; get nominal y start
        rcl Random_Offset_mm rand * +   ; add random shift
        rcl half_pos -                  ; subtract half shift
        sto ion_py_mm                   ; store random y start
 
        rcl ion_pz_mm                   ; get nominal z start
        rcl Random_Offset_mm rand * +   ; add random shift
        rcl half_pos -                  ; subtract half shift
        sto ion_pz_mm                   ; store random z start
 
        ;--------- randomize ion's time of birth --------
        rcl Random_TOB abs rand *       ; create random time of birth
        sto Ion_Time_of_Birth           ; use it for ion
        ;---------------------- done -----------------------------------------
 
 
 
;------------------------------------------------------------------------
seg Fast_Adjust                     ; generates trap rf with fast adjust
                                    ; has first pass initialization
    rcl first                       ; recall first pass flag
    x=0 gsb init                    ; if this is first reference  --> init
 
    rcl scaled_rf
    rcl _AMU_Mass_per_Charge *      ; multiply by mass per unit charge
    sto rfvolts                     ; save rf voltage
 
    rcl scaled_rf
    rcl _AMU_Mass_per_Charge *      ; multiply by mass per unit charge
    rcl _Percent_tune *             ; substitute dc tune point
    100 /
    0.1678399 *
    sto dcvolts                     ; save dc voltage
 
    rcl _Quad_Entrance_Voltage
    sto Adj_elect03                 ; update quad entrance voltage
 
    rcl Ion_Time_of_Flight          ; current tof in micro seconds
    rcl omega *                     ; omega * tof
    rcl theta +                     ; add phasing angle
    sin                             ; sin(theta + (omgga * tof))
    rcl rfvolts *                   ; times rf voltage
    rcl dcvolts +                   ; add dc voltage
    sto tempvolts                   ; save rf dc voltage
    rcl _Quad_Axis_Voltage +        ; add quad axis voltage
    sto Adj_Elect01                 ; electrode 1 voltage
    rcl _Quad_Axis_Voltage          ; rcall quad axis voltage
    rcl tempvolts -                 ; subtract rf dc from it
    sto Adj_Elect02                 ; electrode 2 voltage
    exit                            ; exit program segment
 
 
lbl init                            ; parameter initialization subroutine
 
    1 sto first                     ; tunn off first pass flag
 
    RCL Effective_Radius_in_cm      ; recall effective radius in cm
    entr *                          ; (r * r)
    rcl Freqency_Hz entr * *        ; multiply by frequency squared
    7.11016e-12 *                   ; 7.11016-12 * MASS * FREQ * FREQ * R0 * R0
    sto scaled_rf
    rcl _AMU_Mass_per_Charge *      ; multiply by mass per unit charge
    sto rfvolts                     ; save rf voltage
 
    rcl scaled_rf
    rcl _AMU_Mass_per_Charge *      ; multiply by mass per unit charge
    rcl _Percent_tune *             ; substitute dc tune point
    100 /
    0.1678399 *
    sto dcvolts                     ; save dc voltage
 
    rcl Phaze_Angle_Deg
    >rad                            ; degrees to radians
    sto theta                       ; phasc angle
 
    rcl Freqency_Hz                 ; rf frequancy in hz
    6.28318E-6 *                    ; to radians / microsecond
    sto omega                       ; save frequency in radians / usec
    rtn                             ; return from subroutine
 
 
 
 
 
;------------------------------------------------------------------------
seg Other_Actions                   ; used to control pe surface updates
    rcl Next_PE_Update_in           ; recall time for next pe surface update
    rcl ion_time_of_flight          ; recall ion's time of flight
    x<y exit                        ; exit if tof less than next pe update
    rcl PE_Update_each_usec         ; recall pe update increment
    + sto Next_PE_Update_in         ; add to tof and store as next pe update
    1 sto Update_PE_Surface         ; request a pe surface update
 
