" haystack.vim
" Author:       Tim Pope <http://tpo.pe/>
" Version:      1.0

if exists('g:loaded_haystack')
  finish
endif
let g:loaded_haystack = 1

if !exists('g:completion_filter')
  let g:completion_filter = {'Apply': function('haystack#filter')}
endif

if !exists('g:projectionist_completion_filter')
  let g:projectionist_completion_filter = {'Apply': function('haystack#filter')}
endif
