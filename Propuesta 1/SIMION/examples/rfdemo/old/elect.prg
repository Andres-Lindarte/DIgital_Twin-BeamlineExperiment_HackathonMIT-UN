;   SIMION 6.0 equivalent of a SIMION 4.0 .ELE user program
;   D.A. DAHL 1994
 
;   elect.pa0 has two parallel plate electrodes
;   this fast_adjust seg creates a simple rf field between the plates
;   using dynamic fast adjust
 
                                ; define adjustable variables
defa Omega 1.0                  ; anuglar velocity in radians/micro second
defa RF_Voltage 100.0           ; rf voltage
defa Update_PE_every_usec  0.3  ; update pe surface every 0.3 usec
 
defs next_pe_update 0           ; next pe update time of flight
 
 
SEG Fast_Adjust         ; start of fast_adjust program segment
 
RCL Ion_Time_of_Flight  ; recall the current time-of-flight in micro seconds 
RCL Omega               ; recall the anuglar velocity                        
*                       ; multiply                                           
SIN                     ; take sine of result                                
RCL RF_Voltage *        ; multiply by rf_voltage                             
STO Adj_Elect01         ; Adj_elect01 = rf_voltage * SIN(OMEGA * tof)        
CHS                     ; change sign of value                               
STO Adj_Elect02         ; Adj_elect02 = rf_voltage * SIN(OMEGA * tof)        
                        ; adj_elect01 and adj_elect02 uset to set adjustable 
                        ; electrode voltages                                 
                         
SEG Other_Actions       ; used to control pe surface updates
 
rcl next_pe_update      ; get next time for pe surface update
rcl ion_time_of_flight  ; get time of flight
x<y exit                ; if tof less than time then exit
rcl Update_PE_every_usec
+ sto next_pe_update    ; set next time for pe surface update
1 sto Update_PE_Surface ; flag a pe surface update
