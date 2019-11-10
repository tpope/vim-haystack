" Location:     autoload/haystack.vim
" Author:       Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_haystack')
  finish
endif
let g:autoloaded_haystack = 1

" Arguments:
" 1st: List of items to filter. Will be mutated.
" 2nd: Query to filter by.
" 3rd: Path separator (slash), if different from platform default.
" 4th: Reserved for a future options dictionary.
function! haystack#filter(list, query, ...) abort
  if empty(a:query)
    return a:list
  endif
  call map(a:list, '[99999999-haystack#score(v:val, a:query, a:0 ? a:1 : haystack#slash()), type(v:val) == type({}) ? v:val.word : v:val, v:val]')
  call filter(a:list, 'v:val[0] < 99999999')
  call sort(a:list)
  call map(a:list, 'v:val[2]')
  return a:list
endfunction

function! haystack#slash() abort
  return exists('+shellslash') && !&shellslash ? '\' : '/'
endfunction

if !exists('s:hashes')
  let s:hashes = {}
  let s:heatmaps = {}
endif

function! s:get_hash_for_str(str) abort
  if has_key(s:hashes, a:str)
    return s:hashes[a:str]
  endif
  let res = {}
  let i = 0
  for char in split(tolower(a:str), '\zs')
    let res[char] = get(res, char, [])
    call add(res[char], i)
    let i += 1
  endfor
  let s:hashes[a:str] = res
  return res
endfunction

function! haystack#heatmap(str, ...) abort
  let key = (a:0 ? (empty(a:1) ? "\002" : a:1) : "\001") . a:str
  if has_key(s:heatmaps, key)
    return s:heatmaps[key]
  endif
  let chars = split(a:str, '\zs')
  let scores = repeat([-35], len(chars))
  let groups_alist = [[-1, 0]]
  let scores[-1] += 1
  let last_char = ''
  let group_word_count = 0
  let i = 0
  for char in chars
    let effective_last_char = empty(group_word_count) ? '' : last_char
    if  effective_last_char.char =~# '\U\u\|[[:punct:][:space:]][^[:punct:][:space:]]\|^.$'
      call insert(groups_alist[0], i, 2)
    endif
    if last_char.char =~# '^[[:punct:][:space:]]\=[^[:punct:][:space:]]$'
      let group_word_count += 1
    endif
    if last_char ==# '.'
      let scores[i] -= 45
    endif
    if a:0 && a:1 ==# char
      let groups_alist[0][1] = group_word_count
      let group_word_count = 0
      call insert(groups_alist, [i, group_word_count])
    endif
    if i == len(chars) - 1
      let groups_alist[0][1] = group_word_count
    endif
    let i += 1
    let last_char = char
  endfor
  let group_count = len(groups_alist)
  let separator_count = group_count - 1
  if separator_count
    call map(scores, 'v:val - 2*group_count')
  endif
  let i = separator_count
  let last_group_limit = 0
  let basepath_found = 0
  for group in groups_alist
    let group_start = group[0]
    let word_count = group[1]
    let words_length = len(group) - 2
    let basepath_p = 0
    if words_length && !basepath_found
      let basepath_found = 1
      let basepath_p = 1
    endif
    if basepath_p
      let num = 35 + (separator_count > 1 ? separator_count - 1 : 0) - word_count
    else
      let num = i ? (i - 6) : -3
    endif
    for j in range(group_start+1, last_group_limit ? last_group_limit-1 : len(scores)-1)
      let scores[j] += num
    endfor
    let wi = words_length - 1
    let last_word = last_group_limit ? last_group_limit : len(chars)
    for word in group[2:-1]
      let scores[word] += 85
      let ci = 0
      for j in range(word, last_word-1)
        let scores[j] += -3 * wi - ci
        let ci += 1
      endfor
      let last_word = word
      let wi -= 1
    endfor

    let last_group_limit = group_start + 1
    let i -= 1
  endfor
  let s:heatmaps[key] = scores
  return scores
endfunction

function! s:get_matches(str, query) abort
  return s:compute_matches(s:get_hash_for_str(a:str), a:query, -1, 0)
endfunction

function! s:compute_matches(hash, query, gt, qi) abort
  let indexes = filter(copy(get(a:hash, a:query[a:qi], [])), 'v:val > a:gt')
  if a:qi >= len(a:query)-1
    return map(indexes, '[v:val]')
  endif
  let results = []
  for index in indexes
    let next = s:compute_matches(a:hash, a:query, index, a:qi+1)
    call extend(results, map(next, '[index] + v:val'))
  endfor
  return results
endfunction

function! haystack#flx_score(str, query, sep) abort
  if empty(a:query) || empty(a:str)
    return -1
  endif
  if a:str !~? '\M'.substitute(escape(a:query, '\'), '.', '&\\.\\*', 'g')
    return 0
  endif
  let query = split(tolower(a:query), '\zs')
  let best_score = []
  let heatmap = haystack#heatmap(a:str, a:sep)
  let matches = s:get_matches(a:str, query)
  let full_match_boost = len(query) > 1 && len(query) < 5

  for match_positions in matches
    let score = full_match_boost && len(match_positions) == len(a:str) ? 10000 : 0
    let contiguous_count = 0
    let last_match = -2
    for index in match_positions
      if last_match + 1 == index
        let contiguous_count += 1
      else
        let contiguous_count = 0
      endif
      let score += heatmap[index]
      if contiguous_count
        let score += 45 + 15 * min([contiguous_count, 4])
      endif
      let last_match = index
    endfor
    if score > get(best_score, 0, -1)
      let best_score = [score] + match_positions
    endif
  endfor
  return get(best_score, 0, 0)
endfunction

function! haystack#score(word, query, ...) abort
  let word = type(a:word) == type({}) ? a:word.word : a:word
  let breaks = len(substitute(substitute(substitute(word,
        \ '[[:punct:]]*$', '', ''),
        \ '.\u\l', '@', 'g'),
        \ '[^[:punct:]]', '', 'g'))
  return haystack#flx_score(word, a:query, a:0 ? a:1 : haystack#slash()) * 10 /
        \ (2+breaks)
endfunction

if !has('pythonx')
  finish
endif

pythonx << EOF
import vim
from collections import defaultdict

def flx_vim_encode(data):
  if isinstance(data, list):
    return "[" + ",".join([flx_vim_encode(x) for x in data]) + "]"
  elif isinstance(data, int):
    return str(data)
  else:
    raise TypeError("can't encode " + data)

flx_hashes = {}
def flx_get_hash_for_str(str):
  if str in flx_hashes:
    return flx_hashes[str]
  res = defaultdict(list)
  i = 0
  for char in str.lower():
    res[char].append(i)
    i += 1
  flx_hashes[str] = res
  return res

def flx_get_matches(hash, query, gt=-1, qi=0):
  qc = query[qi]
  indexes = [int(item) for item in hash[qc] if item > gt]
  if qi >= len(query)-1:
    return [[item] for item in indexes]
  results = []
  for index in indexes:
    next = flx_get_matches(hash, query, index, qi+1)
    results += [[index] + item for item in next]
  return results
EOF

function! s:get_matches(str, query) abort
  pythonx vim.command('return ' + flx_vim_encode(flx_get_matches(flx_get_hash_for_str(vim.eval('a:str')), vim.eval('a:query'))))
endfunction
