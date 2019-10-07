let s:is_win = has('win32') || has('win64')

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

    let l:matches = []
    let l:startcol = l:col - l:kwlen

    if exists("*getcompletion")
      let l:data = getcompletion(l:kw,'tag')
      for l:word in l:data
        call add(l:matches, {"word": l:word, "dup": 1, "icase": 1, "menu": "[tag]"})
      endfor
      call asyncomplete#complete(a:opt['name'], a:ctx, l:startcol, l:matches)
      return
    endif

    let l:info = { 'counter': len(l:tag_files), 'startcol': l:startcol, 'matches': l:matches, 'opt': a:opt, 'ctx': a:ctx, 'lines': [] }

    if (executable('grep'))
        for l:tag_file in l:tag_files
            let l:jobid = s:exec(['grep', '-P', '^' . l:kw . "[^\t]*\t", s:escape(l:tag_file)], 0, function('s:on_exec_events', [l:info]))
            if (l:jobid < 0)
                let l:info['counter'] -= 1
            endif
        endfor
        if l:info['counter'] == 0
            call s:complete(l:info)
        endif
    elseif (executable('findstr'))
        for l:tag_file in l:tag_files
            let l:jobid = s:exec(['findstr', '/i', '/b', l:typed, s:escape(l:tag_file)], 0, function('s:on_exec_events', [l:info]))
            if (l:jobid < 0)
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

        call asyncomplete#complete(a:opt['name'], a:ctx, l:startcol, l:matches)
    endif
endfunction

function s:escape(path) abort
  if s:is_win
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
    call asyncomplete#complete(l:opt['name'], l:ctx, a:info['startcol'], a:info['matches'])
endfunction

function! s:lines_to_matches(matches, lines) abort
    for l:line in a:lines
        if l:line[0] !~ '!'
            let l:splits = split(l:line, "\t")
            if len(l:splits) > 0
                let l:word = l:splits[0]
                let l:type = l:splits[-1]
                call add(a:matches, {"word": l:word, "dup": 1, "icase": 1, "menu": "[tag: " . l:type . "]"})
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
        if l:max_file_size == -1 || l:file_size <= l:max_file_size
            call add(l:result, l:tag_file)
        else
            call asyncomplete#log('ignoring tag file due to large size', l:tag_file, l:file_size)
        endif
    endfor
    return l:result
endfunction

" vim8/neovim jobs wrapper {{{
function! s:exec(cmd, str, callback) abort
    call asyncomplete#log('asyncomplete-tags.vim', 's:exec', a:cmd)
    if has('nvim')
        return jobstart(a:cmd, {
                \ 'on_stdout': function('s:on_nvim_job_event', [a:str, a:callback]),
                \ 'on_stderr': function('s:on_nvim_job_event', [a:str, a:callback]),
                \ 'on_exit': function('s:on_nvim_job_event', [a:str, a:callback]),
            \ })
    else
        let l:info = { 'close': 0, 'exit': 0, 'exit_code': -1 }
        let l:jobopt = {
            \ 'out_cb': function('s:on_vim_job_event', [l:info, a:str, a:callback, 'stdout']),
            \ 'err_cb': function('s:on_vim_job_event', [l:info, a:str, a:callback, 'stderr']),
            \ 'exit_cb': function('s:on_vim_job_event', [l:info, a:str, a:callback, 'exit']),
            \ 'close_cb': function('s:on_vim_job_close_cb', [l:info, a:str, a:callback]),
        \ }
        if has('patch-8.1.350')
          let l:jobopt['noblock'] = 1
        endif
        let l:job = job_start(a:cmd, l:jobopt)
        let l:channel = job_getchannel(l:job)
        return ch_info(l:channel)['id']
    endif
endfunction

function! s:on_nvim_job_event(str, callback, id, data, event) abort
    if (a:event == 'exit')
        call asyncomplete#log('asyncomplete-tags.vim', 'exit', a:data, a:id)
        call a:callback(a:id, a:data, a:event)
    elseif a:str
        " convert array to string since neovim uses array split by \n by default
        call a:callback(a:id, join(a:data, "\n"), a:event)
    else
        call a:callback(a:id, a:data, a:event)
    endif
endfunction

function! s:on_vim_job_event(info, str, callback, event, id, data) abort
    if a:event == 'exit'
        call asyncomplete#log('asyncomplete-tags.vim', 'exit', a:data, a:info['close'])
        let a:info['exit'] = 1
        let a:info['exit_code'] = a:data
        let a:info['id'] = a:id
        if a:info['close'] && a:info['exit']
            " for more info refer to :h job-start
            " job may exit before we read the output and output may be lost.
            " in unix this happens because closing the write end of a pipe
            " causes the read end to get EOF.
            " close and exit has race condition, so wait for both to complete
            call a:callback(a:id, a:data, a:event)
        endif
    elseif a:str
        call a:callback(a:id, a:data, a:event)
    else
        " convert string to array since vim uses string by default
        call a:callback(a:id, split(a:data, "\n", 1), a:event)
    endif
endfunction

function! s:on_vim_job_close_cb(info, str, callback, channel) abort
    call asyncomplete#log('asyncomplete-tags.vim', 'close_cb', a:info['exit'])
    let a:info['close'] = 1
    if a:info['close'] && a:info['exit']
        call a:callback(a:info['id'], a:info['exit_code'], 'exit')
    endif
endfunction
" }}}
