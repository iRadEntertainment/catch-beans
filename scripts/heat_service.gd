extends Node
## Can handle heat subscription events.
## [code]{
##	 type: "click",      // Message type, currently either "click" or "system".
##	 id: "U97032862",    // User ID for viewer, which may be Anonymous, Opaque or a real Twitch user ID.
##	 x: "0.354",         // Normalized X coordinate.
##	 y: "0.736"          // Normalized Y coordinate.
## }[/code]

class_name HeatService

@export var broadcaster: TwitchUser
#@export var user_service: UserService

@export var cooldown: float = 0
var viewport: Viewport

var l: TwitchLogger = TwitchLogger.new("Heat")
var cooldowns: Dictionary
var client = WebsocketClient.new()
var anon_usernames: PackedStringArray
var anon_ids: Dictionary = {}


signal input_event(event: HeatInputEvent)


func _ready() -> void:
	viewport = get_viewport()
	_load_rand_username()
	l.enabled = true

	var id: String = broadcaster.id
	client.message_received.connect(_on_message)
	client.connection_url = 'wss://heat-api.j38.net/channel/%s' % id
	add_child(client)
	client.open_connection()


func _load_rand_username():
	anon_usernames = FileAccess.get_file_as_string("res://service/heat/annon_username.txt").split("\n")


func _click(
			position: Vector2,
			user_id: String,
			username: String,
			is_anon: bool,
			color: Color,
		) -> void:
	if viewport == null: return
	#l.i("Click received %s - %s" % [position, name])

	var event: HeatInputEvent = HeatInputEvent.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.user_id = user_id
	event.name = username
	event.is_anon = is_anon
	event.color = color
	viewport.push_input(event, true)

	event = HeatInputEvent.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.user_id = user_id
	event.name = username
	event.is_anon = is_anon
	event.color = color
	viewport.push_input(event, true)
	input_event.emit(event)


func _on_message(data: PackedByteArray) -> void:
	var msg = JSON.parse_string(data.get_string_from_utf8())
	if msg.type == 'system':
		#l.i(msg.to_string())
		return

	if cooldowns.has(msg.id) && cooldowns[msg.id] > Time.get_unix_time_from_system(): return
	cooldowns[msg.id] = Time.get_unix_time_from_system() + cooldown
	var local_pos: Vector2 = Vector2(float(msg.x), float(msg.y))
	var pos: Vector2       = local_pos
	#var pos: Vector2       = Vector2(get_viewport().size) * local_pos
	var user_id: String = msg['id']
	if user_id.begins_with("A"):
		if not anon_ids.has(user_id):
			anon_ids[user_id] = anon_usernames[randi() % anon_usernames.size()]
		var random_name: String = anon_ids[user_id]
		var color: Color = Color.from_hsv(randf(), .5, .5)
		var username: String = "%s (Anon)" % random_name
		_click(pos, user_id, username, true, color)
		l.i("Click received ID (%s) - %s @ %s" % [user_id, username, pos])
		return
	if user_id.begins_with("U"):
		if not anon_ids.has(user_id):
			anon_ids[user_id] = anon_usernames[randi() % anon_usernames.size()]
		var random_name: String = anon_ids[user_id]
		var color: Color = Color.from_hsv(randf(), .7, .7)
		var username: String = "%s (Unverified)" % random_name
		_click(pos, user_id, username, true, color)
		l.i("Click received ID (%s) - %s @ %s" % [user_id, username, pos])
		return

	#var user: DBViewer = await user_service.get_user(user_id)
	#_click(pos, user_id, user.username, Color.from_string(user.color, Color.WHEAT))
	l.i("Click received ID (%s) - %s @ %s" % [user_id, "VERIFIED", pos])
	_click(pos, user_id, "", false, Color.WHEAT)
