;creates magnetic field
;D.A.Dahl

; this user program takes user input (magnetic field strength) and
; sets the simion variable (Ion_BfieldX_gu) equal to the user input value
; user program ties to mag.pa (dummy magnetic potential array)

; ---------------- adjustable variables ------------------------

defa _Bx_Gauss 0			  ; magnetic field in gauss

seg Mfield_Adjust				; magnetic field adjust prog seg

		rcl _Bx_Gauss			 ; recall value for magnetic field
		sto Ion_BfieldX_gu		; store to simion variable Ion_BfieldX_gu
		0						; use zero for remaining magn field components
		sto Ion_BfieldY_gu		; store to simion variable Ion_BfieldY_gu
		sto Ion_BfieldZ_gu		; store to simion variable Ion_BfieldZ_gu



