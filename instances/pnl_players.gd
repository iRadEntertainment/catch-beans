extends PanelContainer
class_name GamePlayers


@onready var vb_list_players: VBoxContainer = %vb_list_players



func add_player_agent(player: PlayerAgent) -> void:
	var new_player_entry: PlayerEntry = PlayerEntry.from_agent(player)
	%vb_list_players.add_child(new_player_entry)


func remove_player(player: PlayerAgent) -> void:
	for entry: PlayerEntry in %vb_list_players.get_children():
		if entry.agent == player:
			entry.queue_free()


func clear() -> void:
	for entry: PlayerEntry in %vb_list_players.get_children():
		entry.queue_free()
