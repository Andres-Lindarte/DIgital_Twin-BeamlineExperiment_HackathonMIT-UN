" Vim syntax file
" Language:	Simion SL
" Version: 0.1
" Last Change:	2004 Mar 23
" Maintainer:  Robert Malek <robert@icr.uni-bremen.de>
" Credits: this work is based on the pascal syntax by 
"    Xavier Cregut <xavier.cregut@enseeiht.fr>, Mario Eusebio <bio@dq.fct.unl.pt>
"    and on the C Syntax by Bram Moolenaar
" Contributors: Dave Manura 
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif


syn case ignore
syn sync lines=100

syn keyword simslImport		import
syn keyword simslConditional	if else endif elseif
syn keyword simslOperator	and or not
syn keyword simslRepeat		for endfor while endwhile step to
syn keyword simslStatement	sub endsub declaresub remote
syn keyword simslStatement	exit returns
syn keyword simslType		adjustable static
" special highlighting for line continuation symbol
syn match simslLineCont		" \.\.\."

syn keyword simslTodo contained	TODO


" String
syn region  simslString matchgroup=simslString start=+"+ end=+"+ skip=/\\"/

syn match   simslIdentifier		"\<[a-zA-Z_][a-zA-Z0-9_]*\>"


syn match   simslSymbolOperator      "[+-/*=%]"
syn match   simslSymbolOperator      "[<>]=\="
syn match   simslSymbolOperator      "!="

syn match   simslNumber        "[+-]\=\<\d\+\(\.\d*\)\=\([eE][+-]\=\d\+\)\=\>"

if exists("simsl_no_tabs")
  syn match simslShowTab "\t"
endif

syn region simslComment	start="#" skip="\\$" end="$" keepend contains=simslTodo

if !exists("simsl_no_functions")

  " math functions
  syn keyword simslFunction	pow10 
  " removed shorthands to simsl coordinate transforms that do _not_ work with SL:
  "   arr azr deg elr ke p p3d pac pao r r3d  rad spd wbc wbo
  syn keyword simslFunction    abs acos 
  syn keyword simslFunction    asin atan 
  syn keyword simslFunction	chs cos exp frac int
  syn keyword simslFunction    ln log
  syn keyword simslFunction    nint rs rand
  syn keyword simslFunction    seed sin sqrt tan
  syn keyword simslFunction    min max floor ceil

  " file functions
  syn keyword simslFunction	array_load array_save mark print key
  " aload and asave removed for the long versions,
  " mess removed to enforce use of print

  " coordinate transforms
  syn keyword simslFunction	pa_coords_to_array_coords wb_coords_to_pa_coords
  syn keyword simslFunction	pa_coords_to_wb_coords azimuth_rotate degrees
  syn keyword simslFunction	elevation_rotate speed_to_ke rect_to_polar
  syn keyword simslFunction	rect3d_to_polar3d wb_orient_to_pa_orient
  syn keyword simslFunction	polar_to_rect polar3d_to_rect3d radians
  syn keyword simslFunction	ke_to_speed pa_orient_to_wb_orient
  " functional if (FIX?)
  "syn keyword simslFunction     if
  
  " crt unit
  syn keyword simslFunction	redraw_screen
  " misc functions
  syn keyword simslFunction	beep bell click nop run_stop
endif

    " predefined variables
    syn match simslPredefined	    "adj_elect\d\+"
    syn match simslPredefined	    "adj_pole\d\+"
    syn keyword simslPredefined    ion_ax_mm ion_ay_mm ion_az_mm
    syn keyword simslPredefined    ion_bfieldx_gu ion_bfieldy_gu ion_bfieldz_gu
    syn keyword simslPredefined    ion_bfieldx_mm ion_bfieldy_mm ion_bfieldz_mm
    syn keyword simslPredefined    ion_charge ion_color
    syn keyword simslPredefined    ion_dvoltsx_gu ion_dvoltsy_gu ion_dvoltsz_gu
    syn keyword simslPredefined    ion_dvoltsx_mm ion_dvoltsy_mm ion_dvoltsz_mm
    syn keyword simslPredefined    ion_instance ion_mass ion_mm_per_grid_unit
    syn keyword simslPredefined    ion_number
    syn keyword simslPredefined    ion_px_abs_gu ion_py_abs_gu ion_pz_abs_gu
    syn keyword simslPredefined    ion_px_gu ion_py_gu ion_pz_gu
    syn keyword simslPredefined    ion_px_mm ion_py_mm ion_pz_mm
    syn keyword simslPredefined    ion_splat ion_time_of_birth ion_time_of_flight
    syn keyword simslPredefined    ion_time_step ion_volts
    syn keyword simslPredefined    ion_vx_mm ion_vy_mm ion_vz_mm
    syn keyword simslPredefined    rerun_flym
    syn keyword simslPredefined    trajectory_image_control
    syn keyword simslPredefined    retain_changed_potentials
    syn keyword simslPredefined    update_pe_surface

    "simsl predefined segements
    syn keyword simslSegment	    Initialize Tstep_Adjust Fast_Adjust
    syn keyword simslSegment	    Efield_Adjust Mfield_Adjust Accel_Adjust
    syn keyword simslSegment	    Other_Actions Terminate Define_Data
    syn keyword simslSegment	    Init_P_Values

"catch (simple) errors caused by wrong Parentheses

    syn region simslInside matchgroup=simslParen start=/(/ matchgroup=simslParen end=/)/ contains=ALL, simslParenError
    syn match simslParenError display ")"

    syn region simslInside matchgroup=simslBracket start=/\[/ matchgroup=simslBracket end=/\]/ contains=ALL, simslBracketError
    syn match simslBracketError display "]"

    " try to match stupid errors of the type "endsub" whithout "sub" etc.:
   " syn match SLError	"\<\(endif\|else\|endsub\|endfor\|endwhile\)\>"
   " syn region SLFor matchgroup=simslRepeat start="\<for" end="\<endfor" contains=ALL
   " leaving this as is: finding sub without endsub etc is much more
   " interesting, will try to find out later

    
" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_simsl_syn_inits")
  if version < 508
    let did_simsl_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink simslComment		Comment
  HiLink simslConditional	Conditional
  HiLink simslFunction		Function
  HiLink simslMatrixDelimiter	Identifier
  HiLink simslNumber		Number
  HiLink simslOperator		Operator
  HiLink simslPredefined	Identifier
  HiLink simslStatement	Statement
  HiLink simslString		String
  HiLink simslSegment		Special
  HiLink simslLineCont		Special
  HiLink simslSymbolOperator	simslOperator
  HiLink simslTodo		Todo
  HiLink simslType		Type
  HiLink simslImport		PreProc
  HiLink simslShowTab		Error
  HiLink simslRepeat		Repeat
  HiLink simslParen		Operator
  HiLink simslParenError	Error
  HiLink simslBracket		Operator
  HiLink simslBracketError	Error

  delcommand HiLink
endif
"unused highlighting IDs: Constant Exception Label 

let b:current_syntax = "simsl"

compiler simsl

" vim: ts=8 sw=2
