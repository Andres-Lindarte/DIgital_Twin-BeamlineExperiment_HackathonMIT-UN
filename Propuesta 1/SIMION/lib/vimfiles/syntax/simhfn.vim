" Vim syntax file
" Language:	Simion Geometries with c++ type header inclusion
" Maintainer:	Robert Malek <robert@icr.uni-bremen.de>
" Credits:		Dave Manura 
" Last change:	2004 APR 07

" assumes use of a c/c++ preprocessor; for example a call for gcc would be:
" g++ -E -Wp,-P -x c -o OUTFILE.gem INFILE.gemh

" please note, that c keywords and functions will be happily highlighted..

runtime syntax/c.vim

let b:current_syntax = "save"
runtime syntax/simgem.vim

