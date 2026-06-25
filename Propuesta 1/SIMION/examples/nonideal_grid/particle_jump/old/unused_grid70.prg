; Simulation of grid lensing using instance hopping
; By Steven M. Colby
; Scientific Instrument Services, Inc.
; Copyright 1996-2008 all rights reserved.
; This program is available as part of application note #52 at www.sisweb.com
 
; This text may be copied and redistributed under the following conditions:
;  1. This notice is not removed or changed.
;  2. A reference is made to the web site www.sisweb.com in any publication of results using this code.
;

;Program for grid instance in grid hopping simulation
 
Define_Adjustable grid_inst_x 135   ;size of grid instance in x dim 135
Define_Adjustable grid_inst_y 135   ;size of grid instance in x dim 135
Define_Adjustable grid_inst_z 271   ;size of grid instance in x dim 271
Define_Adjustable scaling  0.004    ;mm/grid unit    0.004 for full size
Define_static     jumpped  0        ;boolean
Define_Static     Fields_adjusted 0 ;boolean
Define_Static     old_grad_x 0      ;storage for voltage gradient x
Define_Static     old_grad_y 0      ;storage for voltage gradient y
Define_Static     old_grad_z 0      ;storage for voltage gradient z
Define_static     New_gradient 0    ;new x gradient

Define_static var1 0 
Define_static var2 0
Seg Other_actions
    rcl Ion_DvoltsZ_mm
    mess ;field = # V/mm
    rcl var2
    rcl var1
    mess ;temp = #, result = #
Seg Fast_adjust
    RCL fields_adjusted
    X>0 Exit              ;if adjusted leave
     
   ;Set electrode potentials given fields

    RCL grid_inst_z 2 /              ;half the x grid units of the instance
    RCL Ion_mm_Per_Grid_Unit *       ;times mm/gu of grid instance gives distance    
    Duplicate_X                      ;make an extra copy of this variable
    STO temp                         ;store a temporary copy
    RCL old_grad_z *
    STO Adj_Elect01                  ;set new electrode potential
 ;   rcl adj_elect01
 ;   sto var1
 RCL temp                         ;Get temp back
 sto var1
 RCL New_gradient *        ;new field (x) is in New_gradient (V/mm)result is Volts
 sto var2
    RCL temp                         ;Get temp back
    RCL New_gradient *        ;new field (x) is in New_gradient (V/mm)result is Volts
    STO Adj_Elect02                  ;set new electrode potential
 ;   rcl adj_elect02
  ;  sto var2
    1 STO fields_adjusted            ;adjusted=true
    exit                             ;done
     
    ;end of program
