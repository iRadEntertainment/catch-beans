extends Agent
class_name BunnyAgent


var fleeing_from_players: Array[PlayerAgent]


func _ready() -> void:
	super()
	l.enabled = true
	#l.debug = true


func flee(from_pos: Vector2i) -> void:
	fleeing_from_players = game_state.get_players_at_pos(from_pos)
	var flee_dir: Vector2i = (maze_pos - from_pos).clampi(-1, 1)
	var to: Vector2i = flee_pos(flee_dir)
	_move_queue = astar.get_id_path(maze_pos, to)
	
	var tw: Tween = create_tween()
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	
	for p: Vector2 in _move_queue:
		var next_game_pos: Vector2 = pnl_maze.maze_pos_to_game_position(p)
		tw.tween_property(self, ^"position", next_game_pos, STEP_SPEED_BUNNY)
	#tw.tween_property(self, ^"position", pnl_maze.maze_pos_to_game_position(to), STEP_SPEED)
	tw.tween_property(self, ^"maze_pos", to, 0.0)
	await tw.finished
	_move_queue.clear()
	move_queue_finished.emit(self)


func flee_pos(player_dir: Vector2i) -> Vector2i:
	var opposite_dir: Vector2i = player_dir
	var _right_dir: Vector2i = Vector2i(-opposite_dir.y, -opposite_dir.x)
	var _left_dir: Vector2i = -_right_dir
	
	# check opposite first
	var opposite_check: Array = check_flee_dir(maze_pos, opposite_dir)
	var opposite_end_pos: Vector2i = opposite_check[0]
	var is_opposite_safe: bool = opposite_check[1]
	var _is_opposite_dead_end: bool = opposite_check[2]
	l.d("Fleeing to %s %s" % [opposite_end_pos, ("SAFE" if is_opposite_safe else "NOT SAFE")] )
	return opposite_end_pos
	
	#if is_opposite_safe:
		#return opposite_end_pos
	## check right hand
	#var right_check: Array = check_flee_dir(maze_pos, right_dir)
	#var is_right_safe: bool = right_check[0]
	#var right_end_pos: Vector2i = right_check[1]
	#if is_right_safe: return right_end_pos
	
	## check left hand
	#var left_check: Array = check_flee_dir(maze_pos, left_dir)
	#var is_left_safe: bool = left_check[0]
	#var left_end_pos: Vector2i = left_check[1]
	#if is_left_safe: return left_end_pos
	# else check the furthest
	
	#return maze_pos


func check_flee_dir(from: Vector2i, dir: Vector2i, can_turn := true) -> Array:
	var right_dir: Vector2i = Vector2i(dir.y, dir.x)
	var left_dir: Vector2i = -right_dir
	
	var end_pos: Vector2i = from
	var is_safe: bool = false
	var is_dead_end: bool = false
	
	var iter = 0
	while not is_safe:
		iter += 1
		if iter > 30:
			l.d("Max iterations reached")
			break
		
		var test_pos: Vector2i = end_pos + dir
		var is_t_player: bool = game_state.is_any_player_at_pos(test_pos)
		var is_t_wall: bool = not is_maze(test_pos)
		var is_t_dead_end = maze_data.is_dead_end(test_pos)
		var is_t_unsafe: bool = game_state.is_any_player_reaching_pos(test_pos)
		
		var is_on_branch: bool = maze_data.is_path_branching(end_pos, dir)
		var can_proceed: bool = not (is_t_wall or is_t_dead_end or is_t_player)
		var can_proceed_dead_end: bool = not (is_t_wall or is_t_player)
		
		if can_proceed:
			end_pos = test_pos
			is_safe = !is_t_unsafe
			is_dead_end = is_t_dead_end
		
		elif can_turn and is_on_branch:
			var right_check: Array = check_flee_dir(end_pos, right_dir, false)
			l.d("Right check | Dir %s: %s" % [right_dir, str(right_check)] )
			var r_end_pos = right_check[0]
			var r_is_safe = right_check[1]
			var r_is_dead_end = right_check[2]
			if r_is_safe and not r_is_dead_end:
				return [r_end_pos, r_is_safe, r_is_dead_end]
			# check left hand
			var left_check: Array = check_flee_dir(end_pos, left_dir, false)
			l.d("Left check | Dir %s: %s" % [left_dir, str(left_check)] )
			var l_end_pos = left_check[0]
			var l_is_safe = left_check[1]
			var l_is_dead_end = left_check[2]
			if l_is_safe and not l_is_dead_end:
				return [l_end_pos, l_is_safe, l_is_dead_end]
			
			if r_is_safe:
				return [r_end_pos, r_is_safe, r_is_dead_end]
			if l_is_safe:
				return [l_end_pos, l_is_safe, l_is_dead_end]
			
			break
		
		elif can_proceed_dead_end:
			end_pos = test_pos
			is_safe = !is_t_unsafe
			is_dead_end = is_t_dead_end
		else:
			return [end_pos, is_safe, is_dead_end]
	
	return [end_pos, is_safe, is_dead_end]


func should_flee_from(pos: Vector2i) -> bool:
	return pos in affect_kernel
