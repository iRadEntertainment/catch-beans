extends Resource
class_name MazeSettings

@export var maze_size: Vector2i
@export var maze_seed: String
@export_range(0.0, 1.0, 0.001) var noise_threshold: float = 0.6
@export var noise_resolution: float = 15.0
@export_range(1, 25, 1) var bunnies_count = 8
