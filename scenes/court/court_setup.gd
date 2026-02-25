extends Node3D
## Court Setup — runs at scene start to wire up controllers to players.

func _ready() -> void:
	# Wait two frames for all nodes to be ready and in groups
	await get_tree().process_frame
	await get_tree().process_frame
	_assign_controllers()

func _assign_controllers() -> void:
	var parent = get_parent()
	
	# Collect all players, split by human vs AI
	var human_player: CharacterBody3D = null
	var ai_players: Array = []
	
	for node in get_tree().get_nodes_in_group("players"):
		if "is_human" in node and node.is_human:
			human_player = node
		else:
			ai_players.append(node)
	
	# Find the human controller and all AI controllers
	var human_controller: Node = null
	var ai_controllers: Array = []
	
	for child in parent.get_children():
		var script = child.get_script()
		if script == null:
			continue
		var path: String = script.resource_path
		if path.ends_with("player_controller.gd"):
			human_controller = child
		elif path.ends_with("ai_controller.gd"):
			ai_controllers.append(child)
	
	# Assign human controller
	if human_controller and human_player:
		human_controller.player = human_player
		print("[CourtSetup] Human controller -> ", human_player.name)
	else:
		print("[CourtSetup] WARNING: Could not find human controller or human player!")
	
	# Assign AI controllers to AI players 1:1
	for i in range(min(ai_controllers.size(), ai_players.size())):
		ai_controllers[i].player = ai_players[i]
		print("[CourtSetup] AI controller %d -> %s" % [i, ai_players[i].name])
	
	print("[CourtSetup] Assignment complete: 1 human + %d AI players" % ai_players.size())
