# haystack.vim

Haystack provides a fuzzy matching algorithm for use by other Vim plugins.
It's based on [flx][] for Emacs but adapted to my own real world experience.
The algorithm gives priority to runs of consecutive letters and letters after
punctuation marks.

[flx]: https://github.com/lewang/flx

## Usage

Haystack defines `g:completion_filter` with a reference to a function for
filtering a list of items based on a user provided query.  Plugins can check
for this variable and use it if it exists.  This level of indirection allows
for alternative matching algorithms without the need for plugins to be aware
of each one.

So far, out of the box support is included with [projectionist.vim][],
including dependent plugins like [rails.vim][].

[projectionist.vim]: https://github.com/tpope/vim-projectionist
[rails.vim]: https://github.com/tpope/vim-rails

### Use with fuzzy finders

Here's a proof of concept for [ctrlp.vim][].

    function! CtrlPMatch(items, str, limit, mmode, ispath, crfile, regex) abort
      let items = copy(a:items)
      if a:ispath
        call filter(items, 'v:val !=# a:crfile')
      endif
      return haystack#filter(items, a:str)
    endfunction
    let g:ctrlp_match_func = {'match': function('CtrlPMatch')}

Note that the algorithm is slow enough to feel sluggish with larger data sets.
You might consider a hybrid approach that uses a different algorithm above a
certain number of items.

[ctrlp.vim]: https://github.com/kien/ctrlp.vim

## License

Copyright © Tim Pope.  Distributed under the same terms as Vim itself.
See `:help license`.
