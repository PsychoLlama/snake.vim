" A number between 0 and 1
function! s:get_random_number() abort
  let l:max_number = 32767.0
  let l:rand = system('printf "$RANDOM"')
  return l:rand / l:max_number
endfunction

" A template for every game.
let s:game = {
      \   'objective': { 'row': v:null, 'col': v:null },
      \   'axis_types': {
      \     'HORIZONTAL': 'HORIZONTAL',
      \     'VERTICAL': 'VERTICAL',
      \   },
      \   'directions': {
      \     'RIGHT': 'RIGHT',
      \     'LEFT': 'LEFT',
      \     'DOWN': 'DOWN',
      \     'UP': 'UP',
      \   },
      \   'direction_change': v:null,
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
  call timer_start(75, l:TickFn)
endfunction

function! s:game.Create() abort dict
  let l:copy = deepcopy(s:game)
  let g:game = l:copy

  let l:copy.dimensions.height = winheight('.')
  let l:copy.dimensions.width = winwidth('.')

  call l:copy.AddMotionListeners()
  call l:copy.PlaceSnake()
  call l:copy.PlaceObjective()
  call l:copy.Render()
  call l:copy.ScheduleNextTick()

  return l:copy
endfunction

function! s:game.AddMotionListeners() abort dict
  let l:dir = l:self.directions
  let b:GoUp = function(l:self.ChangeDirection, [l:dir.UP], l:self)
  let b:GoDown = function(l:self.ChangeDirection, [l:dir.DOWN], l:self)
  let b:GoLeft = function(l:self.ChangeDirection, [l:dir.LEFT], l:self)
  let b:GoRight = function(l:self.ChangeDirection, [l:dir.RIGHT], l:self)

  nnoremap <silent><buffer>h :call b:GoLeft()<cr>
  nnoremap <silent><buffer>j :call b:GoDown()<cr>
  nnoremap <silent><buffer>k :call b:GoUp()<cr>
  nnoremap <silent><buffer>l :call b:GoRight()<cr>
endfunction

" Vertical or horizontal?
function! s:game.GetDirectionAxis(direction) abort dict
  let l:dirs = l:self.directions
  if a:direction is# l:dirs.UP || a:direction is# l:dirs.DOWN
    return l:self.axis_types.VERTICAL
  elseif a:direction is# l:dirs.LEFT || a:direction is# l:dirs.RIGHT
    return l:self.axis_types.HORIZONTAL
  endif
endfunction

function! s:game.ChangeDirection(direction) abort dict
  let l:axis = l:self.GetDirectionAxis(a:direction)

  " Prevent 180 degree turns.
  if l:axis is# l:self.GetDirectionAxis(l:self.direction)
    return
  endif

  let l:self.direction_change = a:direction
endfunction

function! s:game.GetLine(index) abort dict
  let l:points = get(l:self.snake, a:index, {})

  let l:col = 1
  let l:line = ''
  while l:col <= l:self.dimensions.width
    let l:is_objective = a:index == l:self.objective.row
          \ && l:col == l:self.objective.col

    if l:is_objective
      let l:char = '*'
    elseif has_key(l:points, l:col)
      let l:char = '#'
    else
      let l:char = ' '
    endif

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

function! s:game.GetRandomCoords() abort dict
  let l:w_seed = s:get_random_number()
  let l:h_seed = s:get_random_number()

  let l:row = float2nr(l:h_seed * l:self.dimensions.height) + 1
  let l:col = float2nr(l:w_seed * l:self.dimensions.width) + 1

  return { 'row': l:row, 'col': l:col }
endfunction

function! s:game.PlaceSnake() abort dict
  let l:coords = l:self.GetRandomCoords()

  let l:self.direction = l:self.GetSafeSnakeDirection(l:coords.col, l:coords.row)
  call l:self.FillSnake(l:coords.row, l:coords.col)
endfunction

function! s:game.PlaceObjective() abort dict
  let l:coords = l:self.GetRandomCoords()

  " If it intersects with the snake, try again.
  if l:self.HasCollision(l:coords)
    return l:self.PlaceObjective()
  endif

  let l:self.objective = l:coords
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

function! s:game.MoveSnake(next_position, remove_tail) abort dict
  if a:remove_tail
    let l:oldest_position = remove(l:self.history, 0)
    call remove(l:self.snake[l:oldest_position.row], l:oldest_position.col)
  endif

  call l:self.AddToSnakeSize(a:next_position.row, a:next_position.col)
endfunction

function! s:game.Render() abort dict
  let l:col = 1


  while l:col <= l:self.dimensions.height
    let l:line = l:self.GetLine(l:col)

    setlocal modifiable
    call setline(l:col, l:line)
    setlocal nomodifiable

    let l:col += 1
  endwhile

endfunction

function! s:game.RenderTick(timer_id) abort dict
  " If the buffer is closed or not focused.
  if !l:self.IsSnakeBuffer()
    return
  endif

  " Apply the direction change (prevents two
  " immediate 90deg turns within the same frame).
  if l:self.direction_change != v:null
    let l:self.direction = l:self.direction_change
    let l:self.direction_change = v:null
  endif

  let l:next_position = l:self.GetNextSnakePosition()

  " Ran off the map or into itself?
  if l:self.IsOutOfBounds(l:next_position) || l:self.HasCollision(l:next_position)
    return
  endif

  let l:remove_tail = v:true
  if l:self.IsObjective(l:next_position)
    call l:self.PlaceObjective()
    let l:remove_tail = v:false
  endif

  call l:self.MoveSnake(l:next_position, l:remove_tail)
  call l:self.Render()
  call l:self.ScheduleNextTick()
endfunction

function! s:game.IsOutOfBounds(head) abort dict
  if a:head.row < 1 || a:head.row >= l:self.dimensions.height + 1
    return v:true
  endif

  if a:head.col < 1 || a:head.col >= l:self.dimensions.width + 1
    return v:true
  endif

  return v:false
endfunction

function! s:game.HasCollision(position) abort dict
  if !has_key(l:self.snake, a:position.row)
    return v:false
  endif

  if !has_key(l:self.snake[a:position.row], a:position.col)
    return v:false
  endif

  return v:true
endfunction

function! s:game.IsObjective(coord) abort dict
  let l:obj = l:self.objective

  return a:coord.row == l:obj.row && a:coord.col == l:obj.col
endfunction

function! snake#init_game() abort
  tabnew Snake

  let b:is_snake_game = v:true

  setlocal nomodifiable nowriteany nobuflisted nonumber listchars=
  setlocal buftype=nowrite bufhidden=delete signcolumn=no

  call s:game.Create()
endfunction
