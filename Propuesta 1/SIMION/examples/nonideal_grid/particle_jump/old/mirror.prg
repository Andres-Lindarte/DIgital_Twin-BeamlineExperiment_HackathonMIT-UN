; Simulation of grid lensing using instance hopping
; By Steven M. Colby
; Scientific Instrument Services, Inc.
; Copyright 1996-2008 all rights reserved.
; This program is available as part of application note #xx at www.sisweb.com
 
; This text may be copied and redistributed under the following conditions:
;  1. This notice is not removed or changed.
;  2. A reference is made to the web site www.sisweb.com in any publication of results using this code.
;
 

Seg Define_Data
;Define_Adjustable grid_size 70     ;line per inch currently not used
Define_Adjustable seed_value 4      ;for random # generation change befor runs
Define_Adjustable threshold 0.60    ;60 percent
Define_Adjustable grid_inst_x 135   ;size of grid instance in x dim, 135 for full size
Define_Adjustable grid_inst_y 135   ;size of grid instance in x dim, 135 for full size
Define_Adjustable grid_inst_z 271   ;size of grid instance in x dim, 271 for full size
Define_Adjustable scaling  0.004    ;mm/grid unit, use 0.004 for full size instance
Define_static     jumpped  0        ;boolean
Define_Static     KE_adjusted 0     ;boolean
Define_Static     old_grad_x 0      ;storage for voltage gradient x
Define_Static     old_grad_y 0      ;storage for voltage gradient y
Define_Static     old_grad_z 0      ;storage for voltage gradient z
Define_Static     old_posit_x 0     ;storage for position x
Define_Static     old_posit_y 0     ;storage for position y
Define_Static     old_posit_z 0     ;storage for position z
Define_Static     old_TOF 0         ;storage for TOF
Define_static     Sign_changed 0    ;changed sign of x velocity?
Define_static     first_pass 1       ;don't do some things on 1st pass
Define_static     New_gradient 0    ;new x gradient
Define_static     Excess_Energy 0   ;extra energy from going thru grid

Define_Adjustable initialized 0     ;whether random number generator is
                                    ; initialized (1/0)

Seg Initialize
  ; seed random number generator.  Note: seeding can take fairly long, so
  ; ensure it is only done once.
  RCL initialized X!=0 Goto skip1
    1 STO initialized
    RCL seed_value
    seed
  LBL skip1
 
Seg Other_Actions
RCL jumpped
X=0 Goto not_jumpped 
      ;we have already jumpped 
      ;this means that we have passed through the grid instance
    0 STO jumpped     ;jumpped = false
    RCL old_TOF       ;get old TOF
    STO Ion_time_of_Flight ;restore TOF
    RCL old_posit_x  ;get old x
    STO Ion_Px_mm    ;restore old x
    RCL old_posit_y  ;get old y
    STO Ion_Py_mm    ;restore old y
    RCL old_posit_z  ;get old z
    STO Ion_Pz_mm    ;restore old z  - now jumpped back
    
    RCL Ion_Mass             ;adjust for extra energy
    RCL Ion_Vz_mm            ;get current velocity
    Speed_to_Kinetic_Energy  ;calc current energy
    RCL Excess_Energy -      ;subtract energy
    Kinetic_Energy_to_Speed  ;we now have correct speed
    STO Ion_Vz_mm    
    
    1 STO first_pass ;don't want to jump again on the first pass back
    RCL Sign_changed ;check to see if we changed sign of velocity
    X=0 Exit         ;if not we can leave
    RCL Ion_Vz_mm
    Change_sign
    STO Ion_Vz_mm
    0 STO Sign_changed ;restore flag
    exit ;leave Seg
 
Label not_jumpped  ;we have not jumpped
    RCL first_pass ;is this our first pass? 
    X>0 goto first_time
    ;look for a change in voltage gradiant
    0.0001 ;Store a small # in X. differences of less
           ;than this will be ignored.
    RCL old_grad_z         ;z part
    RCL Ion_DvoltsZ_mm -
    ABS             ;we now have absolute value of difference
;    mess ;first comparison # and #
    X<Y Goto First_time ;if difference is too small to be
                        ;meaningful skip to next section
    RCL Ion_DvoltsZ_mm    
    RCL threshold *       
    ABS
    X<Y Goto Jumpping  ;change was greater than threshold fraction
;    RCL old_grad_y         ;y part
;    RCL Ion_DvoltsY_mm -
;    ABS             ;we now have absolute value of difference
;    RCL Ion_DvoltsY_mm
;    RCL threshold *
;    ABS             ; 
;    X<Y Goto Jumpping  ;change was greater than threshold fraction
;    RCL old_grad_x         ;x part
;    RCL Ion_DvoltsX_mm -
;    ABS             ;we now have absolute value of difference
;    RCL Ion_DvoltsX_mm
;    RCL threshold *
;    ABS             ;                            
;    X>Y Goto Jumpping  ;change was greater than threshold fraction
                                                 
    label first_time ;this is our first time thru
    0 STO first_pass
    RCL Ion_Dvoltsx_mm  ;Update new Old values he
    STO old_grad_x    ;store new old value       
    RCL Ion_Dvoltsy_mm                           
    STO old_grad_y    ;store new old value       
    RCL Ion_Dvoltsz_mm                           
    STO old_grad_z    ;store new old value       
    EXIT              ;no change found          
                                                 
    label jumpping     ;we are going to jump
;    Mess ;making jump 
    0 STO KE_adjusted   ;set false
    1 STO jumpped       ;set true
    RCL Ion_time_of_Flight 
    STO old_TOF        ;save TOF
    RCL Ion_DvoltsZ_mm  ;store the current z gradient.
    STO New_gradient
    RCL Ion_Px_mm    ;get x position
    STO old_posit_x  ;save old x              
    RCL Ion_Py_mm    ;get y position
    STO old_posit_y  ;save old y     
    RCL Ion_Pz_mm    ;get z position
    STO old_posit_z  ;save old z
      
   ;jump to grid instance
    Ring_Bell
 
   ;position in xy plane with random #
    RAND               ;get random # between 0 and 1
    0.5 -                   ;only center opening of instance
    RCL grid_inst_y *  ;multiply times length of y dimension    
    0.666666 *           ;only the middle opening which is 2/3 of 1/2
    RCL Scaling *
    STO Ion_Py_mm
    RAND               ;do same with x
    0.5 -
    RCL grid_inst_x *     
    0.666666 *           ;only the middle opening which is 2/3 of 1/2  
    RCL Scaling *
;mess ;x value of jump = #
    STO Ion_Px_mm
      ;this works because the instance is centered at 0,0,0    
                   ;in grid and workbench coordinates.
    RCL Scaling
;mess ;z value of jump = #   
    STO Ion_Pz_mm  ;set z one grid unit in
    RCL Ion_Vz_mm    ;get the x velocity
    X>0 exit         ;skip next section if velocity is positive
    Change_Sign
    STO Ion_Vz_mm         ;set a new positive velocity
    1 STO Sign_changed    ;remember that we changed the sign
    EXIT                  ;done
 
;end of program
 
