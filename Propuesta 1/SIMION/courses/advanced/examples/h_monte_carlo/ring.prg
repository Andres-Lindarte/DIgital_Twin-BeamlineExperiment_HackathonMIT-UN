; Monte Carlo simulation of self-charge stabilization
; David A. Dahl


; definition of user adjustable variables  -----------------------

defa Single_Run_if_one 0	 ; turn off monte carlo convergence

defa _Bx_Gauss 0			 ; magnetic field in gauss
defa _Primary_Beam_Charging 0 ; charging by primary beam
defa left_voltage  -10		 ; voltage on left electrode
defa right_voltage	10		 ; voltage on right electrode


defa _Convergence_Objective 2 ; minimum offset to declare convergence

defa step_limit 1000		 ; step limit for electrons (stops circular lockups)

defa target_voltage  0		 ; starting target voltage to use

defa use_defined_max_min_if_one 0
defa starting_max_voltage 100
defa starting_min_voltage -100

defa max_voltage 100
defa min_voltage -100

defa use_special_pos_if_one 0		  ; homogeneous surface emission if 1


defa _Cone_Angle_Off_Vel_Axis	89.0   ; (+- 180 deg) cone angle - sphere
defa _Random_Offset_mm			 6.0   ; del start position (x,y,z) in mm



; definition of static variables -----------------------------

defa n_extracted 0					;number of extracted ions
defa net_charge 0					;net charge on the sample
defa p_count 0						;number of positive ions emitted from sample
defa n_count 0						;number of negative ions emitted from sample
defa e_count 0						;number of electrons emitted from sample
defa p_charge 0 					;number of positive ions returned to sample
defa n_charge 0 					;number of positive ions returned to sample
defa e_charge 0 					;number of electrons returned to sample

defa first_flym  0					;first flym flag
defa first_ion	0					;first ion flag
defa finished	0					;finished flag

defa ke_m_025 0 				   ;
defa ke_m_05  0
defa ke_m_1   0
defa ke_m_2   0
defa ke_m_4   0
defa ke_m_8   0
defa ke_m_16  0
defa ke_m_32  0
defa ke_m_big 0

defa ke_e_025 0
defa ke_e_05  0
defa ke_e_1   0
defa ke_e_2   0
defa ke_e_4   0
defa ke_e_8   0
defa ke_e_16  0
defa ke_e_32  0
defa ke_e_big 0

defs time_steps 0			; time steps for killing electrons in mag fields

; program segments below --------------------------------------------


;------------------------------------------------------------------------
seg initialize		; randomize ion's position, ke, and direction
		0 sto Rerun_Flym				; force rerun off

		1 rcl ion_number x!=y goto skip ; skip if not first ion
										; reset all counters on first ion
		rcl _Primary_Beam_Charging		 ; get primary beam charge
		sto net_charge					; store as initial value of net_charge

		0 sto p_charge					; zero positive return charge
		sto n_extracted 				; zero ions extracted
		sto n_charge					; zero negative ions returned
		sto e_charge					; zero electrons returned
		sto first_ion					; zero first ion flag
		sto finished					; zero finished flag
										; zero ion energy bins
		sto ke_m_025					; <= 0.25eV
		sto ke_m_05
		sto ke_m_1
		sto ke_m_2
		sto ke_m_4
		sto ke_m_8
		sto ke_m_16
		sto ke_m_32
		sto ke_m_big					; > 32.0 eV
										;zero electron energy bins
		sto ke_e_025					; <= 0.25eV
		sto ke_e_05
		sto ke_e_1
		sto ke_e_2
		sto ke_e_4
		sto ke_e_8
		sto ke_e_16
		sto ke_e_32
		sto ke_e_big					; > 32.0 eV

   lbl	skip
		rcl first_flym x!=0 goto skip1	;skip if not first flym iteration
		1 rcl ion_number x!=y goto resume1 ; skip if not first ion

										;initialize voltages if not special
		rcl use_defined_max_min_if_one x!=0 goto defined_starts
		rcl left_voltage
		sto max_voltage
		rcl right_voltage
		sto min_voltage
		goto resume

lbl  defined_starts 					;if special use defined starting v
		rcl starting_max_voltage
		sto max_voltage
		rcl starting_min_voltage
		sto min_voltage

lbl   resume
		rcl max_voltage
		rcl min_voltage
		+ 2 / sto target				;assume target starts midway between
		rcl target
		sto target_voltage

lbl   resume1
		1 rcl ion_mass x<y goto count_electrons ;if mass less than 1 electron
		rcl ion_charge x<0 goto count_neg_ions	;neg ion if neg charge

		rcl p_count 1 + sto p_count 			;inc pos ion count
		goto skip1

   lbl	count_neg_ions
		rcl n_count 1 + sto n_count 			;inc neg ion count
		goto skip1

   lbl	count_electrons
		rcl e_count 1 + sto e_count 			;inc electron count


   lbl	skip1							; entry point for all flyms
		rcl net_charge
		rcl ion_charge -				; subtract charge of each emitted ion
										; or electron
		sto net_charge
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


		;------------------- make sure _Cone_Angle_Off_Vel_Axis is legal -------------
								; force 0 <= _Cone_Angle_Off_Vel_Axis <= 180
		rcl _Cone_Angle_Off_Vel_Axis abs
		180 x>y rlup sto _Cone_Angle_Off_Vel_Axis

		; ---------------------- compute random ke -----------
		1 rcl ion_mass					  ; recall ion mass
		x<y goto electron_energies		  ;electron energy calculation

		;molecular energies
		rand sto x									;get random number x (0-1)
		0.0112										; +0.0112
		2.9558 rcl x * -							; -2.9558x
		71.686 rcl x	  rcl x * sto xpower * +	; +71.686x^2
		358.17 rcl xpower rcl x * sto xpower * -	; -358.17x^3
		819.18 rcl xpower rcl x * sto xpower * +	; +819.18x^4
		866.99 rcl xpower rcl x * sto xpower * -	; -866.99x^5
		347.22 rcl xpower rcl x * sto xpower * +	; +347.22x^6
		abs

		sto ke .25 x<y goto next25		 ; skip if > 0.25 eV
		rcl ke_m_025 1 + sto ke_m_025	 ;inc under 0.25 eV bin
		rcl ke
		goto ke_computed

		lbl next25
		rcl ke .5 x<y goto next50		 ; skip if > 0.50 eV
		rcl ke_m_05 1 + sto ke_m_05 	 ;inc under 0.50 eV bin
		rcl ke
		goto ke_computed

		lbl next50
		rcl ke 1 x<y goto next1 		 ; skip if > 1.0 eV
		rcl ke_m_1 1 + sto ke_m_1		 ;inc under 1.0 eV bin
		rcl ke
		goto ke_computed

		lbl next1
		rcl ke 2 x<y goto next2 		; skip if > 2.0 eV
		rcl ke_m_2 1 + sto ke_m_2		;inc under	2.0 eV bin
		rcl ke
		goto ke_computed

		lbl next2
		rcl ke 4 x<y goto next4 		; skip if > 4.0 eV
		rcl ke_m_4 1 + sto ke_m_4		;inc under	4.0 eV bin
		rcl ke
		goto ke_computed

		lbl next4
		rcl ke 8 x<y goto next8 		; skip if > 8.0 eV
		rcl ke_m_8 1 + sto ke_m_8		;inc under	8.0 eV bin
		rcl ke
		goto ke_computed

		lbl next8
		rcl ke 16 x<y goto next16		; skip if > 16.0 eV
		rcl ke_m_16 1 + sto ke_m_16 	;inc under	16.0 eV bin
		rcl ke
		goto ke_computed

		lbl next16
		rcl ke 32 x<y goto next32		; skip if > 32.0 eV
		rcl ke_m_32 1 + sto ke_m_32 	;inc under	32.0 eV bin
		rcl ke
		goto ke_computed

		lbl next32
		rcl ke_m_big 1 + sto ke_m_big	;inc over  32.0 eV bin
		rcl ke
		goto ke_computed


lbl 	electron_energies
		rand sto x									;get random number x (0-1)
		0.2641										; +0.2641
		0.1352 rcl x * -							; -0.1352x
		209.98 rcl x	  rcl x * sto xpower * +	; +209.98x^2
		1202.5 rcl xpower rcl x * sto xpower * -	; -1202.5x^3
		2777.3 rcl xpower rcl x * sto xpower * +	; +2777.3x^4
		2826.6 rcl xpower rcl x * sto xpower * -	; -2826.6x^5
		1063.4 rcl xpower rcl x * sto xpower * +	; +1063.4x^6
		abs

		sto ke .25 x<y goto nexte25 	; skip if > 0.25 eV
		rcl ke_e_025 1 + sto ke_e_025	;inc under 0.25 eV bin
		rcl ke
		goto ke_computed

		lbl nexte25
		rcl ke .5 x<y goto nexte50		; skip if > 0.50 eV
		rcl ke_e_05 1 + sto ke_e_05 	;inc under 0.50 eV bin
		rcl ke
		goto ke_computed

		lbl nexte50
		rcl ke 1 x<y goto nexte1		; skip if > 1.0 eV
		rcl ke_e_1 1 + sto ke_e_1		;inc under 1.0 eV bin
		rcl ke
		goto ke_computed

		lbl nexte1
		rcl ke 2 x<y goto nexte2	   ; skip if > 2.0 eV
		rcl ke_e_2 1 + sto ke_e_2	   ;inc under  2.0 eV bin
		rcl ke
		goto ke_computed

		lbl nexte2
		rcl ke 4 x<y goto nexte4	   ; skip if > 4.0 eV
		rcl ke_e_4 1 + sto ke_e_4	   ;inc under  4.0 eV bin
		rcl ke
		goto ke_computed

		lbl nexte4
		rcl ke 8 x<y goto nexte8	   ; skip if > 8.0 eV
		rcl ke_e_8 1 + sto ke_e_8	   ;inc under  8.0 eV bin
		rcl ke
		goto ke_computed

		lbl nexte8
		rcl ke 16 x<y goto nexte16	   ; skip if > 16.0 eV
		rcl ke_e_16 1 + sto ke_e_16    ;inc under  16.0 eV bin
		rcl ke
		goto ke_computed

		lbl nexte16
		rcl ke 32 x<y goto nexte32	   ; skip if > 32.0 eV
		rcl ke_e_32 1 + sto ke_e_32    ;inc under  32.0 eV bin
		rcl ke
		goto ke_computed

		lbl nexte32
		rcl ke_e_big 1 + sto ke_e_big  ;inc ever  32.0 eV bin
		rcl ke

lbl 	ke_computed 				   ;ke has been computed entry point

		; ---------------------- convert new ke to new speed -----------
		rcl ion_mass					; recall ion mass
;		 message ;#amu, #eV 			; debug testing message
		x><y							; swap x any y
		>spd							; convert to speed
		sto speed						; save new speed

		;-- compute randomized el angle change 90 +- _Cone_Angle_Off_Vel_Axis -------
		;-------- we assume elevation of 90 degrees for mean ----------
		;-------- so cone can be generated via rotating az +- 90 -------
									; (2 * _Cone_Angle_Off_Vel_Axis * rand)
		2 rcl _Cone_Angle_Off_Vel_Axis * rand *
									;  - _Cone_Angle_Off_Vel_Axis + 90
		rcl _Cone_Angle_Off_Vel_Axis - 90 +

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

		rcl use_special_pos_if_one x!=0 goto special_positioning

		rcl _Random_Offset_mm
		2 / rand * sto r				; save radial offset
		rand 360 * >rad sto angle		; save offset angle

		rcl ion_py_mm					; get nominal y start
		rcl r rcl angle sin * +
		sto ion_py_mm					; store random y start

		rcl ion_pz_mm					; get nominal z start
		rcl r rcl angle cos * +
		sto ion_pz_mm					; store random z start
		exit

   lbl special_positioning				; equal area density emission
		click_sound
   lbl	try_again
		rcl _Random_Offset_mm 2 / sto max_r
		rcl _Random_Offset_mm rand *
		rcl max_r - sto y				; save y
		rcl _Random_Offset_mm rand *
		rcl max_r - sto z				; save z

		rcl y entr * rcl z entr * + sqrt
		rcl max_r x<y goto try_again

		rcl ion_py_mm					; get nominal y start
		rcl y +
		sto ion_py_mm					; store random y start

		rcl ion_pz_mm					; get nominal z start
		rcl z +
		sto ion_pz_mm					; store random z start
		exit
		;---------------------- done -----------------------------------------



 seg init_p_values		 ; fast voltage preset segment
;seg fast_adjust		 ; fast voltage adjust segment

	rcl left_voltage
	sto adj_elect01 	; store left_voltage in electrode 1

	rcl right_voltage
	sto adj_elect03 	; store right_voltage in electrode 3

	rcl Single_Run_if_one x!=0 goto single_run
	rcl max_voltage 	; compute target's voltage
	rcl min_voltage
	+ 2 /
	sto target_voltage	;sto target's voltage
	sto adj_elect02 	;sto in electrode 3
	exit

lbl single_run			;if single run
	rcl target_voltage	;use defined target voltage in electrode 2
	sto adj_elect02
	exit



;------------------------------------------------------------------------
seg Other_Actions					; used to control pe surface updates
	rcl first_ion x!=0 goto skip	; skip if not first ion
	1 sto first_flym				; clear first flym flag
	1 sto first_ion 				; clear first ion flag
	1 sto update_pe_surface 		; set update surface flag

lbl skip							; resume from flag clearing
									; skip if not electron
	1 rcl ion_mass	x>y goto splat_test
	rcl step_limit					; get electron step limit
	rcl time_steps 1 + sto time_steps	; inc time steps
	x<y goto splat_test 				; skip if below kill limit
	-4 sto ion_splat					; kill electron

lbl splat_test						; ion splat test
	rcl ion_splat x=0 exit			; exit if ion/electron is still alive

									; skip if ion/electron didn't hit extraction electrode
	rcl ion_px_mm 185 x>y goto return_test
	rcl ion_mass 1	x>y exit		; exit if electron
	rcl n_extracted 1 + sto n_extracted 	; inc extracted ion count
	exit

	lbl return_test 				;tests for returned ions and electrons
	1.0
	rcl ion_px_mm abs
	x>y exit						;exit if not within 1 mm in x of target's face

	rcl ion_py_mm entr *
	rcl ion_pz_mm entr * + sqrt
	6 x<y exit						;exit if beyond radius of target

	rcl ion_charge					;get ion/electron's charge
	rcl net_charge +				;apply it to target's charge
	sto net_charge					;save new net charge
	rcl ion_charge					;get particle's charge
	x<0 goto nskip					;skip if negative
	rcl p_charge + sto p_charge 	;store to total positive charge returned
	exit
lbl nskip
	1 rcl ion_mass x<y goto electron	; jump if electron
	rcl ion_charge
	rcl n_charge + sto n_charge 		; update total negative charge returned
	exit
lbl electron
	rcl ion_charge
	rcl e_charge + sto e_charge 		;update total electron charge returned
	exit



;------------------------------------------------------------------------
seg Terminate							;all ions are dead
	rcl finished x!=0 exit				;if finished flag cleared -- exit
	1 sto finished						;clear finished flag
	1 sto Retain_changed_potentials 	;keep the final PE surface potentials

										;display results of run
	rcl e_charge
	rcl n_charge
	rcl p_charge
	rcl net_charge
	rcl target_voltage
	message ;TVolts = #, t = #, p = #, n = #, e = #

	rcl Single_Run_if_one x!=0 exit 	; quit if single run

	1 sto rerun_flym					; turn on rerun mode
	rcl _Convergence_Objective abs		 ; test for convergence
	rcl net_charge x>y goto positive_charging	; too much positive charge

	rcl _Convergence_Objective abs chs
	rcl net_charge x<y goto negative_charging	; too much negative charge

	0 sto rerun_flym		; turn off rerun mode
	message ;
	message ;Finished		; converged

	rcl n_count rcl p_count + sto t_count
	message ;
	message ;Ion Energy Profile:

	rcl ke_m_025 rcl t_count / 100 *
	message ; #% below 0.25eV

	rcl ke_m_05 rcl t_count / 100 *
	message ; #% between 0.25eV and 0.5 eV

	rcl ke_m_1 rcl t_count / 100 *
	message ; #% between 0.5eV and 1 eV

	rcl ke_m_2 rcl t_count / 100 *
	message ; #% between 1eV and 2 eV

	rcl ke_m_4 rcl t_count / 100 *
	message ; #% between 2eV and 4 eV

	rcl ke_m_8 rcl t_count / 100 *
	message ; #% between 4eV and 8 eV

	rcl ke_m_16 rcl t_count / 100 *
	message ; #% between 8eV and 16 eV

	rcl ke_m_32 rcl t_count / 100 *
	message ; #% between 16eV and 32 eV

	rcl ke_m_big rcl t_count / 100 *
	message ; #% over 32 eV

	rcl e_count x=0 goto skipe		;skip if no electrons defined
	sto t_count
	message ;
	message ;Electron Energy Profile:

	rcl ke_e_025 rcl t_count / 100 *
	message ; #% below 0.25eV

	rcl ke_e_05 rcl t_count / 100 *
	message ; #% between 0.25eV and 0.5 eV

	rcl ke_e_1 rcl t_count / 100 *
	message ; #% between 0.5eV and 1 eV

	rcl ke_e_2 rcl t_count / 100 *
	message ; #% between 1eV and 2 eV

	rcl ke_e_4 rcl t_count / 100 *
	message ; #% between 2eV and 4 eV

	rcl ke_e_8 rcl t_count / 100 *
	message ; #% between 4eV and 8 eV

	rcl ke_e_16 rcl t_count / 100 *
	message ; #% between 8eV and 16 eV

	rcl ke_e_32 rcl t_count / 100 *
	message ; #% between 16eV and 32 eV

	rcl ke_e_big rcl t_count / 100 *
	message ; #% over 32 eV

	lbl skipe				;entry from electron spectrum skip

	message ;
	message ;Balance Data:

	rcl target_voltage
	rcl right_voltage
	rcl left_voltage
	message ;Left = #V, Right = #V, Target = #V

	rcl _Bx_gauss
	message ;Magnetic Field = # Gauss

	rcl _Primary_Beam_Charging
	message ;Charge From Primary beam = #

	rcl e_count
	rcl n_count
	rcl p_count
	message ;Emitted  p = #, n = #, e = #

	rcl e_charge
	rcl n_charge
	rcl p_charge
	message ;Returned p = #, n = #, e = #

	rcl n_extracted
	rcl net_charge
	message ;net_charge = #, n_extracted = #
	exit

lbl positive_charging			; positive over charging -- next iteration
	rcl max_voltage rcl min_voltage
	x>y goto positive_charging1 ; jump to reverse voltage compensation
	rcl target_voltage
	sto min_voltage 			; use target voltage for new min voltage
	exit

lbl positive_charging1			; reverse voltage compensation
	rcl target_voltage
	sto max_voltage 			; use target voltage for new max voltage
	exit

lbl negative_charging			; negative over charging -- next iteration
	rcl max_voltage rcl min_voltage
	x>y goto negative_charging1 ; jump to reverse voltage compensation
	rcl target_voltage
	sto max_voltage 			; use target voltage for new max voltage
	exit
lbl negative_charging1			; reverse voltage compensation
	rcl target_voltage
	sto min_voltage 			; use target voltage for new min voltage
	exit
