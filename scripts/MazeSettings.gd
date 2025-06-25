@tool
extends Resource
class_name MazeSettings

enum Sizes {VERY_SMALL, SMALL, MEDIUM, LARGE, VERY_LAGE, BIG, HUGE}
const PRESET_SIZES = {
	Sizes.VERY_SMALL: Vector2i(19, 13),
	Sizes.SMALL: Vector2i(23, 15),
	Sizes.MEDIUM: Vector2i(27, 19),
	Sizes.LARGE: Vector2i(31, 23),
	Sizes.VERY_LAGE: Vector2i(37, 27),
	Sizes.BIG: Vector2i(43, 33),
	Sizes.HUGE: Vector2i(53, 41)
}


@export var maze_size_preset: Sizes = Sizes.VERY_SMALL:
	set(val):
		maze_size_preset = val
		maze_size = PRESET_SIZES[maze_size_preset]
@export var maze_size: Vector2i:
	set(val):
		maze_size = val
		maze_size_updated.emit()
@export var maze_seed: String:
	set(val):
		maze_seed = val
		maze_seed_updated.emit(maze_seed)
@export_range(0.0, 1.0, 0.001) var noise_threshold: float = 0.6
@export var noise_resolution: float = 15.0
@export_range(1, 25, 1) var bunnies_count = 8
@export_range(60.0, 600.0, 1.0) var level_time: float = 60.0


signal maze_size_updated
signal maze_seed_updated(maze_seed: String)
