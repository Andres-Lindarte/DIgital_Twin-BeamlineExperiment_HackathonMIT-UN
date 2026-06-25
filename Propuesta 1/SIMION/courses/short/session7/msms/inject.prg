; ion trap demo program for simulating ion injection
; David A. Dahl 1996
 
 
; definition of user adjustable variables  -----------------------
 
        ; ---------- adjustable during flight -----------------
 
defa _Mean_Free_Path          40.0    ; mean free path in mm
defa _Collision_Gas_Mass       4.0    ; assume helium
defa _Avg_Mass_per_Atom       12.0    ; average mass per atom
defa _Avg_Visibility           0.666  ; average visibility of atoms
 
defa _Qz_tune                  0.908  ; Qz tuning point
defa _Az_tune                  0.0    ; Az tuning point
defa _AMU_Mass_per_Charge     40.0    ; mass tune point in amu/unit charge
 
defa _Target_Voltage           3.9    ; voltage of sims target
defa _Focus_Ring_Voltage      10.0    ; voltage on focus ring
defa _Left_Cap_Voltage         0.0    ; voltage on left end cap
defa _Right_Cap_Voltage        0.0    ; voltage on right end cap
defa _Time_to_trap_usec        20.0   ; time to use before ion is assumed trapped
defa _Max_Tstep_usec           0.05   ; max time step in micro seconds
 
        ; ---------- adjustable at beginning of flight -----------------
 
defa Ions_trapped              0.0    ; number of ions trapped
defa PE_Update_each_usec        0.05  ; pe surface update time step in usec
defa Percent_Energy_Variation  90.0   ; (+- 90%) random energy variation
defa Cone_Angle_Off_Vel_Axis   45.0   ; (+- 45 deg) cone angle
defa Random_Offset_mm           0.1   ; del start position (y,z) in mm
defa Random_TOB                 0.909091   ; random time of birth
 
defa Phaze_Angle_Deg           0.0    ; entry phase angle of ion
defa Freqency_Hz               1.1E6  ; rf frequency of quad in (hz)
defa Effective_Radius_in_cm    1.00   ; effective quad radius r0 in cm
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
seg initialize      ; randomize ions' position, ke, and direction
        1 sto Rerun_Flym                ; force rerun on
                                        ; turns traj file saving off
                                         
        ;------------------- get ion's initial velocity components -------------
        rcl ion_vz_mm                   ; get ion's specified velocity components
        rcl ion_vy_mm
        rcl ion_vx_mm
 
        ;------------------- convert to 3d polar coords -------------
        >p3d                            ; convert to polar 3d
 
        ;------------------- save polar coord values ----------------
        sto speed    rlup               ; store ion's speed
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
        ;--------- this gives 360 effective because of +- elevation angles ---
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
                                        ; x position is not randomized
        sto ion_px_mm                   ; store offset x start
 
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
        exit
 
 
 
 
;------------------------------------------------------------------------
seg Fast_Adjust                     ; generates trap rf with fast adjust
                                    ; has first pass initialization
    rcl first                       ; recall first pass flag
    x=0 gsb init                    ; if this is first reference  --> init
 
    rcl scaled_rf
    rcl _AMU_Mass_per_Charge *       ; multiply by mass per unit charge
    rcl _Qz_tune *                   ; rf tuning point
    sto rfvolts                     ; save rf voltage
 
    rcl scaled_rf
    rcl _AMU_Mass_per_Charge *       ; multiply by mass per unit charge
    rcl _Az_tune *                   ; substitute dc tune point
    2 / chs                         ; additional dc factor
    sto dcvolts                     ; save dc voltage
 
    rcl _Left_Cap_Voltage
    sto Adj_Elect02                 ; electrode 2 voltage - left end cap
    rcl _Right_Cap_Voltage
    sto Adj_Elect03                 ; electrode 3 voltage - right end cap
    rcl _Target_Voltage
    sto Adj_Elect04                 ; electrode 4 voltage - sample target
    rcl _Focus_Ring_Voltage
    sto Adj_Elect05                 ; electrode 5 voltage - focus ring
 
    rcl Ion_Time_of_Flight          ; current tof in micro seconds
    rcl omega *                     ; omega * tof
    rcl theta +                     ; add phasing angle
    sin                             ; sin(theta + (omgga * tof))
    rcl rfvolts *                   ; times rf voltage
    rcl dcvolts +                   ; add dc voltage
    chs 2 * sto Adj_Elect01         ; electrode 1 voltage (ring)
    exit                            ; exit program segment
 
 
lbl init                            ; parameter initialization subroutine
 
    1 sto first                     ; turn off first pass flag
     
    RCL Effective_Radius_in_cm      ; recall effective radius in cm
    entr *                          ; (r * r)
    rcl Freqency_Hz entr * *        ; multiply by frequency squared
    5.1145633E-12 * chs             ; -5.1145633E-12 * Qz * MASS * FREQ * FREQ * R0 * R0
    sto scaled_rf
 
    rcl Phaze_Angle_Deg
    >rad                            ; degrees to radians
    sto theta                       ; phase angle
 
    rcl Freqency_Hz                 ; rf frequancy in hz
    6.283185E-6 *                   ; to radians / microsecond
    sto omega                       ; save frequency in radians / usec
    rtn                             ; return from subroutine
 
 
 
;----------------------------------------------------------
seg tstep_adjust                    ; keep time step <= _Max_Tstep_usec
    rcl ion_time_step rcl _Max_Tstep_usec
    x>y exit
    sto ion_time_step
    exit
 
 
 
 
;------------------------------------------------------------------------
seg Other_Actions                   ; used to control pe surface updates
                                    ; also simulates collisional cooling
                                     
                                    ; mean free path for one visible atom
    rcl _mean_free_path x<=0 goto skip1            
    rcl ion_mass                    ; mass of ion
    rcl _Avg_Mass_per_Atom /        ; compute number of atoms
    1 - rcl _Avg_Visibility * 1 +   ; compute average atoms visibile
    / sto effective_free_path       ; compute effective free path
                                    ;    message ; Mean Free Path = #
     
    rcl ion_vz_mm                   ; mean free path cooling
    rcl ion_vy_mm                   ; load velocity vectors
    rcl ion_vx_mm
    >p3d                            ; convert velocity to polar coords
         sto v                      ; save in temporary variables
    rlup sto az
    rlup sto el
     
    rcl v rcl ion_time_step *       ; compute distance from tstep * v
    rcl effective_free_path / chs e^x
    1 x<>y -                        ;(1-e(-d/fp))
    rand                            ;get random number from 0 - 1
    x>y goto skip1                  ; no collision
                                    ; collision assume variable position hit on resting gas molecule
    1 rand x>=y goto skip1          ; no collision if r >= 1.0
    abs x>0 sqrt                    ; equal area r value
    asin                            ; collision angle in radians
    sto impact_angle_rad            ; save in local variable
 
                                    ; collision assume direct hit on resting gas molecule
    rcl ion_mass rcl _collision_gas_mass -
    rcl ion_mass rcl _collision_gas_mass + /    ; (m - mc)/(m + mc)
    x=0 0.000001                                ; protect against identical mass blowup
    rcl v * rcl impact_angle_rad cos * sto vr   ; attenuated radial velocity
    rcl v rcl impact_angle_rad sin * sto vt     ; attenuated tangential velocity
                                                ; compute resulting velocity
    rcl vr rcl vr * rcl vt rcl vt * + sqrt sto v 
 
    rcl impact_angle_rad rcl vt rcl vr / atan -
    >deg                            ; elevation off vertical
    90 +                            ; elevation off vertical
 
    360 rand *                      ; azimuth angle
    rcl v                           ; velocity
    >r3d                            ; compute rect assuming vertical is on original line
 
    -90 >elr                        ; el rotate back from 90 vertical
 
    rcl el >elr                     ;el rotate to initial el
    rcl az >azr                     ;az rotate to initial az
                                     
         sto ion_vx_mm              ;store back into user variables
    rlup sto ion_vy_mm
    rlup sto ion_vz_mm
                                    ; toggle ion color between blue and red
                                    ; to flag a collision
    rcl ion_color 1 x=y 3 sto ion_color
     
lbl skip1                           ; skip to point if no collision
    rcl _Time_to_trap_usec          ; get time to assumed capture
    rcl Ion_Time_of_Flight          ; get ion's time of flight
    x<=y goto skip                  ; don't kill if not captured
     
    -4 sto Ion_Splat                ; kill ion
    rcl Ions_trapped 1 +            ; up ion trapped count
    sto ions_trapped                ; save for future reference
    rcl Ion_number
                                    ; inform user of capture statistics
    message ; # Ions Flown:  # Ions Trapped
    exit
 
lbl skip                            ; pe surface update test
    rcl Next_PE_Update              ; recall time for next pe surface update
    rcl ion_time_of_flight          ; recall ion's time of flight
    x<y exit                        ; exit if tof less than next pe update
    rcl PE_Update_each_usec         ; recall pe update increment
    + sto next_pe_update            ; add to tof and store as next pe update
    1 sto Update_PE_Surface         ; request a pe surface update
    exit
 
 
 
;------------------------------------------------------------------------
seg Terminate                       ; used to turn off rerun mode
            0 sto rerun_flym     
