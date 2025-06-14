extends Node2D
class_name Agent


@onready var sprite: Sprite2D = get_node("sprite")

const MAX_QUEUE = 25
const STEP_SPEED_PLAYER = 0.2 #sec
const STEP_SPEED_BUNNY = 0.08 #sec

var l: TwitchLogger

var game: Game
var pnl_maze: GameMaze
var maze_data: MazeData:
	get(): return game.maze_data
var game_state: GameState:
	get(): return game.state
var astar: AStarGrid2D:
	get(): return maze_data.astar


var maze_pos: Vector2i:
	set(val):
		if val != maze_pos:
			maze_pos = val
			update_affect_kernel()
			maze_pos_updated.emit()
var affect_kernel: Array[Vector2i]
var _move_queue: Array[Vector2i]


signal maze_pos_updated
@warning_ignore("unused_signal")
signal move_finished
signal move_queue_updated
signal move_queue_dirs_added(dirs: Array[Vector2i])
@warning_ignore("unused_signal")
signal move_queue_finished(agent: Agent)


func _ready() -> void:
	l = TwitchLogger.new(name)
	l.color = Color.ORANGE.to_html() if (self is PlayerAgent) else Color.AQUA.to_html()
	l.d("Added to tree")
	pnl_maze.visibility_changed.connect(_on_resized)
	pnl_maze.resized.connect(_on_resized)
	update()


func add_move_to(end_pos: Vector2i) -> void:
	if not astar:
		l.e("No astar ref")
		return
	if _move_queue.size() >= MAX_QUEUE:
		return
	l.i("Move to %s" % end_pos)
	var dirs: Array[Vector2i] = get_astar_dirs(end_pos)
	
	if moves_left() + dirs.size() > MAX_QUEUE:
		dirs.resize(MAX_QUEUE - moves_left())
	_move_queue.append_array(dirs)
	move_queue_dirs_added.emit(dirs)
	move_queue_updated.emit()


func add_move_directions(dirs: Array[Vector2i]) -> void:
	_move_queue.append_array(dirs)
	move_queue_dirs_added.emit(dirs)
	move_queue_updated.emit()


func update_affect_kernel() -> void:
	if !game: return
	affect_kernel.clear()
	for dir: Vector2i in Globals.CARD_DIR:
		var p1: Vector2i = maze_pos + dir
		if !is_maze(p1): continue
		affect_kernel.append(p1)
		
		var p2: Vector2i = maze_pos + dir * 2
		if !is_maze(p2): continue
		affect_kernel.append(p2)


func has_next_move() -> bool:
	return !_move_queue.is_empty()


#region Update
func update() -> void:
	if !is_node_ready(): return
	await get_tree().process_frame
	position = pnl_maze.maze_pos_to_game_position(maze_pos)
	scale_texture()


func scale_texture() -> void:
	# rescale to match maze cell size
	var img_text_max_size: float = max(sprite.texture.get_size().x, sprite.texture.get_size().y)
	var scale_factor: float = pnl_maze.cell_size / img_text_max_size
	sprite.scale = Vector2.ONE * scale_factor * 0.8
#endregion


#region Utilities
func is_maze(pos: Vector2i) -> bool:
	return maze_data.is_maze(pos)


func get_astar_dirs(end_pos: Vector2i) -> Array[Vector2i]:
	var last_pos: Vector2i = maze_pos
	if !_move_queue.is_empty():
		last_pos = calculate_last_pos()
	
	var new_path: Array[Vector2i] = astar.get_id_path(last_pos, end_pos, true)
	var dirs: Array[Vector2i]
	
	for i: int in range(1, new_path.size()):
		var next_p: Vector2i = new_path[i]
		var dir: Vector2i = next_p - last_pos
		if dir != Vector2i.ZERO:
			dirs.append(dir)
			last_pos = next_p
	return dirs


func calculate_last_pos() -> Vector2i:
	var current: Vector2i = maze_pos
	for dir: Vector2i in _move_queue:
		var next: Vector2i = current + dir
		if is_maze(next):
			current += dir
	return current


func get_next_move() -> Vector2i:
	if !_move_queue.is_empty():
		return _move_queue.front() + maze_pos
	return Vector2i(-1,-1)


func moves_left() -> int:
	return _move_queue.size()
#endregion


#region Signals
func _on_resized() -> void:
	update()
#endregion
