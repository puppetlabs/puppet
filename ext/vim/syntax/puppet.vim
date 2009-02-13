" puppet syntax file
" Filename:     puppet.vim
" Language:     puppet configuration file 
" Maintainer:   Luke Kanies <luke@madstop.com>
" URL:          
" Last Change: 
" Version:      
"

" Copied from the cfengine, ruby, and perl syntax files
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn region  puppetDefine        start="^\s*\(class\|define\|node\)" end="{" contains=puppetDefType,puppetDefName,puppetDefArguments
syn keyword puppetDefType       class define site node inherits contained
syn keyword puppetInherits      inherits contained
syn region  puppetDefArguments  start="(" end=")" contains=puppetArgument
syn match   puppetArgument      "\w\+" contained
syn match   puppetArgument      "\$\w\+" contained
syn match   puppetArgument      "'[^']+'" contained
syn match   puppetArgument      '"[^"]+"' contained
syn match   puppetDefName     "\w\+" contained

syn match   puppetInstance           "\w\+\s*{" contains=puppetTypeBrace,puppetTypeName,puppetTypeDefault
syn match   puppetTypeBrace       "{" contained
syn match   puppetTypeName       "[a-z]\w*" contained
syn match   puppetTypeDefault    "[A-Z]\w*" contained

syn match   puppetParam           "\w\+\s*=>" contains=puppetTypeRArrow,puppetParamName
syn match   puppetParamRArrow       "=>" contained
syn match   puppetParamName       "\w\+" contained
syn match   puppetVariable           "$\w\+"
syn match   puppetVariable           "${\w\+}"
syn match   puppetParen           "("
syn match   puppetParen           ")"
syn match   puppetBrace           "{"
syn match   puppetBrace           "}"

syn region  puppetString start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=puppetVariable

syn keyword puppetBoolean    true false 
syn keyword puppetKeyword    import inherits include
syn keyword puppetControl    case default 

" comments last overriding everything else
syn match   puppetComment            "\s*#.*$" contains=puppetTodo
syn region  puppetComment            start="/\*" end="\*/" contains=puppetTodo extend
syn keyword puppetTodo               TODO NOTE FIXME XXX contained

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_puppet_syn_inits")
  if version < 508
    let did_puppet_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink puppetVariable             Identifier
  HiLink puppetBoolean              Boolean
  HiLink puppetType                 Identifier
  HiLink puppetDefault              Identifier
  HiLink puppetKeyword              Define
  HiLink puppetTypeDefs             Define
  HiLink puppetComment              Comment
  HiLink puppetString               String
  HiLink puppetTodo                 Todo
"  HiLink puppetBrace                Delimiter
"  HiLink puppetTypeBrace            Delimiter
"  HiLink puppetParen                Delimiter
  HiLink puppetDelimiter            Delimiter
  HiLink puppetControl              Statement
  HiLink puppetDefType              Define
  HiLink puppetDefName              Type
  HiLink puppetTypeName             Statement
  HiLink puppetTypeDefault          Type
  HiLink puppetParamName            Identifier
  HiLink puppetArgument             Identifier

  delcommand HiLink
endif

let b:current_syntax = "puppet"
