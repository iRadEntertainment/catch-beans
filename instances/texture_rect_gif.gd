@tool
extends Control
class_name TextureRectGif


@export var sprite_frames: SpriteFrames:
	set(val):
		sprite_frames = val
		if _animated_sprite:
			_animated_sprite.sprite_frames = sprite_frames
		_sprite_max_size = _get_sprite_max_size()
		update()

@export var expand_mode: TextureRect.ExpandMode = TextureRect.ExpandMode.EXPAND_KEEP_SIZE:
	set(val):
		expand_mode = val
		update()
@export var stretch_mode: TextureRect.StretchMode = TextureRect.StretchMode.STRETCH_SCALE:
	set(val):
		stretch_mode = val
		update()

@export var play: bool = true:
	set(val):
		play = val
		if _animated_sprite:
			if _animated_sprite.is_playing() and !play:
				_animated_sprite.stop()
			elif !_animated_sprite.is_playing() and play:
				_animated_sprite.play()
@export var flip_h: bool = false:
	set(val):
		flip_h = val
		if _animated_sprite:
			_animated_sprite.flip_h = flip_h
@export var flip_v: bool = false:
	set(val):
		flip_v = val
		if _animated_sprite:
			_animated_sprite.flip_v = flip_v

var _animated_sprite: AnimatedSprite2D
var _sprite_rect: Rect2
var _sprite_max_size: Vector2



func _ready() -> void:
	_animated_sprite = AnimatedSprite2D.new()
	_animated_sprite.centered = false
	add_child(_animated_sprite)
	sprite_frames = sprite_frames
	
	visibility_changed.connect(update)
	resized.connect(update)
	play = play


func update() -> void:
	if !is_node_ready(): return
	_update_custom_min_size()
	await _update_sprite_rect()
	_update_sprite_position_and_scale()


func _get_sprite_max_size() -> Vector2:
	var _dimensions: Vector2 = Vector2.ZERO
	if not sprite_frames:
		return _dimensions
	
	for frame_num: int in sprite_frames.get_frame_count(&"default"):
		var tex: Texture2D = sprite_frames.get_frame_texture(&"default", frame_num)
		_dimensions.x = max(_dimensions.x, tex.get_size().x)
		_dimensions.y = max(_dimensions.y, tex.get_size().y)
	
	return _dimensions


func _update_custom_min_size() -> void:
	match expand_mode:
		TextureRect.ExpandMode.EXPAND_KEEP_SIZE:
			custom_minimum_size = _sprite_max_size
		TextureRect.ExpandMode.EXPAND_IGNORE_SIZE:
			custom_minimum_size = Vector2()
		TextureRect.ExpandMode.EXPAND_FIT_HEIGHT:
			custom_minimum_size = Vector2(0, _sprite_max_size.y)
		TextureRect.ExpandMode.EXPAND_FIT_HEIGHT_PROPORTIONAL:
			custom_minimum_size = Vector2(0, _sprite_max_size.y)
		TextureRect.ExpandMode.EXPAND_FIT_WIDTH:
			custom_minimum_size = Vector2(_sprite_max_size.x, 0)
		TextureRect.ExpandMode.EXPAND_FIT_WIDTH_PROPORTIONAL:
			custom_minimum_size = Vector2(_sprite_max_size.x, 0)


func _update_sprite_rect() -> void:
	await get_tree().process_frame
	
	_sprite_rect = Rect2()
	var is_sprite_taller: bool = false
	var control_ratio: float = 1.0
	var sprite_ratio: float = 1.0
	if stretch_mode in [
		TextureRect.StretchMode.STRETCH_KEEP_ASPECT,
		TextureRect.StretchMode.STRETCH_KEEP_ASPECT_CENTERED,
		TextureRect.StretchMode.STRETCH_KEEP_ASPECT_COVERED,
			]:
		control_ratio = size.x/size.y
		sprite_ratio = _sprite_max_size.x/_sprite_max_size.y
		is_sprite_taller = control_ratio > sprite_ratio
		
		if !is_sprite_taller:
			_sprite_rect.size.x = size.x
			_sprite_rect.size.y = size.x / sprite_ratio
		else:
			_sprite_rect.size.y = size.y
			_sprite_rect.size.x = size.y / sprite_ratio
	
	match stretch_mode:
		TextureRect.StretchMode.STRETCH_SCALE:
			_sprite_rect.size = size
		TextureRect.StretchMode.STRETCH_TILE:
			_sprite_rect.size = size
		TextureRect.StretchMode.STRETCH_KEEP:
			_sprite_rect.size = _sprite_max_size
		TextureRect.StretchMode.STRETCH_KEEP_CENTERED:
			_sprite_rect.position = (size - _sprite_max_size)/2.0
			_sprite_rect.size = _sprite_max_size
		TextureRect.StretchMode.STRETCH_KEEP_ASPECT:
			pass
		TextureRect.StretchMode.STRETCH_KEEP_ASPECT_CENTERED:
			_sprite_rect.position = (size - _sprite_rect.size)/2.0
		TextureRect.StretchMode.STRETCH_KEEP_ASPECT_COVERED:
			_sprite_rect.size.x = size.x if is_sprite_taller else _sprite_max_size.x
			_sprite_rect.size.y = size.y if !is_sprite_taller else _sprite_max_size.y
			_sprite_rect.position = (size - _sprite_rect.size)/2.0


func _update_sprite_position_and_scale() -> void:
	_animated_sprite.position = _sprite_rect.position
	_animated_sprite.scale.x = _sprite_rect.size.x / _sprite_max_size.x
	_animated_sprite.scale.y = _sprite_rect.size.y / _sprite_max_size.y
