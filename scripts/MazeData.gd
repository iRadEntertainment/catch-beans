extends Resource
class_name MazeData

# settings
@export var maze_size: Vector2i
@export var maze_seed: String

# generated
@export var btm_boundaries: BitMap
@export var btm_corners: BitMap
@export var btm_walls: BitMap
@export var btm_maze: BitMap
@export var btm_dead_ends: BitMap
@export var btm_dead_ends_paths: BitMap
var list_boundaries: Array[Vector2i]
var list_corners: Array[Vector2i]
var list_walls: Array[Vector2i]
var list_maze: Array[Vector2i]
var list_dead_ends: Array[Vector2i]
var list_dead_ends_paths: Array[Vector2i]

var rng: RandomNumberGenerator:
	get():
		if not rng: regen_rng()
		return rng
var astar: AStarGrid2D:
	get():
		if not astar: regen_astar()
		return astar


func pick_random_maze_point() -> Vector2i:
	var rand_point = list_maze[rng.randi_range(0, list_maze.size()-1)]
	return rand_point


func is_maze(pos: Vector2i) -> bool:
	if not Rect2i(Vector2i.ZERO, maze_size).has_point(pos):
		return false
	return btm_maze.get_bitv(pos)


func regen_btms_dead_end() -> void:
	btm_dead_ends = BitMap.new()
	btm_dead_ends.create(maze_size)
	btm_dead_ends_paths = BitMap.new()
	btm_dead_ends_paths.create(maze_size)
	list_dead_ends = []
	list_dead_ends_paths = []
	
	for x in range(1, maze_size.x-1, 2):
		for y in range(1, maze_size.y-1, 2):
			var p: Vector2i = Vector2i(x, y)
			if get_free_neighbours(p).size() == 1:
				btm_dead_ends.set_bitv(p, true)
				list_dead_ends.append(p)
	
	for p: Vector2i in list_dead_ends:
		btm_dead_ends_paths.set_bitv(p, true)
		var dir: Vector2i = get_first_open_dir(p)
		var next: Vector2i = p + dir
		var is_branch: bool = is_path_branching(next, dir)
		while !is_branch:
			btm_dead_ends_paths.set_bitv(next, true)
			next += dir
			is_branch = is_path_branching(next, dir)


func regen_rng() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = hash(maze_seed)


func regen_astar() -> void:
	astar = AStarGrid2D.new()
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.region = Rect2i(0, 0, maze_size.x, maze_size.y)
	astar.update()
	for x in maze_size.x:
		for y in maze_size.y:
			var p := Vector2i(x,y)
			if not btm_maze.get_bitv(p):
				astar.set_point_solid(p, true)
	astar.update()


func get_free_neighbours(pos: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for dir: Vector2i in Globals.CARD_DIR:
		var p: Vector2i = pos + dir
		if is_maze(p):
			found.append(p)
	return found


func is_path_branching(pos: Vector2i, axis_dir: Vector2i) -> bool:
	for dir: Vector2i in Globals.CARD_DIR:
		# skip same direction (front and back)
		if dir == axis_dir or dir == -axis_dir:
			continue
		var p: Vector2i = pos + dir
		if is_maze(p):
			return true
	return false


func is_dead_end(pos: Vector2i) -> bool:
	return btm_dead_ends_paths.get_bitv(pos)


func get_first_open_dir(from: Vector2i) -> Vector2i:
	for dir: Vector2i in Globals.CARD_DIR:
		var p: Vector2i = from + dir
		if is_maze(p):
			return dir
	return Vector2i()
