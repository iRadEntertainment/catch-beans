@tool
extends PanelContainer
class_name GameMaze


@export var tileset_img: Texture2D
@export var tileset_dim: int = 32
@export var tileset_base_color: Color = Color.WHITE:
	set(val):
		tileset_base_color = val
		if is_node_ready():
			%game_base_maze.self_modulate = tileset_base_color

var game: Game
var maze_data: MazeData:
	set(val): maze_data = val; calculate_game_properties()
	get(): return game.maze_data if game else null
var maze_size: Vector2i:
	get(): return game.maze_data.maze_size
var cell_size: float
var is_taller: bool = false
var render_rect: Rect2


func _ready() -> void:
	resized.connect(calculate_game_properties)
	resized.connect(%game_base_maze.queue_redraw)
	#%game_base_maze.draw.connect(draw_reticle)


#region Inputs (Debug)
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_released(): return
		var maze_pos: Vector2i = game_pos_to_maze_pos(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			game.check_user_click(
				Globals.IRAD_ID,
				maze_pos
			)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			game.check_user_click(
				Globals.FINISFINE_ID,
				maze_pos
			)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			game.add_bunny(maze_pos)
#endregion


#region Game actions
func clear() -> void:
	for agent: Agent in %players.get_children() + %bunnies.get_children():
		agent.queue_free()
func add_player_agent(new_player_agent: PlayerAgent) -> void:
	%players.add_child(new_player_agent)
func add_bunny_agent(new_bunny_agent: BunnyAgent) -> void:
	%bunnies.add_child(new_bunny_agent)
#endregion


#region Render (and debug)
func calculate_game_properties() -> void:
	if not maze_data: return
	var game_rect_ratio: float = size.x / size.y
	var maze_rect_ratio: float = float(maze_data.maze_size.x) / maze_data.maze_size.y
	
	is_taller = game_rect_ratio > maze_rect_ratio
	
	cell_size = size.y/maze_data.maze_size.y if is_taller else size.x/maze_data.maze_size.x
	render_rect = Rect2()
	if is_taller:
		render_rect.size.y = size.y
		render_rect.size.x = cell_size * maze_data.maze_size.x
		render_rect.position.x = size.x/2.0 - render_rect.size.x/2.0
	else:
		render_rect.size.x = size.x
		render_rect.size.y = cell_size * maze_data.maze_size.y
		render_rect.position.y = size.y/2.0 - render_rect.size.y/2.0
	

func render_maze() -> void:
	calculate_game_properties()
	#var img_covino: Image = Image.create(maze_size.x, maze_size.y, false, Image.FORMAT_RGBAF)
	#for x in maze_size.x:
		#for y in maze_size.y:
			#var p: Vector2i = Vector2i(x, y)
			#var is_maze: bool = maze_data.is_maze(p)
			#var col: Color = Color.AZURE if is_maze else Color("3f6899")
			#img_covino.set_pixelv(p, col)
	
	
	var tile_img: Image = tileset_img.get_image()
	var img_full_res: Vector2i = maze_size * tileset_dim
	var img_test_tilemap: Image = Image.create(img_full_res.x, img_full_res.y, false, tile_img.get_format())
	
	for x in maze_size.x:
		for y in maze_size.y:
			var p: Vector2i = Vector2i(x, y)
			draw_tile_at_pos(p, img_test_tilemap, tile_img)
	
	%game_base_maze.texture = ImageTexture.create_from_image(img_test_tilemap)
	%game_base_maze.queue_redraw()


func draw_tile_at_pos(p: Vector2i, dst: Image, src: Image) -> void:
	var is_maze: bool = maze_data.is_maze(p)
	var src_rect: Rect2i = Rect2i(0, 0, tileset_dim, tileset_dim)
	if is_maze:
		if (p.x + p.y) % 2 == 0:
			src_rect.position = Vector2i(4, 0) * tileset_dim
		else:
			src_rect.position = Vector2i(4, 1) * tileset_dim
		dst.blend_rect(src, src_rect, p * tileset_dim)
		return
	
	var bit_neighbors: int = 0b0000 # UP, LEFT, DOWN, RIGHT 0b
	for i: int in 4:
		var dir: Vector2i = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][i]
		var n_p: Vector2i = p + dir
		if maze_data.is_maze(n_p):
			continue
		if !Rect2i(Vector2i.ZERO, maze_size).has_point(n_p):
			continue
		bit_neighbors += 0b1 << i
	
	match bit_neighbors:
		# single
		0b0000: src_rect.position = Vector2i(0, 0) * tileset_dim
		# vert
		0b0010: src_rect.position = Vector2i(0, 1) * tileset_dim
		0b1010: src_rect.position = Vector2i(0, 2) * tileset_dim
		0b1000: src_rect.position = Vector2i(0, 3) * tileset_dim
		# horiz
		0b0001: src_rect.position = Vector2i(1, 0) * tileset_dim
		0b0101: src_rect.position = Vector2i(2, 0) * tileset_dim
		0b0100: src_rect.position = Vector2i(3, 0) * tileset_dim
		#corners
		0b0011: src_rect.position = Vector2i(1, 1) * tileset_dim
		0b0110: src_rect.position = Vector2i(2, 1) * tileset_dim
		0b1100: src_rect.position = Vector2i(2, 2) * tileset_dim
		0b1001: src_rect.position = Vector2i(1, 2) * tileset_dim
		#cross
		0b1111: src_rect.position = Vector2i(1, 3) * tileset_dim
		#T-junctions
		0b1011: src_rect.position = Vector2i(3, 1) * tileset_dim
		0b0111: src_rect.position = Vector2i(3, 2) * tileset_dim
		0b1110: src_rect.position = Vector2i(3, 3) * tileset_dim
		0b1101: src_rect.position = Vector2i(2, 3) * tileset_dim
	
	dst.blend_rect(src, src_rect, p * tileset_dim)
#endregion


func draw_reticle() -> void:
	const RETICLE_COLOR = Color(0.5, 0.5, 0.5, 0.5)
	const RETICLE_WIDTH = 1.0 #px
	for x in range(1, maze_size.x):
		var p0: Vector2 = Vector2()
		p0.x = x * cell_size + render_rect.position.x
		p0.y = render_rect.position.y
		var p1: Vector2 = p0
		p1.y = render_rect.size.y + render_rect.position.y
		%game_base_maze.draw_line(p0, p1, RETICLE_COLOR, RETICLE_WIDTH)
	
	for y in range(1, maze_size.y):
		var p0: Vector2 = Vector2()
		p0.y = y * cell_size + render_rect.position.y
		p0.x = render_rect.position.x
		var p1: Vector2 = p0
		p1.x = render_rect.size.x + render_rect.position.x
		%game_base_maze.draw_line(p0, p1, RETICLE_COLOR, RETICLE_WIDTH)


#region Position mapping
func maze_pos_to_game_position(maze_pos: Vector2i) -> Vector2:
	var pos_snapped: Vector2 = Vector2(maze_pos)
	pos_snapped *= cell_size
	pos_snapped += Vector2.ONE * cell_size / 2.0
	pos_snapped += render_rect.position
	return pos_snapped


func game_pos_to_maze_pos(game_click_pos: Vector2) -> Vector2i:
	var in_rect_pos: Vector2 = game_click_pos - render_rect.position
	in_rect_pos /= cell_size
	
	return Vector2i(in_rect_pos)
#endregion
