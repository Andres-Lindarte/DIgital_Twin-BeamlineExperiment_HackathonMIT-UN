adefa first 1		 ;array flag first call to other actions in fly'm
adefa last	1		 ;array flag first call to terminate in fly'm

adefa vx1	10		 ;initial velocity arrays
adefa vy1	10

seg initialize
rcl ion_vx_mm
rcl ion_number
asto vx1
rcl ion_vy_mm
rcl ion_number
asto vy1


seg other_actions
					;skip if not first call in fly'm
1 arcl first x!=0 goto next
1 1 asto first		;flag as having been called
					;display banner lines
message ; Cross Accel of Relativistic Electrons
message ; Initial velocity in y
message ; initial ke in y varies 1-7 rest masses
message ; Cross Accelerated in x by 1 rest mass
message ;

lbl next			;continue
					;exit if electron hasn't splatted
rcl ion_splat x=0 exit
					;jump if not ion number one
2 rcl ion_number x>=y goto test2
message ; Electron 1 (vy = 1 rest mass)
2 sto n 			;total rest mass ke at splat
goto resume 		;return to summary

lbl test2
x>y goto test3		;jump if ion number 3
message ; Electron 2 (vy = 3 rest masses)
4 sto n 			;total rest mass ke at splat
goto resume 		;return to summary

lbl test3
message ; Electron 3 (vy = 7 rest masses)
8 sto n 			;total rest mass ke at splat

lbl resume			;entry for rest of output

rcl ion_vy_mm
rcl ion_vy_mm * 	;vy squared at splat
rcl ion_vx_mm
rcl ion_vx_mm * 	;vx squared at splat
+ sqrt				;compute vt
sto speed			;save as temp variable speed
rcl ion_mass		;get rest mass of ion (electron)
x<>y				;swap x and y registers
>ke 				;convert speed to ke
sto ke				;save ke

rcl n 5.1099906e5 * ;compute/display expected ke using n
message ;  ke = # eV	  (Expected)
rcl ke				;display ke obtained by SIMION
message ;  ke = # eV	  (SIMION)

rcl n 1 + sto n 	;add electron's rest mass to ke
rcl n rcl n * sto n ;square result save in n
					;n = 1/sqrt(1 - (v^2)/(c^2))
					;v = c * sqrt((n^2 -1)/(n^2))
rcl n 1 - rcl n / sqrt 2.997924580e5 *
					;display expected speed
message ;  vt = # mm/usec (Expected)
rcl speed			;display speed at splat
message ;  vt = # mm/usec (SIMION)
rcl ion_number
arcl vy1			 ;display vx and vy components
rcl ion_number
arcl vx1
message ;  Init. vx = # mm/usec, vy = # mm/usec
rcl ion_vy_mm		;display vx and vy components
rcl ion_vx_mm
message ;  Splat vx = # mm/usec, vy = # mm/usec
message ;


seg terminate
1 arcl last x!=0 exit  ;skip if already called
1 1 asto last		   ;flag to skip
					   ;include exit message
message ;		NOTE: vx and vy at splat doesn't remain constant
message ;		With Relativity:  The Rules Have Changed!
