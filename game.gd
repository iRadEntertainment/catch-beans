@tool
extends PanelContainer
class_name Game


@export var maze_settings: MazeSettings
@warning_ignore("unused_private_class_variable")
@export_tool_button("Generate", "Button") var _do_it = do_it
@export var maze_data: MazeData

@onready var pnl_maze: GameMaze = %pnl_maze
@onready var pnl_tools: GameTools = %pnl_tools
@onready var pnl_players: GamePlayers = %pnl_players


var state: GameState
var l: TwitchLogger = TwitchLogger.new("Game")

# Agent management

signal bunnies_moves_finished

# debug
var last_click: Vector2


# i was here # konrad
func _ready() -> void:
	pnl_maze.game = self
	l.enabled = true
	l.debug = true
	if Engine.is_editor_hint():
		if maze_settings:
			maze_settings.maze_size_updated.connect(reset)
		return
	
	# in game
	setup_twitcher()
	pnl_tools.generate_maze_pressed.connect(_on_generate_maze_pressed)
	pnl_tools.game = self
	pnl_tools.update_from_current_settings()
	reset()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_released():
			return
		if event.keycode in [KEY_UP, KEY_W]: parse_chat_movement(Globals.IRAD_ID, ["w"])
		elif event.keycode in [KEY_DOWN, KEY_S]: parse_chat_movement(Globals.IRAD_ID, ["s"])
		elif event.keycode in [KEY_LEFT, KEY_A]: parse_chat_movement(Globals.IRAD_ID, ["a"])
		elif event.keycode in [KEY_RIGHT, KEY_D]: parse_chat_movement(Globals.IRAD_ID, ["d"])


#region Setup
func do_it() -> void:
	if not is_node_ready(): return
	if not Engine.is_editor_hint():
		l.w("Only available in editor")
		return
	generate_maze()


func reset() -> void:
	l.i("Reset game")
	clear()
	generate_maze()
	state = GameState.new(self)
	add_bunnies()


func generate_maze() -> void:
	l.i("Generating maze")
	maze_data = MazeGen.generate_maze(maze_settings)
	maze_data.regen_btms_dead_end()
	pnl_maze.render_maze()
	#await get_tree().process_frame


func setup_twitcher() -> void:
	Twitch.setup()
	add_commands()


func add_commands() -> void:
	Twitch.add_command("join", _on_chat_user_join)
	Twitch.add_command("leave", _on_chat_user_leave)
	Twitch.add_command("cat", _on_chat_user_cat)
	Twitch.add_command("new", _on_chat_new)
#endregion


#region Agents Manager
func add_player_agent(user: TwitchUser, maze_pos: Vector2i) -> void:
	if state.player_agents.has(int(user.id)):
		l.w("Add User (%s) already in game state" % user.id)
		return
	var new_agent: PlayerAgent = await state.add_player_agent(user, maze_pos)
	new_agent.move_queue_updated.connect(get_next_agent_to_move)
	pnl_players.add_player_agent(new_agent)
	pnl_maze.add_player_agent(new_agent)


func add_bunny(_maze_pos: Vector2i) -> void:
	var new_agent: BunnyAgent = state.add_bunny_agent(_maze_pos)
	new_agent.move_queue_finished.connect(_on_bunny_move_queue_finished)
	pnl_maze.add_bunny_agent(new_agent)


func add_bunnies() -> void:
	for i: int in maze_settings.bunnies_count:
		var p: Vector2i = state.pick_random_available_bunny_spot()
		add_bunny(p)


func clear() -> void:
	if state:
		state.clear()
		state.player_movement_processing = false
	pnl_players.clear()
	pnl_maze.clear()


func get_next_agent_to_move() -> void:
	# if still processing skipt new input
	if state.player_movement_processing:
		return
	
	state.player_movement_processing = true
	for agent: PlayerAgent in state.player_agents.values():
		# await for bunnies to finish their moves
		if not state.are_bunnies_move_queues_empty():
			await bunnies_moves_finished
		
		if agent.has_next_move():
			var next_pos: Vector2i = agent.get_next_move()
			await agent.do_next_move()
			check_and_move_bunnies(next_pos)
	
	state.player_movement_processing = false
	
	# loop for new movements if not done
	if not state.are_player_move_queues_empty():
		get_next_agent_to_move()


func get_players_count_with_moves() -> int:
	var count: int = 0
	for agent: PlayerAgent in state.player_agents.values():
		if agent.has_next_move():
			count += 1
	return count


func check_and_move_bunnies(check_pos: Vector2i) -> void:
	var players_at_pos = state.get_players_at_pos(check_pos)
	
	var player: PlayerAgent
	
	if players_at_pos:
		player = state.get_players_at_pos(check_pos).front()
	
	if player:
		var bunnies_catched: Array[BunnyAgent] = state.get_bunnies_at_pos(check_pos)
		for bunny: BunnyAgent in bunnies_catched:
			player.score_catch += 1
			var assist_players: Array[PlayerAgent] = state.get_players_in_range(check_pos)
			for assist_pl: PlayerAgent in assist_players:
				assist_pl.score_assist += 1
			state.remove_bunny(bunny)
	
	for bunny: BunnyAgent in state.bunnies_agents:
		if bunny.is_queued_for_deletion():
			continue
		if bunny.should_flee_from(check_pos):
			bunny.flee(check_pos)


func _on_bunny_move_queue_finished(_bunny_agent: BunnyAgent) -> void:
	if state.are_bunnies_move_queues_empty():
		bunnies_moves_finished.emit()
#endregion


#region Signals
func _on_generate_maze_pressed(_settings: MazeSettings) -> void:
	maze_settings = _settings
	reset()


func _on_heat_service_input_event(event: HeatInputEvent) -> void:
	last_click = heat_pos_to_window_pos(event.position)
	check_user_click(
		int(event.user_id),
		window_pos_to_maze_pos(last_click),
		event.is_anon
	)
	%debug_overlay.queue_redraw()


func _on_chat_user_join(
			_from_username: String,
			info: TwitchCommandInfo,
			_args: PackedStringArray
		) -> void:
	var user_id: int = int(info.original_message.chatter_user_id)
	if not state.player_agents.has(user_id):
		var user: TwitchUser = await Twitch.get_user_by_id(str(user_id))
		add_player_agent(user, state.pick_random_available_player_spot())


func _on_chat_user_leave(
			from_username: String,
			_info: TwitchCommandInfo,
			_args: PackedStringArray
		) -> void:
	Twitch.chat("%s you can NEVER leave!" % from_username)


# Ategon was here
func _on_chat_user_cat(
			_from_username: String,
			_info: TwitchCommandInfo,
			_args: PackedStringArray
		) -> void:
	Twitch.chat("🐈")


func _on_chat_new(
			_from_username: String,
			_info: TwitchCommandInfo,
			args: PackedStringArray
		) -> void:
	var maze_seed: String = str(args[0])
	maze_settings.maze_seed = maze_seed
	reset()


func _on_twitch_chat_message_received(t_message: TwitchChatMessage) -> void:
	var user_id: int = int(t_message.chatter_user_id)
	if !state.player_agents.has(user_id):
		return
	var player: PlayerAgent = state.player_agents[user_id]
	var message: String = (t_message.message.text).strip_edges()
	if message.begins_with("!"):
		var unparsed_dir: PackedStringArray = message.to_lower().split()
		parse_chat_movement(user_id, unparsed_dir)
	else:
		player.popup_message(message)


func parse_chat_movement(user_id: int, unparsed_dir: PackedStringArray) -> void:
	var agent: PlayerAgent = state.get_agent_by_user_id(user_id)
	if not agent:
		printerr("Parsing movementes: No agent found with ID %s" % user_id)
		return
	var dirs: Array[Vector2i] = []
	var iter: int = 0
	for s: String in unparsed_dir:
		match s.to_lower():
			"w": dirs.append(Vector2i.UP)
			"s": dirs.append(Vector2i.DOWN)
			"a": dirs.append(Vector2i.LEFT)
			"d": dirs.append(Vector2i.RIGHT)
			"_": pass
		iter += 1
		if iter >= Agent.MAX_QUEUE:
			break
	
	agent.add_move_directions(dirs)


func _on_btn_generate_pressed() -> void:
	do_it()
#endregion


#region Game Twitch management
func get_user_by_user_id(_user_id: int) -> TwitchUser:
	var agent: PlayerAgent = state.get_agent_by_user_id(_user_id)
	if not agent: return null
	return agent.user


func check_user_click(_user_id: int, maze_pos: Vector2i, is_anon := false) -> void:
	if is_anon:
		return
	if !Rect2i(Vector2i.ZERO, maze_data.maze_size).has_point(maze_pos):
		return
	
	var agent: PlayerAgent = state.get_agent_by_user_id(_user_id)
	if not agent and !_user_id in state.checking_ids:
		state.checking_ids.append(_user_id)
		var user: TwitchUser = await Twitch.get_user_by_id(str(_user_id))
		if maze_data.is_maze(maze_pos):
			await add_player_agent(user, maze_pos)
		else:
			Twitch.chat("%s select an empty spot to join!" % user.display_name)
		state.checking_ids.erase(_user_id)
	elif agent and maze_data.btm_maze.get_bitv(maze_pos):
		agent.add_move_to(maze_pos)
#endregion


#region Position mapping
func heat_pos_to_window_pos(stream_click_u_pos: Vector2) -> Vector2:
	var screen_id: int = DisplayServer.window_get_current_screen(0)
	var current_screen_size: Vector2 = Vector2(DisplayServer.screen_get_size(screen_id))
	var global_click_pos: Vector2 = stream_click_u_pos * current_screen_size
	var screen_position: Vector2 = Vector2(DisplayServer.screen_get_position(screen_id))
	var window_pos: Vector2 = Vector2(DisplayServer.window_get_position()) - screen_position
	var final_pos: Vector2 = global_click_pos - window_pos
	return final_pos


func heat_pos_to_game_pos(stream_click_u_pos: Vector2) -> Vector2:
	var win_pos: Vector2 = heat_pos_to_window_pos(stream_click_u_pos)
	var maze_pos: Vector2i = window_pos_to_maze_pos(win_pos)
	return pnl_maze.maze_pos_to_game_position(maze_pos)


func window_pos_to_maze_pos(window_click_pos: Vector2) -> Vector2i:
	var game_click_pos: Vector2 = window_click_pos - pnl_maze.global_position
	return pnl_maze.game_pos_to_maze_pos(game_click_pos)


func maze_pos_to_window_position(maze_pos: Vector2i) -> Vector2:
	var pos_snapped: Vector2 = pnl_maze.maze_pos_to_game_position(maze_pos)
	return pos_snapped + pnl_maze.global_position
#endregion
