" Vim compiler file
" Compiler: OpenCode agent review

if exists("current_compiler") | finish | endif
let current_compiler = "opencodereview"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=opencode\ run
let s:errorformat = [
            \ "%E%f:%l: error: %m",
            \ "%W%f:%l: warning: %m",
            \ "%I%f:%l: info: %m",
            \ "%C  %m",
            \ "%-GNO FINDINGS",
            \ "%-G%.%#",
            \ ]
execute "CompilerSet errorformat=" .. escape(join(s:errorformat, ","), ' \|"')

let &cpo = s:cpo_save
unlet s:cpo_save
unlet s:errorformat
