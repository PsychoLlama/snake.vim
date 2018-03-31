if exists('b:current_syntax')
  finish
endif

let b:current_syntax = 'snake'

syntax match snakeBody '\v#'
syntax match snakeObjective '\v\*'
syntax match snakeBorder '\v(-|\|)'

highlight snakeObjective ctermfg=Green

" Syntax groups assigned programmatically.
highlight snakeCollision ctermfg=DarkRed
highlight snakeHead ctermfg=Cyan

highlight link snakeBorder Comment
highlight link snakeBody Comment
