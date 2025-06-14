extends Agent
class_name PlayerAgent

@onready var lb_name: Label = %lb_name
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


func _ready() -> void:
	if not user: return
	sprite.texture = user_profile_pic
	lb_name.text = user.display_name
	
	super()
	l.enabled = true
	#l.debug = true


func update() -> void:
	super()
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
