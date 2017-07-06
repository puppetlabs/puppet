" Vim indent file
" Language:	Puppet
" Maintainer:	Todd Zullinger <tmz@pobox.com>
" Last Change:	2009 Aug 19
" vim: set sw=4 sts=4:

if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal autoindent smartindent
setlocal indentexpr=GetPuppetIndent()
setlocal indentkeys+=0],0)

if exists("*GetPuppetIndent")
    finish
endif

" Check if a line is part of an include 'block', e.g.:
"   include foo,
"       bar,
"       baz
function! s:PartOfInclude(lnum)
    let lnum = a:lnum
    while lnum
        let lnum = lnum - 1
        let line = getline(lnum)
        if line !~ ',$'
            break
        endif
        if line =~ '^\s*include\s\+[^,]\+,$'
            return 1
        endif
    endwhile
    return 0
endfunction

function! s:OpenBrace(lnum)
    call cursor(a:lnum, 1)
    return searchpair('{\|\[\|(', '', '}\|\]\|)', 'nbW')
endfunction

function! GetPuppetIndent()
    let pnum = prevnonblank(v:lnum - 1)
    if pnum == 0
       return 0
    endif

    let line = getline(v:lnum)
    let pline = getline(pnum)
    let ind = indent(pnum)

    if pline =~ '^\s*#'
        return ind
    endif

    if pline =~ '\({\|\[\|(\|:\)$'
        let ind += &sw
    elseif pline =~ ';$' && pline !~ '[^:]\+:.*[=+]>.*'
        let ind -= &sw
    elseif pline =~ '^\s*include\s\+.*,$'
        let ind += &sw
    endif

    if pline !~ ',$' && s:PartOfInclude(pnum)
        let ind -= &sw
    endif

    " Match } }, }; ] ]: )
    if line =~ '^\s*\(}\(,\|;\)\?$\|]:\?$\|)\)'
        let ind = indent(s:OpenBrace(v:lnum))
    endif

    return ind
endfunction
