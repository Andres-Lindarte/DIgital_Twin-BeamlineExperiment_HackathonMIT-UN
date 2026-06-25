" Vim compiler file
" Compiler:		Simion SL
" Maintainer:	Robert Malek <robert@icr.uni-bremen.de>
" Last Change:	2004 April 13

if exists("current_compiler")
  finish
endif
let current_compiler = "simsl"

" generating a summary from simions error outputs
setlocal errorformat=%ECompile\ failed%.%#,%-C,%CError\ on\ line\ #%l\\,\ file\ %f:,%-C\ \ %.%#,%C%m,%Z
" silently jumps the cursor to the line of the error after make, 
" use clist! to get the complete message

" default make
" note: the echo statement works around problem with spaces
"       in the file path (taken from hugs.vim--haskell)
setlocal makeprg=echo\ :q\ \\\|\ \"$VIM\\..\\..\\bin\\sl.exe\"\ \"%\"
