" Vim filetype plugin
" Language:	Simion SL
" Maintainer:	Robert Malek <robert@icr.uni-bremen.de>
" Last Change:	2004 April 13

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let cpo_save = &cpo
set cpo-=C

let b:undo_ftplugin = "setl fo< com< tw< commentstring<"
	\ . "| unlet! b:match_ignorecase b:match_words b:match_skip"

" Comments start with a number sign
setlocal comments=:#
"setlocal commentstring=\#%s

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal formatoptions-=t 
setlocal formatoptions+=croql
setlocal tw=78

" Set 'comments' to format dashed lists in comments
"setlocal com=s:#\ -,m:#\ -,e:#\ -,:#
"setlocal com=:#
 
" Format comments to be up to 78 characters long
" setlocal tw=78  this hurts non-comments!


" Let the matchit plugin know what items can be matched.
if exists("loaded_matchit")
  let b:match_ignorecase = 1
  let b:match_words =
	\ '\<for\>:\<endfor\>,' .
	\ '\<sub\>:\<endsub\>,' .
	\ '\<while\>:\<endwhile\>,' .
	\ '\<if\>:\<else\%[if]\>:\<endif\>,' .
	\ '(:)'
endif

let &cpo = cpo_save
setlocal cpo+=M		" makes \%( match \)

runtime compiler/simsl.vim


