" A number between 0 and 1
function! s:get_random_number() abort
  let l:max_number = 32767.0
  let l:rand = system('printf "$RANDOM"')
  return l:rand / l:max_number
endfunction

" A template for every game.
let s:game = {
      \   'directions': { 'LEFT': -1, 'RIGHT': 1 },
      \   'initial_snake_size': 5,
      \   'direction': v:null,
      \   'dimensions': {},
      \   'history': [],
      \   'snake': {},
      \ }

function! s:game.Create() abort dict
  let l:copy = deepcopy(s:game)
  let g:game = l:copy

  let l:copy.dimensions.height = winheight('.')
  let l:copy.dimensions.width = winwidth('.')

  call l:copy.PlaceSnake()
  call l:copy.Render()

  return l:copy
endfunction

function! s:game.GetLine(index) abort dict
  let l:points = get(l:self.snake, a:index, {})

  let l:col = 1
  let l:line = ''
  while l:col <= l:self.dimensions.width
    let l:char = has_key(l:points, l:col) ? '#' : ' '
    let l:line .= l:char
    let l:col += 1
  endwhile

  return l:line
endfunction

function! s:game.AddToSnakeSize(row, col) abort dict
  if !has_key(l:self.snake, a:row)
    let l:self.snake[a:row] = {}
  endif

  let l:self.snake[a:row][a:col] = v:true

  let l:entry = { 'row': a:row, 'col': a:col }
  let l:self.history += [l:entry]
endfunction

function! s:game.GetSafeSnakeDirection(row, col) abort dict
  let l:size = l:self.initial_snake_size
  let l:buffer = l:size + 2

  " Too close to the side
  if a:col + l:buffer >= l:self.dimensions.width
    return l:self.directions.LEFT
  endif

  return l:self.directions.RIGHT
endfunction

function! s:game.FillSnake(row, col) abort dict
  let l:direction = l:self.direction
  let l:target = l:self.initial_snake_size * l:direction + a:col
  let l:index = a:col

  while l:index < l:target
    call l:self.AddToSnakeSize(a:row, l:index)
    let l:index += l:direction
  endwhile
endfunction

function! s:game.PlaceSnake() abort dict
  let l:w_seed = s:get_random_number()
  let l:h_seed = s:get_random_number()

  let l:row = float2nr(l:h_seed * l:self.dimensions.height) + 1
  let l:col = float2nr(l:w_seed * l:self.dimensions.width) + 1

  let l:self.direction = l:self.GetSafeSnakeDirection(l:col, l:row)
  call l:self.FillSnake(l:row, l:col)
endfunction

function! s:game.Render() abort dict
  let l:col = 1

  while l:col <= l:self.dimensions.height
    let l:line = l:self.GetLine(l:col)
    call setline(l:col, l:line)
    let l:col += 1
  endwhile
endfunction

function! s:game.RenderTick(timer_id) abort dict
  call l:self.Render()
endfunction

function! snake#init_game() abort
  tabnew Snake

  setlocal nowriteany nobuflisted nonumber listchars=
  setlocal buftype=nowrite bufhidden=delete signcolumn=no

  call s:game.Create()
endfunction
