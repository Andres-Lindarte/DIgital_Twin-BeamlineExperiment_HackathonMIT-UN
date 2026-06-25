;   SIMION 6.0 equivalent of a SIMION 4.0 .FAC user program
;   D.A. DAHL 1994
 
;   factor.pa has two parallel plate electrodes
;   one set to 100 volts and the other set to -100 volts
;   this efield_adjust program modulates the field
 
                        ; define an adjustable variable
DEFA Omega 1.0          ; angular velocity in radians/micro second
 
 
 
SEG Efield_Adjust       ; start of efield_adjust program segment
 
RCL Ion_time_of_Flight  ; recall the current time-of-flight in micro seconds
RCL Omega               ; recall the anuglar velocity
*                       ; multiply
SIN                     ; take sine of result
STO factor              ; factor = sin(omega * tof)- temporary variable
 
RCL Ion_Volts           ; recall reserved variable ion_volts
RCL factor *            ; multiply it times factor
STO Ion_Volts           ; store result in ion_volts
 
RCL Ion_DvoltsX_gu      ; recall reserved variable dvoltsx_gu
RCL factor *            ; multiply it times factor
STO ion_DvoltsX_gu      ; store result in dvoltsx_gu
 
RCL Ion_DvoltsY_gu      ; recall reserved variable dvoltsy_gu
RCL factor *            ; multiply it times factor
STO ion_DvoltsY_gu      ; store result in dvoltsy_gu
 
RCL Ion_DvoltsZ_gu      ; recall reserved variable dvoltsz_gu
RCL factor *            ; multiply it times factor
STO ion_DvoltsZ_gu      ; store result in dvoltsz_gu
 
