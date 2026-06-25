" Vim syntax file
" Language:	Simion user Program	
" Maintainer:	Robert Malek <robert@icr.uni-bremen.de>
" Contributors: Dave Manura
" Last change:	2004 APR 07

" Remove any old syntax stuff hanging around
syn clear

" note: the simion extension .prg collides with clipper.. you might want
" to use a modeline: ; vim: syntax=simprg

" note: simion is not case sensitive,
" my personal preferences for upper and lowercase are given below, 
" you may switch off case senstivity by uncommenting the next line...

syn case ignore

" note: I was a bit lazy with statements. With (very few ) exceptions,
" only short forms of commands are supported. Many Conversion Commands are missing

syn keyword simprgSection	    EXIT LBL LABEL RTN RETURN SEG

syn keyword simprgStatement	    GOTO RCL STO

syn match   simprgStatement	    "1/X"
syn keyword simprgStatement	    "10^X"

syn match   simprgStatement	    "E^X"
syn match   simprgStatement	    "X><Y"
syn match   simprgStatement	    "R/S"
syn match   simprgStatement	    "KEY?"
syn match   simprgStatement	    ">ARR"
syn match   simprgStatement	    ">AZR"
syn match   simprgStatement	    ">DEG"
syn match   simprgStatement	    ">ELR"
syn match   simprgStatement	    ">KE"
syn match   simprgStatement	    ">P"
syn match   simprgStatement	    ">P3D"
syn match   simprgStatement	    ">PAC"
syn match   simprgStatement	    ">PAO"
syn match   simprgStatement	    ">R"
syn match   simprgStatement	    ">R3D"
syn match   simprgStatement	    ">RAD"
syn match   simprgStatement	    ">SPD"
syn match   simprgStatement	    ">WBC"
syn match   simprgStatement	    ">WBO"


syn keyword simprgStatement	    ABS ACOS ASIN ATAN BELL BEEP CHS CLICK COS ENTR ENTER
syn keyword simprgStatement	    FRAC GSB GOSUB GTO GOTO INT LN LOG MARK
syn keyword simprgStatement	    MESS NINT NOP RAND REDRAW RLDN RLUP SEED
syn keyword simprgStatement	    SIN SQRT TAN
syn keyword simprgStatement         ARCL ALOAD ASAVE ASTO
syn keyword simprgType		    defa defs adefa adefs
syn match simprgConditional	    "X>Y" 
syn match simprgConditional	    "X<Y"
syn match simprgConditional	    "X>0" 
syn match simprgConditional	    "X<0"      
syn match simprgConditional	    "X>=Y" 
syn match simprgConditional	    "X<=Y"
syn match simprgConditional	    "X>=0" 
syn match simprgConditional	    "X<=0" 
syn match simprgConditional	    "X=0"
syn match simprgConditional	    "X!=0"
syn match simprgConditional	    "X=Y"
syn match simprgConditional	    "X!=Y"


" long forms (in order listed in the manual)
syn keyword simprgSection           ADD SUBTRACT MULTIPLY DIVIDE
syn keyword simprgStatement         RECIPROCAL_OF_X
syn keyword simprgStatement         10_TO_THE_X
syn keyword simprgStatement         PA_COORDS_TO_ARRAY_COORDS
syn keyword simprgStatement         AZIMUTH_ROTATE
syn keyword simprgStatement         RADIANS_TO_DEGREES
syn keyword simprgStatement         ELEVATION_ROTATE
syn keyword simprgStatement         SPEED_TO_KINETIC_ENERGY
syn keyword simprgStatement         RECT_TO_POLAR
syn keyword simprgStatement         RECT3D_TO_POLAR3D
syn keyword simprgStatement         WB_COORDS_TO_PA_COORDS
syn keyword simprgStatement         WB_ORIENT_TO_PA_ORIENT
syn keyword simprgStatement         POLAR_TO_RECT
syn keyword simprgStatement         POLAR3D_TO_RECT3D
syn keyword simprgStatement         DEGREES_TO_RADIANS
syn keyword simprgStatement         KINETIC_ENERGY_TO_SPEED
syn keyword simprgStatement         PA_COORDS_TO_WB_COORDS
syn keyword simprgStatement         PA_ORIENT_TO_WB_ORIENT
syn keyword simprgStatement         ABSOLUTE_VALUE
syn keyword simprgStatement         ARC_COSINE
syn keyword simprgType              ARRAY_DEFINE_ADJUSTABLE
syn keyword simprgType              ARRAY_DEFINE_STATIC
syn keyword simprgStatement         ARRAY_LOAD
syn keyword simprgStatement         ARRAY_RECALL
syn keyword simprgStatement         ARRAY_SAVE
syn keyword simprgStatement         ARC_SINE
syn keyword simprgStatement         ARRAY_STORE
syn keyword simprgStatement         ARC_TANGENT
syn keyword simprgStatement         BEEP_SOUND
syn keyword simprgStatement         RING_SOUND
syn keyword simprgStatement         CHANGE_SIGN
syn keyword simprgStatement         CLICK_SOUND
syn keyword simprgStatement         COSINE
syn keyword simprgType              DEFINE_ADJUSTABLE
syn keyword simprgType              DEFINE_STATIC
syn keyword simprgStatement         E_TO_THE_X
syn keyword simprgStatement         DUPLICATE_X
syn keyword simprgStatement         DECIMAL_FRACTION
syn keyword simprgStatement         GOSUB GO_SUBROUTINE
syn keyword simprgStatement         GO_TO
syn keyword simprgStatement         INTEGER
syn keyword simprgStatement         CHECK_FOR_KEY_INPUT
syn keyword simprgSection           LABEL ENTRY SUBROUTINE
syn keyword simprgStatement         NATURAL_LOG
syn keyword simprgStatement         BASE_10_LOG
syn keyword simprgStatement         MARK_ALL_IONS
syn keyword simprgStatement         MESSAGE
syn keyword simprgStatement         NEAREST_INTEGER
syn match   simprgStatement         "RUN/STOP"
syn keyword simprgStatement         RANDOM_NUMBER
syn keyword simprgStatement         RECALL
syn keyword simprgStatement         REDRAW_SCREEN
syn keyword simprgStatement         ROLL_REGISTER_POINTER_DOWN
syn keyword simprgStatement         ROLL_REGISTER_POINTER_UP
syn keyword simprgSection           RETURN_FROM_SUBROUTINE
syn keyword simprgStatement         RANDOM_SEED
syn keyword simprgSection           BEGIN_SEGMENT
syn keyword simprgStatement         SINE
syn keyword simprgStatement         SQUARE_ROOT
syn keyword simprgStatement         STORE
syn keyword simprgStatement         TANGENT
syn keyword simprgStatement         XY_SWAP SWAP_XY
syn match  simprgStatement          "X<>Y"



" all reserved variables, this helps guessing common names...
syn match   simprgIdentifier	    "Adj_Elect[0-9][0-9]"
syn match   simprgIdentifier	    "Adj_Pole[0-9][0-9]" 
syn keyword simprgIdentifier	    Ion_Ax_mm Ion_Ay_mm Ion_Az_mm
syn keyword simprgIdentifier	    Ion_BfieldX_gu Ion_BfieldY_gu Ion_BfieldZ_gu
syn keyword simprgIdentifier	    Ion_BfieldX_mm Ion_BfieldY_mm Ion_BfieldZ_mm
syn keyword simprgIdentifier	    Ion_Charge Ion_Color Ion_Number
syn keyword simprgIdentifier	    Ion_DvoltsX_gu Ion_DvoltsY_gu Ion_DvoltsZ_gu
syn keyword simprgIdentifier	    Ion_DvoltsX_mm Ion_DvoltsY_mm Ion_DvoltsZ_mm
syn keyword simprgIdentifier	    Ion_Instance Ion_Mass Ion_mm_Per_Grid_Unit
syn keyword simprgIdentifier	    Ion_Px_Abs_gu Ion_Py_Abs_gu  Ion_Pz_Abs_gu  
syn keyword simprgIdentifier	    Ion_Px_gu Ion_Py_gu  Ion_Pz_gu  
syn keyword simprgIdentifier	    Ion_Px_mm Ion_Py_mm  Ion_Pz_mm 
syn keyword simprgIdentifier	    Ion_Splat Ion_Time_of_Birth Ion_Time_of_Flight
syn keyword simprgIdentifier	    Ion_Time_Step Ion_Volts
syn keyword simprgIdentifier	    Ion_Vx_mm  Ion_Vy_mm Ion_Vz_mm
syn keyword simprgIdentifier	    Rerun_Flym Update_PE_Surface

syn keyword simprgSegment	    Initialize Tstep_Adjust Fast_Adjust
syn keyword simprgSegment	    Efield_Adjust Mfield_Adjust Accel_Adjust
syn keyword simprgSegment	    Other_Actions Terminate Define_Data


syn match   simprgOperator	    "[-+*/]"

syn match   simprgNumber            "[+-]\=\<\d\+\(\.\d*\)\=\([eE][+-]\=\d\+\)\="

syn match   simprgComment	    ";.*$"


hi link simprgStatement	    Statement
hi link simprgType	    Type
hi link simprgConditional   Conditional
hi link simprgLabel	    Label
hi link simprgOperator	    Operator
hi link simprgNumber	    Number
hi link simprgComment	    Comment
hi link simprgIdentifier    Identifier
hi link simprgSegment	    Special
hi link simprgSection	    Special

let b:current_syntax = "simprg"

" vim: ts=8
