;   SIMION 6.0 equivalent of a SIMION 4.0 .AR? user program
;   D.A. DAHL 1994
 
;   area.pa has two parallel plate electrodes
;   one set to 100 volts and the other set to -100 volts
;   voltages in the potential array are totally ignored!!!
;   this efield_adjust seg defines an explicit rf field between the plates
 
 
 
                        ; define adjustable variables
defa Omega 1.0          ; anuglar velocity in radians/micro second
defa RF_Voltage 100.0   ; rf voltage
 
 
SEG Efield_Adjust       ; start of efield_adjust program segment
 
; ******************* first we calculate the potential of the left electrode
RCL Ion_Time_of_Flight  ; recall the current time-of-flight in micro seconds
RCL Omega               ; recall the anuglar velocity
*                       ; multiply
SIN                     ; take sine of result
RCL RF_Voltage *        ; multiply by rf_voltage
STO V_left              ; V_left = rf_voltage * sin (omega * tof)
 
 
 
; ************* next we calculate the electrostatic field (-) in the x direction
-21.5                   ; distance from edge of left electrode to center
/                       ; divide to get slopt (-electrostatic field)
STO dV_dx               ; store as temp variable dV_dx
STO Ion_DvoltsX_gu      ; Ion_DvoltsX_gu = rf_voltage * sin (omega * tof) /(-21.5)
0
STO ion_DVOLTSy_gu      ; store zero for other e fields
STO ion_DVOLTSz_gu
 
 
 
; ************* then we calculate the potential at the current ion location
22.5
RCL Ion_Px_gu           ; get current ion position in PA volume coords
-                       ; (22.5 - X)
RCL dV_dx               ; recall horizontal voltabe gradient
*                       ; multiply
RCL V_left              ; recall potential at left electrode
+                       ; add
STO Ion_Volts           ; Ion_Volts = V_left + dV/dx * (22.5 - X)
