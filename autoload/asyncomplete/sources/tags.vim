function! asyncomplete#sources#tags#get_source_options(opt)
    return a:opt
endfunction

function! asyncomplete#sources#tags#completor(opt, ctx)
    let l:tag_files = s:get_tag_files(a:opt)
    if empty(l:tag_files)
        return
    endif

    call asyncomplete#log('using tagfiles', l:tag_files)

    let l:col = a:ctx['col']
    let l:typed = a:ctx['typed']

    let l:kw = matchstr(l:typed, '\w\+$')
    let l:kwlen = len(l:kw)
    if l:kwlen < 1
        return
    endif

    let l:matches = {}
    let l:startcol = l:col - l:kwlen

    let l:info = { 'counter': len(l:tag_files), 'startcol': l:startcol, 'matches': l:matches, 'opt': a:opt, 'ctx': a:ctx, 'lines': [] }

    if executable('grep')
        for l:tag_file in l:tag_files
            let l:id = s:exec(['grep', '-e', '^' . l:typed . '[^\t]*\t', s:escape(l:tag_file)], function('s:on_exec_events', [l:info]))
            if (l:id <= 0)
                let l:info['counter'] -= 1
            endif
        endfor
        if l:info['counter'] == 0
            call s:complete(l:info)
        endif
    elseif executable('findstr')
        for l:tag_file in l:tag_files
            let l:id = s:exec(['findstr', '/i', '/b', l:typed, s:escape(l:tag_file)], function('s:on_exec_events', [l:info]))
            if (l:id <= 0)
                let l:info['counter'] -= 1
            endif
        endfor
        if l:info['counter'] == 0
            call s:complete(l:info)
        endif
    else
        for l:tag_file in l:tag_files
            let l:lines = readfile(l:tag_file)
            call s:lines_to_matches(l:matches, l:lines)
        endfor

        call asyncomplete#complete(a:opt['name'], a:ctx, l:startcol, keys(l:matches))
    endif
endfunction

function s:escape(path) abort
  if has('win32') || has('win64')
      return substitute(a:path, '/', '\\', 'g')
  else
      return a:path
  endif
endfunction

function! s:on_exec_events(info, id, data, event) abort
    if (a:event == 'exit')
        let a:info['counter'] -= 1
        call asyncomplete#log('asyncomplete-tags.vim', 'exitcode', a:data)
        if (a:data == 0) " if exited successfully
            call s:lines_to_matches(a:info['matches'], a:info['lines'])
        endif
        if (a:info['counter'] == 0) " if all tag files search completed
            call s:complete(a:info)
        endif
    elseif (a:event == 'stdout') " when we get a buffer
        let a:info['lines'] += a:data
    endif
endfunction

function! s:complete(info) abort
    let l:opt = a:info['opt']
    let l:ctx = a:info['ctx']
    call asyncomplete#complete(l:opt['name'], l:ctx, a:info['startcol'], keys(a:info['matches']))
endfunction

function! s:lines_to_matches(matches, lines) abort
    for l:line in a:lines
        if l:line[0] !~ '!'
            let l:splits = split(l:line, "\t")
            if len(l:splits) > 0
                let l:word = l:splits[0]
                let a:matches[l:word] = 1
            endif
        endif
    endfor
endfunction

function! s:get_tag_files(opt)
    let l:max_file_size = 50000000 " 20mb

    if has_key(a:opt, 'config') && has_key(a:opt['config'], 'max_file_size')
        let l:max_file_size = a:opt['config']['max_file_size']
    endif

    let l:all_tag_files = map(tagfiles(), 'fnamemodify(v:val, ":p")')
    let l:result = []
    for l:tag_file in l:all_tag_files
        let l:file_size = getfsize(l:tag_file)
        if l:file_size == -1 || l:file_size <= l:max_file_size
            call add(l:result, l:tag_file)
        else
            call asyncomplete#log('ignoring tag file due to large size', l:tag_file, l:file_size)
        endif
    endfor
    return l:result
endfunction

" vim8/neovim jobs wrapper {{{
function! s:exec(cmd, callback) abort
    if has('nvim')
        return jobstart(a:cmd, {
            \ 'on_stdout': a:callback,
            \ 'on_stderr': a:callback,
            \ 'on_exit': a:callback,
            \ })
    else
        let l:job = job_start(a:cmd, {
            \ 'out_cb': function('s:on_vim_job_event', [a:callback, 'stdout']),
            \ 'err_cb': function('s:on_vim_job_event', [a:callback, 'stderr']),
            \ 'exit_cb': function('s:on_vim_job_event', [a:callback, 'exit']),
            \ 'mode': 'raw',
            \ })
        if job_status(l:job) !=? 'run'
            return -1
        else
            return 1
        endif
    endif
endfunction

function! s:on_vim_job_event(callback, event, id, data) abort
    " normalize to neovim's job api
    if (a:event == 'exit')
        call a:callback(a:id, a:data, a:event)
    else
        call a:callback(a:id, split(a:data, "\n", 1), a:event)
    endif
endfunction
" }}}
