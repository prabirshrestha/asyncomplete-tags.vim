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
    \    " Max file size in bytes. Defaults to 20mb
    \    'max_file_size': 20000000,
    \  },
    \ }))
```

Note: `config` is optional. `max_file_size` defaults to 20000000 (20mb). If the tag file size exceeds max_file_size it is ignored.
Set `max_file_size` to `-1` for unlimited file size. This is not recommended as it could slow down vim a lot.
