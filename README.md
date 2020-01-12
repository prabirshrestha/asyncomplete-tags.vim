tags source for asyncomplete.vim
================================

Provide tag completions for [asyncomplete.vim](https://github.com/prabirshrestha/asyncomplete.vim)

### Installing

```viml
Plug 'prabirshrestha/asyncomplete.vim'
Plug 'prabirshrestha/asyncomplete-tags.vim'
```

asyncomplete-tags.vim is not responsible for creating tag files. You should create tagfiles on your own or use plugins to help you generate tags files.
If you are using a plugin to generate tags make sure it is async so it doesn't block vim.

Here is an example configured with ctags and [vim-gutentags](https://github.com/ludovicchabant/vim-gutentags). vim-gutentags generates tags asynchronously using `job`.

```viml
Plug 'prabirshrestha/asyncomplete.vim'
if executable('ctags')
    Plug 'prabirshrestha/asyncomplete-tags.vim'
    Plug 'ludovicchabant/vim-gutentags'
endif
```

#### Registration

```vim
au User asyncomplete_setup call asyncomplete#register_source(asyncomplete#sources#tags#get_source_options({
    \ 'name': 'tags',
    \ 'whitelist': ['c'],
    \ 'completor': function('asyncomplete#sources#tags#completor'),
    \ 'config': {
    \    'max_file_size': 50000000,
    \  },
    \ }))
```

Also, you may want show Language Server Protocol Engine's result before tag source:

```vim
"sort result with sources' priority
"the default priority of sources is 0
function! s:sort_by_priority_preprocessor(options, matches) abort
    let l:items = []
    for [l:source_name, l:matches] in items(a:matches)
        for l:item in l:matches['items']
            if stridx(l:item['word'], a:options['base']) == 0
                let l:item['priority'] =
                            \ get(asyncomplete#get_source_info(l:source_name),'priority',0)
                call add(l:items, l:item)
            endif
        endfor
    endfor

    let l:items = sort(l:items, {a, b -> b['priority'] - a['priority']})

    call asyncomplete#preprocess_complete(a:options, l:items)
endfunction
let g:asyncomplete_preprocessor =
            \ [function('s:sort_by_priority_preprocessor')]

"set a low priority to tag source
au User asyncomplete_setup call asyncomplete#register_source(asyncomplete#sources#tags#get_source_options({
            \ 'name': 'tags',
            \ 'whitelist': ['c'],
            \ 'completor': function('asyncomplete#sources#tags#completor'),
            \ 'config': {
            \    'max_file_size': 50000000,
            \  },
            \ 'priority' : -100, 
            \ })

```

Note: `config` is optional. `max_file_size` defaults to 50000000 (50mb). If the tag file size exceeds max_file_size it is ignored.
Set `max_file_size` to `-1` for unlimited file size.

It will try to use `grep` or `findstr` (findstr ships with Windows) asynchronously.
If those executables are not found it will fallback to using vimscript which could be slow for large tag files.
