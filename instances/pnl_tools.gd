extends PanelContainer
class_name GameTools


var game: Game

signal generate_maze_pressed(maze_setting: MazeSettings)


func update_from_current_settings() -> void:
	%ln_seed.text = game.maze_settings.maze_seed
	%sp_x.value = game.maze_settings.maze_size.x
	%sp_y.value = game.maze_settings.maze_size.y
	%sl_treshold.value = game.maze_settings.noise_threshold
	%sl_resolution.value = game.maze_settings.noise_resolution
	

func _on_btn_generate_pressed() -> void:
	var settings := MazeSettings.new()
	settings.maze_seed = %ln_seed.text
	settings.maze_size = Vector2i()
	settings.maze_size.x = int(%sp_x.value)
	settings.maze_size.y = int(%sp_y.value)
	settings.noise_threshold = %sl_treshold.value
	settings.noise_resolution = %sl_resolution.value
	generate_maze_pressed.emit(settings)


func _on_btn_git_pressed() -> void:
	Twitch.chat("Check the repository of this game here on github: https://github.com/iRadEntertainment/catch-beans")
	OS.shell_open("https://github.com/iRadEntertainment/catch-beans")
