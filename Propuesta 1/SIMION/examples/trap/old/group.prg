; ion trap demo program
; David A. Dahl 1995
 
 
; definition of user adjustable variables  -----------------------
 
        ; ---------- adjustable during flight -----------------
 
defa _Linear_Damping           1.0    ; adjustable variable for linear damping
defa _Qz_tune                  0.8    ; Qz tuning point
defa _Az_tune                  0.00   ; Az tuning point
defa _AMU_Mass_per_Charge    100.0    ; mass tune point in amu/unit charge
defa _Target_Voltage           0.0    ; voltage of sims target
defa _Left_Cap_Voltage         0.0    ; voltage on left cap
defa _Right_Cap_Voltage        0.0    ; voltage on right cap
 
        ; ---------- adjustable at beginning of flight -----------------
 
defa PE_Update_each_usec        0.05  ; pe surface update time step in usec
defa Percent_Energy_Variation  90.0   ; (+- 90%) random energy variation
defa Cone_Angle_Off_Vel_Axis  180.0   ; (+- 180 deg) cone angle - sphere
defa Random_Offset_mm           0.1   ; del start position (x,y,z) in mm
defa Random_TOB                 0.909091   ; random time of birth over one cysle
 
defa Phaze_Angle_Deg           0.0    ; entry phase angle of ion
defa Freqency_Hz               1.1E6  ; rf frequency of quad in (hz)
defa Effective_Radius_in_cm    0.41   ; effective quad radius r0 in cm
defa mm_per_Grid_Unit          0.1    ; grid scaling mm/grid unit
 
 
 
; definition of static variables -----------------------------
 
defs first                     0.0    ; first call flag
defs scaled_rf                 0.0    ; scaled rf base
defs rfvolts                 100.0    ; rf voltage
defs dcvolts                   0.0    ; dc voltage
defs omega                     1.0    ; freq in radians / usec
defs theta                     0.0    ; phase offset in radians
 
defs Next_PE_Update            0.0    ; next time to update pe surface
 
 
; program segments below --------------------------------------------
 
 
;------------------------------------------------------------------------
seg initialize      ; randomize ion's position, ke, and direction
        1 sto Rerun_Flym                ; force rerun on
                                        ; turns traj file saving off
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
 
        rcl ion_px_mm                   ; get nominal x start
        rcl Random_Offset_mm rand * +   ; add random shift
        rcl half_pos -                  ; subtract half shift
        sto ion_px_mm                   ; store random x start
 
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
    rcl _Qz_tune *                  ; rf tuning point
    sto rfvolts                     ; save rf voltage
 
    rcl scaled_rf
    rcl _AMU_Mass_per_Charge *      ; multiply by mass per unit charge
    rcl _Az_tune *                  ; substitute dc tune point
    2 / chs                         ; additional dc factor
    sto dcvolts                     ; save dc voltage
 
    rcl _Left_Cap_Voltage
    sto Adj_Elect01                 ; electrode 1 voltage
    rcl _Right_Cap_Voltage
    sto Adj_Elect03                 ; electrode 3 voltage
    rcl _Target_Voltage
    sto Adj_Elect04                 ; electrode 4 voltage
 
    rcl Ion_Time_of_Flight          ; current tof in micro seconds
    rcl omega *                     ; omega * tof
    rcl theta +                     ; add phasing angle
    sin                             ; sin(theta + (omgga * tof))
    rcl rfvolts *                   ; times rf voltage
    rcl dcvolts +                   ; add dc voltage
    chs 2 * sto Adj_Elect02         ; electrode 2 voltage
    exit                            ; exit program segment
 
 
lbl init                            ; parameter initialization subroutine
 
    1 sto first                     ; tunn off first pass flag
 
    RCL Effective_Radius_in_cm      ; recall effective radius in cm
    entr * 2 /                      ; (r * r)/2
    rcl Freqency_Hz entr * *        ; multiply by frequency squared
    1.022442E-11 * chs              ; -1.022442E-11 * Qz * MASS * FREQ * FREQ * R0 * R0
    sto scaled_rf
    rcl _AMU_Mass_per_Charge *      ; multiply by mass per unit charge
    rcl _Qz_tune *                  ; rf tuning point
    sto rfvolts                     ; save rf voltage
 
    rcl scaled_rf
    rcl _AMU_Mass_per_Charge *      ; multiply by mass per unit charge
    rcl _Az_tune *                  ; substitute dc tune point
    2 / chs                         ; additional dc factor
    sto dcvolts                     ; save dc voltage
 
    rcl Phaze_Angle_Deg
    >rad                            ; degrees to radians
    sto theta                       ; phasc angle
 
    rcl Freqency_Hz                 ; rf frequancy in hz
    6.28318E-6 *                    ; to radians / microsecond
    sto omega                       ; save frequency in radians / usec
    rtn                             ; return from subroutine
 
 
 
;----------------------------------------------------------
seg tstep_adjust                    ; keep time step <= 0.1 Usec
    rcl ion_time_step 0.1
    x>y exit
    sto ion_time_step
 
 
 
 
 
 
 
;------------------------------------------------------------------------
seg accel_adjust                    ; adds viscous effects to ion motions
 
    rcl ion_time_step x=0 exit      ; exit if zero time step
    rcl _linear_damping x=0 exit    ; exit if damping set to zero
    abs sto damping                 ; force damping term to be positive
    * sto tterm                     ; compute and save number of time constants
    chs e^x 1 x><y -                ; (1 - e^(-(t * damping)))
    rcl tterm / sto factor          ; factor = (1 - e^(-(t * damping)))/(t * damping)
 
    rcl ion_ax_mm                   ; recall ax acceleration
    rcl ion_vx_mm                   ; recall vx velocity
    rcl damping * -                 ; multiply times damping and sub from ax
    rcl factor *                    ; multiply times factor
    sto ion_ax_mm                   ; store as new ax acceleration
 
    rcl ion_ay_mm                   ; recall ay acceleration
    rcl ion_vy_mm                   ; recall vy velocity
    rcl damping * -                 ; multiply times damping and sub from ay
    rcl factor *                    ; multiply times factor
    sto ion_ay_mm                   ; store as new ay acceleration
 
    rcl ion_az_mm                   ; recall az acceleration
    rcl ion_vz_mm                   ; recall vz velocity
    rcl damping * -                 ; multiply times damping and sub from az
    rcl factor *                    ; multiply times factor
    sto ion_az_mm                   ; store as new az acceleration
 
 
 
 
;------------------------------------------------------------------------
seg Other_Actions                   ; used to control pe surface updates
    rcl Next_PE_Update              ; recall time for next pe surface update
    rcl ion_time_of_flight          ; recall ion's time of flight
    x<y exit                        ; exit if tof less than next pe update
    rcl PE_Update_each_usec         ; recall pe update increment
    + sto next_pe_update            ; add to tof and store as next pe update
    1 sto Update_PE_Surface         ; request a pe surface update
 
 
 
;------------------------------------------------------------------------
seg Terminate
            0 sto rerun_flym        ; turn off rerun mode
