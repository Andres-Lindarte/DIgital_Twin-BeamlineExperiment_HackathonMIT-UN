" Vim syntax file
" Language:	Simion Geometry
" Maintainer:	Robert Malek <Robert@icr.uni-bremen.de>
" Last change:	2004 APR 07

" Remove any existing syntax stuff (unless this file is being run by "simhfn.vim")
if !(exists("b:current_syntax") && b:current_syntax == "save")
    syn clear
endif

" simion extentions: geometry files

syn case ignore

syn match   simionComment	";.*$"

syn keyword geometrySpecial	PA_Define
syn keyword geometrySpecial     Locate Project Project_It Transform
syn keyword geometrySpecial     Include

syn keyword geometryKeyword	cylindrical planar
syn keyword geometryKeyword     none non-mirrored non_mirrored x y z xy yz xz xyz
syn keyword geometryKeyword     Electrostatic Electric Magnetic

syn keyword geometryStatement	Electrode E P Elect Pole Electrode_Points Pole Pole_Points
syn keyword geometryStatement   Non_Electrode N Non_E Non_P Non_Pole Non_Electrode_Points
syn keyword geometryStatement       Non_Pole_Points
syn keyword geometryStatement	Fill Fill_Volume
syn keyword geometryStatement   Edge_Fill Edge_Fill_Volume
syn keyword geometryStatement   Rotate_Fill Rotate_Fill_Volume
syn keyword geometryStatement   Rotate_Edge_Fill Rotate_Edge_Fill_Volume
syn keyword geometryStatement	Within
syn keyword geometryStatement	Within_Inside
syn keyword geometryStatement	Within_Inside_Or_On
syn keyword geometryStatement   Notin
syn keyword geometryStatement   Notin_Inside
syn keyword geometryStatement   Notin_Inside_Or_On

syn keyword geometryObject	Box Box2D
syn keyword geometryObject      Box3D
syn keyword geometryObject      Centered_Box Centered_Box2D Cent_Box Cent_Box2D
syn keyword geometryObject      Centered_Box3D Cent_Box3D
syn keyword geometryObject      Circle Ellipse
syn keyword geometryObject	Corner_Box Corner_Box2D Corn_Box Corn_Box2D
syn keyword geometryObject	Corner_Box3D Corn_Box3D
syn keyword geometryObject	Cylinder
syn keyword geometryObject      Hyperbola
syn keyword geometryObject      Parabola
syn keyword geometryObject      Points Points2D
syn keyword geometryObject      Points3D
syn keyword geometryObject	Polyline
syn keyword geometryObject      Sphere Ellipsoid

hi link simionComment	    Comment
hi link geometrySpecial	    Special
hi link geometryKeyword	    Identifier
hi link geometryStatement   Statement
hi link geometryObject	    Type

let b:current_syntax = "simgem"

" vim: ts=8
