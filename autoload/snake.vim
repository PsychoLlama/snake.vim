" A number between 0 and 1
function! s:get_random_number() abort
  let l:max_number = 32767.0
  let l:rand = system('printf "$RANDOM"')
  return l:rand / l:max_number
endfunction

" A template for every game.
let s:game = {
      \   'directions': {
      \     'RIGHT': 'RIGHT',
      \     'LEFT': 'LEFT',
      \     'DOWN': 'DOWN',
      \     'UP': 'UP',
      \   },
      \   'initial_snake_size': 5,
      \   'direction': v:null,
      \   'dimensions': {},
      \   'history': [],
      \   'snake': {},
      \ }

function! s:game.IsSnakeBuffer() abort
  return get(b:, 'is_snake_game', v:false)
endfunction

function! s:game.ScheduleNextTick() abort dict
  let l:TickFn = function(l:self.RenderTick, [], l:self)
  call timer_start(500, l:TickFn)
endfunction

function! s:game.Create() abort dict
  let l:copy = deepcopy(s:game)
  let g:game = l:copy

  let l:copy.dimensions.height = winheight('.')
  let l:copy.dimensions.width = winwidth('.')

  call l:copy.PlaceSnake()
  call l:copy.Render()
  call l:copy.ScheduleNextTick()

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
  let l:is_moving_left = l:self.direction is# l:self.directions.LEFT
  let l:multiplier = l:is_moving_left ? -1 : 1
  let l:target = l:self.initial_snake_size * l:multiplier + a:col
  let l:index = a:col

  while l:index < l:target
    call l:self.AddToSnakeSize(a:row, l:index)
    let l:index += l:multiplier
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

function! s:game.GetNextSnakePosition() abort dict
  let l:last_position = l:self.history[-1]
  let l:next = { 'row': l:last_position.row, 'col': l:last_position.col }

  if l:self.direction is# l:self.directions.UP
    let l:next.row -= 1
  elseif l:self.direction is# l:self.directions.DOWN
    let l:next.row += 1
  elseif l:self.direction is# l:self.directions.LEFT
    let l:next.col -= 1
  elseif l:self.direction is# l:self.directions.RIGHT
    let l:next.col += 1
  endif

  return l:next
endfunction

function! s:game.MoveSnake() abort dict
  let l:oldest_position = remove(l:self.history, 0)
  call remove(l:self.snake[l:oldest_position.row], l:oldest_position.col)

  let l:next_position = l:self.GetNextSnakePosition()
  call l:self.AddToSnakeSize(l:next_position.row, l:next_position.col)
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
  " If the buffer is closed or not focused.
  if !l:self.IsSnakeBuffer()
    return
  endif

  call l:self.MoveSnake()
  call l:self.Render()
  call l:self.ScheduleNextTick()
endfunction

function! snake#init_game() abort
  tabnew Snake

  let b:is_snake_game = v:true

  setlocal nowriteany nobuflisted nonumber listchars=
  setlocal buftype=nowrite bufhidden=delete signcolumn=no

  call s:game.Create()
endfunction
