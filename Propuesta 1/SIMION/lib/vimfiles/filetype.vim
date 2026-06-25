" Vim support file to detect Simion file types
"
" Maintainer:	Robert Malek <robert@icr.uni-bremen.de> 
" Last change:	2004 Apr 07

" place this file into a vim runtime directory , eg ~/vimfiles
" in the case of WinXP this means:
" \documents and settings\User\vimfiles\filetype.vim
" \dokumente und einstellugen\users\vimfiles\filetype.vim
" you may have to merge this with existing customizations

augroup filetypedetect

" Simion 
" use the following line, when you know, that you don't want syntax
" highlighting for clipper or fox pro:
"au BufNewFile,BufRead *.prg set ft=simprg

" Simion using filtype_prg definition
au BufNewFile,BufRead *.prg
	\ if exists("g:filetype_prg") |
	\   exe "setf " . g:filetype_prg |
	\ else |
	\   set ft=simprg |
	\ endif


" Simion geometry
au BufNewFile,BufRead *.gem         set ft=simgem

" Simion extended geometry
au BufNewFile,BufRead *.hfx,*.hfn,*.gemh   set ft=simhfn

" Simion SL
au BufNewFile,BufRead *.sl          set ft=simsl

augroup END


