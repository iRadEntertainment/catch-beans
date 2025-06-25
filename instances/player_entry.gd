extends PanelContainer
class_name PlayerEntry

const DIR_ICONS = {
	Vector2i.UP: preload("res://theme/UI/arrow-up-circle-fill.png"),
	Vector2i.DOWN: preload("res://theme/UI/arrow-down-circle-fill.png"),
	Vector2i.LEFT: preload("res://theme/UI/arrow-left-circle-fill.png"),
	Vector2i.RIGHT: preload("res://theme/UI/arrow-right-circle-fill.png"),
}
const DIR_ARROW_SIZE = 24 #px

var agent: PlayerAgent



func _ready() -> void:
	#clear_dirs()
	if agent:
		#agent.move_queue_updated.connect(_on_agent_move_queue_updated) # TODO: remove this
		#agent.move_finished.connect(update_dirs)
		agent.score_updated.connect(update_scores)
		update()
		update_scores()


func update() -> void:
	if not agent: return
	if not agent.is_node_ready():
		await agent.ready
	%tex_profile_pic.texture = agent.sprite.texture
	%lb_display_name.text = agent.user.display_name


func update_scores() -> void:
	%lb_catch.text = str(agent.score_catch)
	%lb_assist.text = str(agent.score_assist)


func remove_last_dir() -> void:
	if %cnt_dirs.get_child_count() < 1:
		return
	

#TODO: check if keep or not
#func update_dirs() -> void:
	#clear_dirs()
	#for dir: Vector2i in agent._move_queue:
		#var new_dir_texture := TextureRect.new()
		#new_dir_texture.name = "dir%02d" % agent.moves_left()
		#new_dir_texture.texture = DIR_ICONS.get(dir)
		#new_dir_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		#new_dir_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		#new_dir_texture.custom_minimum_size = Vector2.ONE * DIR_ARROW_SIZE
		#%cnt_dirs.add_child(new_dir_texture)
#
#
#func clear_dirs() -> void:
	#for child: Control in %cnt_dirs.get_children():
		#child.free()


#func _on_agent_move_queue_updated() -> void:
	#update_dirs()


static func from_agent(_agent: PlayerAgent) -> PlayerEntry:
	const PACK = preload("res://instances/player_entry.tscn")
	var new_entry: PlayerEntry = PACK.instantiate()
	new_entry.agent = _agent
	return new_entry
