;--------------------------------------------------------------------
; this user program randomly changes the initial ke, direction, and position of ions
; energy is randomly changed +- Percent_Energy_Variation * ke
; ions are emitted randomly within a cone of revolution around the
; ion's defined velocity direction axis
; the full angle of the cone is +- Cone_Angle_Off_Vel_Axis
; (e.g. 90.0 is full hemisphere, 180 is a full sphere)
;--------------------------------------------------------------------
 
;--------- you can use it with your own lenses without modification ----------
;            (just rename user program file using your pa's name)
;------ Note: you can also modify the emission distributions as desired ------
defa Percent_Energy_Variation     50    ; (+- 50%) random energy variation
defa Cone_Angle_Off_Vel_Axis      90    ; (+- 90 deg) cone angle hemisphere
defa Random_Offset_mm           0.1     ; del start position (x,y,z) in mm
 
 
 
seg initialize                          ; initialize ion's velocity and direction
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
         
;        rcl ion_px_mm                   ; get nominal x start
;        rcl Random_Offset_mm rand * +   ; add random shift
;        rcl half_pos -                  ; subtract half shift
;        sto ion_px_mm                   ; store random x start
         
        rcl ion_py_mm                   ; get nominal y start
        rcl Random_Offset_mm rand * +   ; add random shift
        rcl half_pos -                  ; subtract half shift
        sto ion_py_mm                   ; store random y start
         
        rcl ion_pz_mm                   ; get nominal z start
        rcl Random_Offset_mm rand * +   ; add random shift
        rcl half_pos -                  ; subtract half shift
        sto ion_pz_mm                   ; store random z start
 
        ;---------------------- done -----------------------------------------
