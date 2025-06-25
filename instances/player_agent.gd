extends Agent
class_name PlayerAgent

@onready var lb_name: Label = %lb_name
@onready var line_preview_path: Line2D = %line_preview_path


var user: TwitchUser
var user_profile_pic: ImageTexture

var score_catch: int = 0:
	set(val):
		score_catch = val
		score_updated.emit()
var score_assist: int = 0:
	set(val):
		score_assist = val
		score_updated.emit()
signal score_updated()

var tw_message: Tween
var message_font: Font


func _ready() -> void:
	set_process(false)
	line_preview_path.clear_points()
	line_preview_path.hide()
	line_preview_path.reparent(pnl_maze.lines)
	line_preview_path.position = Vector2.ZERO
	message_font = %lb_text_bubble.get_theme_font(&"normal_font")
	%lb_text_bubble.hide()
	if not user: return
	sprite.texture = user_profile_pic
	lb_name.text = user.display_name
	
	super()
	move_queue_updated.connect(func(): set_process(true))
	l.enabled = true
	#l.debug = true


func _process(_delta: float) -> void:
	line_preview_path.clear_points()
	if _move_queue.is_empty():
		line_preview_path.hide()
		set_process(false)
		return
	
	line_preview_path.show()
	var index_path: Array[Vector2i] = [maze_pos]
	for dir: Vector2i in _move_queue:
		var next_p: Vector2i = index_path.back() + dir
		index_path.append(next_p)
	
	for i: int in range(index_path.size()-1, -1, -1):
		var p_index: Vector2i = index_path[i]
		var p: Vector2 = pnl_maze.maze_pos_to_game_position(p_index)
		line_preview_path.add_point(p)
	line_preview_path.add_point(position)


func update() -> void:
	await super()
	await get_tree().process_frame
	lb_name.position.x = -lb_name.size.x/2.0
	lb_name.position.y = sprite.texture.get_size().y * sprite.scale.y/2.0 + 8 #px offset


func do_next_move() -> bool:
	var next_map_pos: Vector2i = maze_pos + _move_queue.front()
	var duration: float = STEP_SPEED_PLAYER
	var players_with_moves: int = game.get_players_count_with_moves()
	if players_with_moves:
		duration /= players_with_moves
	if !is_maze(next_map_pos):
		_move_queue.pop_front()
		#await get_tree().create_timer(duration).timeout
		move_finished.emit()
		return false
	
	maze_pos = next_map_pos
	_move_queue.pop_front()
	
	var next_game_pos: Vector2 = pnl_maze.maze_pos_to_game_position(next_map_pos)
	var tw: Tween = create_tween()
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, ^"position", next_game_pos, duration)
	await tw.finished
	move_finished.emit()
	return true


func popup_message(text: String) -> void:
	if tw_message:
		tw_message.kill()
	
	%lb_text_bubble.show()
	%lb_text_bubble.text = text
	%lb_text_bubble.size.y = 0.0
	%lb_text_bubble.self_modulate.a = 1 #TODO: remove
	%lb_text_bubble.modulate.a = 1 #TODO: remove
	%lb_text_bubble.visible_ratio = 0.0
	%lb_text_bubble.position.y = -(sprite.texture.get_size().y * sprite.scale.y/2.0 + 8) #px offset
	
	var display_duration: float = 2.0 + text.length() * 0.05 # seconds
	var font_size: float = %lb_text_bubble.get_theme_font_size(&"normal_font_size")
	var pnl: StyleBoxFlat = %lb_text_bubble.get_theme_stylebox(&"normal")
	var text_width: float = %lb_text_bubble.size.x - (pnl.content_margin_left + pnl.content_margin_right)
	var text_size: Vector2 = message_font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size
	)
	var pnl_final_size_y: float = text_size.y + (pnl.content_margin_top + pnl.content_margin_bottom)
	%lb_text_bubble.position.y -= pnl_final_size_y
	
	tw_message = create_tween()
	tw_message.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw_message.tween_property(%lb_text_bubble, ^"size:y", pnl_final_size_y, 0.2)
	tw_message.parallel().tween_property(%lb_text_bubble, ^"self_modulate:a", 0.75, 0.2)
	tw_message.parallel().tween_property(%lb_text_bubble, ^"visible_ratio", 1, 0.2).set_delay(0.1)
	tw_message.tween_interval(display_duration)
	tw_message.tween_callback(hide_message_bubble)


func hide_message_bubble() -> void:
	if tw_message:
		tw_message.kill()
	tw_message = create_tween()
	tw_message.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw_message.tween_property(%lb_text_bubble, ^"size:y", 0, 0.2)
	tw_message.parallel().tween_property(%lb_text_bubble, ^"self_modulate:a", 0, 0.2)
	tw_message.tween_callback(%lb_text_bubble.hide)
