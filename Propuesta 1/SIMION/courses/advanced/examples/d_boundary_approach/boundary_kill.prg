;--------------------------------------------------------------------
; this user program kills ions at some 3D radius from their starting point
;
; energy is randomly changed +- Percent_Energy_Variation * ke
; ions are emitted randomly within a cone of revolution around the
; ion's defined velocity direction axis
; the full angle of the cone is +- Cone_Angle_Off_Vel_Axis
; (e.g. 90.0 is full hemisphere, 180 is a full sphere)
;--------------------------------------------------------------------

defa Boundary_Radius_mm 		30.0	; 3D boundary ion kill radius in mm
defa Radius_accuracy_mm 		 0.0001 ; boundary approach accuracy for radius
										; ions killed within
										; +/- radius_accuracy_mm / 2
										; of boundary_radius_mm

defa Percent_Energy_Variation	  50	; (+- 50%) random energy variation
defa Cone_Angle_Off_Vel_Axis	  90	; (+- 90 deg) cone angle hemisphere

										;holds ions' previous positions
adefa prior_ion_px_mm			1000	;1000 element array
adefa prior_ion_py_mm			1000	;1000 element array
adefa prior_ion_pz_mm			1000	;1000 element array

										;holds ions' previous velocities
adefa prior_ion_vx_mm			1000	;1000 element array
adefa prior_ion_vy_mm			1000	;1000 element array
adefa prior_ion_vz_mm			1000	;1000 element array

										;holds ions' previous time step and tof
adefa prior_ion_time_step		1000	;1000 element array
adefa prior_ion_time_of_flight	1000	;1000 element array

adefa prior_ion_half_step_flag	1000	;1000 element array - half step
adefa prior_ion_boundary_flag	1000	;1000 element array - kill on next step
adefa fatal_error_flag			   1	;fatal error flag


seg initialize							; initialize ion's velocity and direction
		1 arcl fatal_error_flag  x!=0 exit	;exit if fatal error
		1000 rcl ion_number x<=y goto ok	;trap array out of range
		beep_sound
		message ;Too many ions defined 1000 max
		1 1 asto fatal_error_flag		; flag fatal error
		exit

		lbl ok
		;------------------- get ion's initial velocity components -------------
		rcl ion_vz_mm					; get ion's specified velocity components
		rcl ion_vy_mm
		rcl ion_vx_mm

		;------------------- convert to 3d polar coords -------------
		>p3d							; convert to polar 3d

		;------------------- save polar coord values ----------------
		sto speed rlup					; store ion's speed
		sto az_angle rlup				; store ion's az angle
		sto el_angle					; store ion's el angle

		;------------------- make sure Percent_Energy_Variation is legal -------------
								; force 0 <= Percent_Energy_Variation <= 100
		rcl Percent_Energy_Variation abs
		100 x>y rlup sto Percent_Energy_Variation

		;------------------- make sure Cone_Angle_Off_Vel_Axis is legal -------------
								; force 0 <= Cone_Angle_Off_Vel_Axis <= 180
		rcl Cone_Angle_Off_Vel_Axis abs
		180 x>y rlup sto Cone_Angle_Off_Vel_Axis

		; ---------------------- calculate ion's defined ke -------------
		rcl ion_mass					; get ion's mass
		rcl speed						; recall its total speed
		>ke 							; convert speed to kinetic energy
		sto kinetic_energy				; save ion's defined kinetic energy

		; ---------------------- compute new randomized ke -------------
										; convert from percent to fraction
		rcl Percent_Energy_Variation 100 /
		sto del_energy 2 * rand *		; fac = 2 * del_energy * rand
		rcl del_energy - 1 +			; fac += 1 - del_energy
		rcl kinetic_energy *			; new ke = fac * ke

		; ---------------------- convert new ke to new speed -----------
		rcl ion_mass					; recall ion mass
		x><y							; swap x any y
		>spd							; convert to speed
		sto speed						; save new speed

		;-- compute randomized el angle change 90 +- Cone_Angle_Off_Vel_Axis -------
		;-------- we assume elevation of 90 degrees for mean ----------
		;-------- so cone can be generated via rotating az +- 90 -------
									; (2 * Cone_Angle_Off_Vel_Axis * rand)
		2 rcl Cone_Angle_Off_Vel_Axis * rand *
									;  - Cone_Angle_Off_Vel_Axis + 90
		rcl Cone_Angle_Off_Vel_Axis - 90 +

		;-------------- compute randomized az angle change ------------
		;--------- this gives 360 effective because of +- elevation angels ---
		180 rand * 90 - 				;		   +- 90 randomized az

		;---------------------- recall new ion speed ------------------
		rcl speed						; recall new speed

		;--------- at this point x = speed, y = az, z = el --------------
		;------------- convert to rectangular velocity components ---------
		>r3d							; convert polar 3d to rect 3d

		;------------- el rotate back to from 90 vertical -------------
		-90 >elr

		;------------- el rotate back to starting elevation -------------
		rcl el_angle >elr

		;------------- az rotate back to starting azimuth -------------
		rcl az_angle >azr

		;------------- update ion's velocity components with new values --------
		sto ion_vx_mm					; return vx
		rlup
		sto ion_vy_mm					; return vy
		rlup
		sto ion_vz_mm					; return vz

		rcl ion_number sto n
										;save starting positions
		rcl ion_px_mm rcl n asto prior_ion_px_mm
		rcl ion_py_mm rcl n asto prior_ion_py_mm
		rcl ion_pz_mm rcl n asto prior_ion_pz_mm
										;save starting velocities
		rcl ion_vx_mm rcl n asto prior_ion_vx_mm
		rcl ion_vy_mm rcl n asto prior_ion_vy_mm
		rcl ion_vz_mm rcl n asto prior_ion_vz_mm

		;---------------------- done -----------------------------------------


seg tstep_adjust
	rcl ion_number sto n			;save copy of ion number

	arcl prior_ion_half_step_flag	;get boundary approach flag for ion
	x=0  exit						;exit if not set for boundary approach

	rcl n arcl prior_ion_time_step
	2 / sto ion_time_step			;halve the prior time step
									;clear the half step flag
	0 rcl n asto prior_ion_half_step_flag
	exit


seg other_actions
								;kill ion on fatal error abort
	1 arcl fatal_error_flag  x=0 goto ok
		1001 arcl fatal_error_flag ;force illegal command
		exit

	lbl ok
	rcl ion_number sto n			;save copy of ion number

	arcl prior_ion_boundary_flag
	x!=0 goto kill					;kill ion if already crossed boundary

	rcl boundary_radius_mm abs			;get kill radius
	sto boundary_radius_mm
	rcl Radius_accuracy_mm abs
	sto Radius_accuracy_mm
							   2 / -	;inside kill radius
	rcl ion_px_mm entr *
	rcl ion_py_mm entr * +
	rcl ion_pz_mm entr * +
	sqrt sto r						;ion's current radius
	x>y goto half_step				;goto setup for half stepping

									;just save current state as prior
									;save positions
	rcl ion_px_mm rcl n asto prior_ion_px_mm
	rcl ion_py_mm rcl n asto prior_ion_py_mm
	rcl ion_pz_mm rcl n asto prior_ion_pz_mm
									;save velocities
	rcl ion_vx_mm rcl n asto prior_ion_vx_mm
	rcl ion_vy_mm rcl n asto prior_ion_vy_mm
	rcl ion_vz_mm rcl n asto prior_ion_vz_mm
									;save time of flight
	rcl ion_time_of_flight rcl n asto prior_ion_time_of_flight
	exit

	lbl half_step				   ;prepare to back up and half step
	rcl r						   ;get ion's radius
	rcl boundary_radius_mm		   ;get kill radius
	- abs						   ;absolute difference
	rcl Radius_accuracy_mm 2 /	   ;within half radius accuracy
	x>y goto markit 			   ;mark ion to be killed in next step


									;else back up and halve the time step
									;restore prior positions
	rcl n arcl prior_ion_px_mm sto ion_px_mm
	rcl n arcl prior_ion_py_mm sto ion_py_mm
	rcl n arcl prior_ion_pz_mm sto ion_pz_mm
									;restore prior velocities
	rcl n arcl prior_ion_vx_mm sto ion_vx_mm
	rcl n arcl prior_ion_vy_mm sto ion_vy_mm
	rcl n arcl prior_ion_vz_mm sto ion_vz_mm
									;restore prior time of flight
	rcl n arcl prior_ion_time_of_flight sto ion_time_of_flight
									;flag half step boundary approach
	1 rcl n asto prior_ion_half_step_flag
									;save prior time step for tstep use
	rcl ion_time_step rcl n asto prior_ion_time_step
	exit



	lbl markit						;mark ion for death on next time step
	1 rcl n asto prior_ion_boundary_flag
	rcl r							;output ion's current radius
	rcl n
	message ; ion = # kill_r = #
	exit

	lbl kill
	-4 sto ion_splat				;kill the ion
