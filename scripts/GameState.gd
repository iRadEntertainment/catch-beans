extends Resource
class_name GameState



var game: Game
var settings: MazeSettings
var maze_data: MazeData:
	get(): return game.maze_data

@export var btm_players: BitMap
@export var btm_bunnies: BitMap
@export var btm_players_affect: BitMap
@export var btm_bunnies_affect: BitMap

var player_agents: Dictionary[int, PlayerAgent] = {} # {user_id: PlayerAgent}
var bunnies_agents: Array[BunnyAgent] = []
var player_movement_processing: bool = false
var checking_ids: Array[int] = []

enum State{STOPPED, AWAITING_PLAYERS, STARTING, STARTED, CLOSING}
var state: State = State.STOPPED

var level: int = 1
var bunnies_left: int:
	get(): return bunnies_agents.size()


signal game_state_changed(state: State)
signal level_win
signal level_lose


func _init(_game: Game) -> void:
	game = _game
	create_btms()


func clear() -> void:
	create_btms()
	player_agents.clear()
	bunnies_agents.clear()


func create_btms() -> void:
	btm_players = BitMap.new()
	btm_players.create(maze_data.maze_size)
	btm_bunnies = BitMap.new()
	btm_bunnies.create(maze_data.maze_size)
	btm_players_affect = BitMap.new()
	btm_players_affect.create(maze_data.maze_size)
	btm_bunnies_affect = BitMap.new()
	btm_bunnies_affect.create(maze_data.maze_size)


func _update_btm_players() -> void:
	var btm_rect: Rect2i = Rect2i(Vector2i.ZERO, maze_data.maze_size)
	btm_players.set_bit_rect(btm_rect, false)
	btm_players_affect.set_bit_rect(btm_rect, false)
	for player: PlayerAgent in player_agents.values():
		btm_players.set_bitv(player.maze_pos, true)
		btm_players_affect.set_bitv(player.maze_pos, true)
		for p: Vector2i in player.affect_kernel:
			btm_players_affect.set_bitv(p, true)


func _update_btm_bunnies() -> void:
	var btm_rect: Rect2i = Rect2i(Vector2i.ZERO, maze_data.maze_size)
	btm_bunnies.set_bit_rect(btm_rect, false)
	btm_bunnies_affect.set_bit_rect(btm_rect, false)
	for bunny: BunnyAgent in bunnies_agents:
		btm_bunnies.set_bitv(bunny.maze_pos, true)
		btm_bunnies_affect.set_bitv(bunny.maze_pos, true)
		for p: Vector2i in bunny.affect_kernel:
			btm_bunnies_affect.set_bitv(p, true)


#region Agents management
func add_player_agent(user: TwitchUser, maze_pos: Vector2i) -> PlayerAgent:
	const player_agent_pack = preload("res://instances/player_agent.tscn")
	var new_player_agent = player_agent_pack.instantiate()
	new_player_agent.name = user.login
	new_player_agent.game = game
	new_player_agent.pnl_maze = game.pnl_maze
	new_player_agent.maze_pos = maze_pos
	new_player_agent.user = user
	new_player_agent.user_profile_pic = await Twitch.load_profile_image(user)
	new_player_agent.maze_pos_updated.connect(_update_btm_players)
	
	player_agents[int(user.id)] = new_player_agent
	btm_players.set_bitv(maze_pos, true)
	return new_player_agent


func remove_player(player: PlayerAgent) -> void:
	player_agents.erase( int(player.user.id) )
	player.queue_free()
	_update_btm_players()


func add_bunny_agent(maze_pos: Vector2i) -> BunnyAgent:
	const bunny_agent_pack = preload("res://instances/bunny_agent.tscn")
	var new_bunny_agent = bunny_agent_pack.instantiate()
	new_bunny_agent.name = "bunny%d" % bunnies_agents.size()
	new_bunny_agent.game = game
	new_bunny_agent.pnl_maze = game.pnl_maze
	new_bunny_agent.maze_pos = maze_pos
	new_bunny_agent.maze_pos_updated.connect(_update_btm_bunnies)
	
	bunnies_agents.append(new_bunny_agent)
	btm_bunnies.set_bitv(maze_pos, true)
	
	return new_bunny_agent


func remove_bunny(bunny: BunnyAgent) -> void:
	bunnies_agents.erase(bunny)
	bunny.queue_free()
	_update_btm_bunnies()



func get_agent_by_user_id(_user_id: int) -> PlayerAgent:
	return player_agents.get(_user_id, null)


func get_players_in_range(at_pos: Vector2i) -> Array[PlayerAgent]:
	var found: Array[PlayerAgent] = []
	for player: PlayerAgent in player_agents.values():
		if at_pos in player.affect_kernel:
			found.append(player)
	return found


func get_players_at_pos(_maze_pos: Vector2i) -> Array[PlayerAgent]:
	var found: Array[PlayerAgent] = []
	for player: PlayerAgent in player_agents.values():
		if player.maze_pos == _maze_pos:
			found.append(player)
	return found


func get_bunnies_at_pos(_maze_pos: Vector2i) -> Array[BunnyAgent]:
	var found: Array[BunnyAgent] = []
	for bunny: BunnyAgent in bunnies_agents:
		if bunny.maze_pos == _maze_pos:
			found.append(bunny)
	return found


func are_player_move_queues_empty() -> bool:
	for agent: PlayerAgent in player_agents.values():
		if agent.has_next_move():
			return false
	return true


func are_bunnies_move_queues_empty() -> bool:
	for agent: BunnyAgent in bunnies_agents:
		if agent.has_next_move():
			return false
	return true


func is_any_player_at_pos(_maze_pos: Vector2i) -> bool:
	for player: PlayerAgent in player_agents.values():
		if player.maze_pos == _maze_pos:
			return true
	return false


func is_any_bunny_at_pos(_maze_pos: Vector2i) -> bool:
	for bunny: BunnyAgent in bunnies_agents:
		if bunny.maze_pos == _maze_pos:
			return true
	return false


func is_any_player_reaching_pos(_maze_pos: Vector2i) -> bool:
	for player: PlayerAgent in player_agents.values():
		if _maze_pos in player.affect_kernel:
			return true
	return false


func is_cell_free(pos: Vector2i) -> bool:
	if not maze_data.btm_maze.get_bitv(pos):
		return false
	if btm_players.get_bitv(pos): return false
	if btm_bunnies.get_bitv(pos): return false
	return true


func is_cell_valid_for_bunny(pos: Vector2i) -> bool:
	if not is_cell_free(pos): return false
	return true


func pick_random_available_player_spot() -> Vector2i:
	return maze_data.pick_random_maze_point()


func pick_random_available_bunny_spot() -> Vector2i:
	var p: Vector2i = maze_data.pick_random_maze_point()
	var is_valid: bool = !maze_data.btm_dead_ends_paths.get_bitv(p)
	while not is_valid:
		p = maze_data.pick_random_maze_point()
		is_valid = !maze_data.btm_dead_ends_paths.get_bitv(p)
	return p
