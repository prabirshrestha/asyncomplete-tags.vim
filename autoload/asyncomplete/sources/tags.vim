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

    for l:tag_file in l:tag_files
        let l:lines = readfile(l:tag_file)
        for l:line in l:lines
            if l:line[0] !~ '!'
                let l:splits = split(l:line, "\t")
                let l:word = l:splits[0]
                if !has_key(l:matches, l:word)
                    " only add non-duplicated words
                    let l:matches[l:word] = 1
                endif
            endif
        endfor
    endfor

    let l:startcol = l:col - l:kwlen
    call asyncomplete#complete(a:opt['name'], a:ctx, l:startcol, keys(l:matches))
endfunction

function! s:get_tag_files(opt)
    let l:max_file_size = 20000000 " 20mb

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
