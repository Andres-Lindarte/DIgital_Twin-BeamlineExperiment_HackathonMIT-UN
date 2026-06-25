; ion trap demo program - demonstrates use of msms
; David A. Dahl 1995


; definition of user adjustable variables  -----------------------

		; ---------- adjustable during flight -----------------

defa _Parent_Mass			  303.0   ; mass of parent ion
defa _Daughter_Mass 		   80.0   ; mass of daughter
defa _Tickle_Voltage		   0.2	  ; tickle voltage
defa _Fragment_energy_eV		1.0   ; fragment energy in ev
defa _Ratio_absorbed			0.5   ; ratio of energy absorbed
defa _Time_to_trap_usec 	   20.0   ; time to use before ion is assumed trapped
defa _Tickle_Frequency		 93.5e3   ; tickle frequency of 93.5 khz
defa _Mean_Free_Path		  20.0	  ; mean free path in mm
defa _Collision_Gas_Mass	   4.0	  ; assume helium
defa _Qz_tune				   0.908  ; Qz tuning point
defa _Az_tune				   0.00   ; Az tuning point
defa _AMU_Mass_per_Charge	  40.0	  ; mass tune point in amu/unit charge
defa _Max_Tstep_usec		   0.05   ; max time step in micro seconds

		; ---------- adjustable at beginning of flight -----------------

defa PE_Update_each_usec		0.05  ; pe surface update time step in usec
defa Percent_Energy_Variation  90.0   ; (+- 90%) random energy variation
defa Cone_Angle_Off_Vel_Axis  180.0   ; (+- 180 deg) cone angle - sphere
defa Random_Offset_mm			0.1   ; del start position (x,y,z) in mm
defa Random_TOB 				0.909091   ; random time of birth over one cysle

defa Phaze_Angle_Deg		   0.0	  ; entry phase angle of ion
defa Freqency_Hz			   1.1E6  ; rf frequency of quad in (hz)
defa Effective_Radius_in_cm    1.00   ; effective quad radius r0 in cm
defa mm_per_Grid_Unit		   0.1	  ; grid scaling mm/grid unit
defa ions_trapped				0.0   ; number of ions trapped



; definition of static variables -----------------------------

defs first					   0.0	  ; first call flag
defs fragmented 			   0.0	  ; mass has been fragmented
defs time_of_fragmentation	   0.0	  ; time ion was fragmented
defs scaled_rf				   0.0	  ; scaled rf base
defs rfvolts				 100.0	  ; rf voltage
defs dcvolts				   0.0	  ; dc voltage
defs omega					   1.0	  ; freq in radians / usec
defs theta					   0.0	  ; phase offset in radians
defs tickle_omega			   1.0	  ; tickle freq in rad / sec

defs Next_PE_Update 		   0.0	  ; next time to update pe surface
defs tickle 0
defs total_ke_absorbed		   0.0	  ; total amount of ke absorbed

defs _beta_guess			   0.0	  ; initial guess at B
defs _beta_next 			   0.0	  ; final estimate of B
defs _qz_next				   0.0	  ; parent ion qz operating point


; program segments below --------------------------------------------


;------------------------------------------------------------------------
seg initialize		; randomize ion's position, ke, and direction
		1 sto Rerun_Flym				; force rerun on
										; turns traj file saving off
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

		;--------- randomize ion's position components --------
		rcl Random_Offset_mm
		2 / sto half_pos				; save half max shift

		rcl ion_px_mm					; get nominal x start
		rcl Random_Offset_mm rand * +	; add random shift
		rcl half_pos -					; subtract half shift
		sto ion_px_mm					; store random x start

		rcl ion_py_mm					; get nominal y start
		rcl Random_Offset_mm rand * +	; add random shift
		rcl half_pos -					; subtract half shift
		sto ion_py_mm					; store random y start

		rcl ion_pz_mm					; get nominal z start
		rcl Random_Offset_mm rand * +	; add random shift
		rcl half_pos -					; subtract half shift
		sto ion_pz_mm					; store random z start

		;--------- randomize ion's time of birth --------
		rcl Random_TOB abs rand *		; create random time of birth
		sto Ion_Time_of_Birth			; use it for ion
		;---------------------- done -----------------------------------------



;------------------------------------------------------------------------
seg Fast_Adjust 					; generates trap rf with fast adjust
									; has first pass initialization
	rcl first x=0 gsb init			; init on first try

	rcl scaled_rf
	rcl _AMU_Mass_per_Charge *		; multiply by mass per unit charge
	rcl _Qz_tune *					; rf tuning point
	sto rfvolts 					; save rf voltage

	rcl scaled_rf
	rcl _AMU_Mass_per_Charge *		; multiply by mass per unit charge
	rcl _Az_tune *					; substitute dc tune point
	2 / chs 						; additional dc factor
	sto dcvolts 					; save dc voltage

	rcl _Tickle_Frequency			; get tickle frequency
	6.28318E-6 *					; to radians / microsecond
	rcl Ion_Time_of_Flight *		; current tof in micro seconds
	sin 							; sin(theta + (omgga * tof))
	rcl _Tickle_Voltage *
	sto tickle
	sto Adj_Elect02 				; left end cap
	chs
;	 rcl _Right_End_Cap_DC
	sto Adj_Elect03 				; set right endcap voltage

	rcl Ion_Time_of_Flight			; current tof in micro seconds
	rcl omega * 					; omega * tof
	rcl theta + 					; add phasing angle
	sin 							; sin(theta + (omgga * tof))
	rcl rfvolts *					; times rf voltage
	rcl dcvolts +					; add dc voltage
	chs 2 * sto Adj_Elect01 		; electrode 2 voltage - ring electrode
	exit							; exit program segment


lbl init							; parameter initialization subroutine

	1 sto first 					; turn off first pass flag

	RCL Effective_Radius_in_cm		; recall effective radius in cm
	entr *							; (r * r)
	rcl Freqency_Hz entr * *		; multiply by frequency squared
	5.1145633E-12 * chs 			; -5.1145633E-12 * Qz * MASS * FREQ * FREQ * R0 * R0
	sto scaled_rf

	rcl _AMU_Mass_per_Charge		; multiply mass per unit charge
	rcl _Qz_tune *					; by rf tuning point
	rcl _Parent_Mass /				; divide by parent ion mass
	sto _qz_next					; to get qz point of parent ion
	enter * 2 / sqrt				; estimate B = sqrt(qz * qz / 2)
	sto _beta_guess 				; save initial B estimate for first guess
	rcl Freqency_Hz * 2 /			; use for initial guess at tickle frequency
	sto _Tickle_Frequency

	rcl Phaze_Angle_Deg
	>rad							; degrees to radians
	sto theta						; phase angle

	rcl Freqency_Hz 				; rf frequancy in hz
	6.283185E-6 *					; to radians / microsecond
	sto omega						; save frequency in radians / usec

	20								; estimate B with 20 terms
	rcl _qz_next					; qz to use for parent
	rcl _beta_guess 				; initial guess at B

lbl loop_again						; B iteration loop entry point
	sto beta_test					; keep copy of current B guess
	gsb beta						; get next guess at B
	sto _beta_next					; save next B estimate
									; exit loop if closely converged
	rcl beta_test - abs 0.00000001 x>y goto gotit
									; us average for estimate of next B guess
	rcl _beta_next rcl beta_test + 2 /
	sto _beta_next					; save next B estimate

	20								; estimate B with 20 terms
	rcl _qz_next					; qz to use for parent
	rcl _beta_next					; next guess at B
	goto loop_again 				; loop back for next iteration

 lbl gotit							; convergence limit for B reached
	rcl _beta_next					; get best estimate for B
	rcl Freqency_Hz * 2 /			; use it to compute the tickle frequency
	sto _Tickle_Frequency

	rtn 							; return from subroutine

subroutine beta 					; gets next estimate for B
	sto betaz						; save trial B value
	rlup sto qz 					; save qz
	rlup sto n sto nlevels			; save number of terms to use
	0 sto terma sto termb			; initialize starting terms
	rcl qz entr * sto qz2			; compute and save qz squared

lbl loop							; B estimate loop

	rcl n x<=0 goto endloop 		; exit if terms complete

	rcl n 2 * rcl betaz + entr *	; (2 * n + B) squared
	rcl terma - 					; minus current terma
	rcl qz2 x<>y /					; qz * qz /((2n + B) * (2n + B) - terma)
	sto terma						; store as new terma

	rcl betaz rcl n 2 * - entr *	; (B - 2 * n) squared
	rcl termb - 					; minus current termb
	rcl qz2 x<>y /					; qz * qz /((B - 2n) * (B - 2n) - termb)
	sto termb						; store as new termb

	rcl n 1 - sto n 				; n = n - 1
	goto loop						; loop back for next level

lbl endloop 						; term estimates are complete

	rcl terma
	rcl termb
	+ sqrt
	sto betaz						; B new estimate = sqrt(terma + termb)
	rcl nlevels 					; restore calling stack
	rcl qz
	rcl betaz

	rtn 							; return to caller



;----------------------------------------------------------
seg tstep_adjust					; keep time step <= _Max_Tstep_usec
	rcl ion_time_step rcl _Max_Tstep_usec
	x>y exit
	sto ion_time_step
	exit




;------------------------------------------------------------------------
seg Other_Actions					; used to control pe surface updates

	rcl fragmented x!=0 goto rest	; skip if already fragmented
	rcl total_ke_absorbed			; recall total ke already absorbed
									; skip if not >= to fragmetation energy
	rcl _Fragment_energy_eV x>y goto rest

	1 sto fragmented				; mark ion as fragmented
	rcl _daughter_mass sto Ion_mass ; change ion's mass
									; save time of fragmentation
	rcl ion_time_of_flight sto time_of_fragmentation
									; inform user
	message ; Ion Fragmented: at # usec to # amu
	mark							; mark location of fragmentation


lbl rest

	rcl total_ke_absorbed			; recall total key absorbed
	rcl ion_number					; recall ion number
									; if ion hit wall inform user
	rcl ion_splat x!=0 message ; Splat # for ion #, total ke absorbed = # eV

	rcl ion_vz_mm					; mean free path cooling
	rcl ion_vy_mm					; load velocity components
	rcl ion_vx_mm
	>p3d							; convert velocity to polar coords
		 sto v						; save in temporary variables
	rlup sto az
	rlup sto el

	rcl v rcl ion_time_step *		; compute distance from tstep * v
	rcl _mean_free_path x<=0 goto skip1 / chs e^x
	1 x<>y -						;(1-e(-d/fp))
	rand							;get random number from 0 - 1
	x>y goto skip1					; no collision
									; collision assume variable position hit on resting gas molecule
	1 rand x>=y goto skip1			; no collision if r >= 1.0
	abs x>0 sqrt					; equal area r value
	asin							; collision angle in radians
	sto impact_angle_rad			; save in local variable

									; collision assume direct hit on resting gas molecule
	rcl ion_mass rcl _collision_gas_mass -
	rcl ion_mass rcl _collision_gas_mass + /	; (m - mc)/(m + mc)
	x=0 0.000001								; protect against identical mass blowup
	rcl v * rcl impact_angle_rad cos * sto vr	; attenuated radial velocity
	rcl v rcl impact_angle_rad sin * sto vt 	; attenuated tangential velocity
												; compute resulting velocity
	rcl vr rcl vr * rcl vt rcl vt * + sqrt sto vnew

	rcl impact_angle_rad rcl vt rcl vr / atan -
	>deg							; elevation off vertical
	90 +							; elevation off vertical

	360 rand *						; azimuth angle
	rcl vnew						; velocity
	>r3d							; compute rect assuming vertical is on original line

	-90 >elr						; el rotate back from 90 vertical

	rcl el >elr 					;el rotate to initial el
	rcl az >azr 					;az rotate to initial az

		 sto ion_vx_mm				;store back into user variables
	rlup sto ion_vy_mm
	rlup sto ion_vz_mm

	rcl ion_mass					;get ion's mass
	rcl vnew						;get new velocity
	>KE 							;ion's new KE
	sto new_ke						; save new ke
	rcl ion_mass
	rcl v
	>KE 							;compute previous ke
	rcl new_ke -					;find change in ke
	rcl _Ratio_absorbed *			;times ratio of ke absorbed
	rcl total_ke_absorbed + 		;add to total ke absorbed
	sto total_ke_absorbed			;save result
	rcl ion_number
;	message ; ion #, total ke absorbed = #

									; don't change colors of non-tuned mass
	rcl ion_mass rcl _AMU_Mass_per_Charge x!=y exit
	rcl Ion_color 3 x=y 2 sto Ion_color
	exit

lbl skip1							; don't change colors of non-tuned mass
	rcl ion_mass rcl _Parent_Mass x!=y goto next
	rcl tickle
	x=0 goto next					; if tickle is off skip
	x<0 goto red
	3 sto Ion_color 				; ion is blue if tickle voltage is positive
	goto next
 lbl red
	1 sto ion_color 				; ion is red if tickle voltage is negative

 lbl next
	rcl fragmented x=0 goto skip
	rcl _Time_to_trap_usec			; get time to assumed capture
	rcl Ion_Time_of_Flight			; get ion's time of flight
	rcl time_of_fragmentation - 	; time since fragmentation
	x<=y goto skip					; don't kill if not captured

	-4 sto Ion_Splat				; kill ion
	rcl Ions_trapped 1 +			; up ion trapped count
	sto ions_trapped				; save for future reference
	rcl Ion_number
									; inform user of capture statistics
	message ; # Ions Fragmented:  # Ions Trapped

  lbl skip
	rcl Next_PE_Update				; recall time for next pe surface update
	rcl ion_time_of_flight			; recall ion's time of flight
	x<y exit						; exit if tof less than next pe update
	rcl PE_Update_each_usec 		; recall pe update increment
	+ sto next_pe_update			; add to tof and store as next pe update
	1 sto Update_PE_Surface 		; request a pe surface update

	exit



;------------------------------------------------------------------------
seg Terminate
			0 sto rerun_flym		; turn off rerun mode
