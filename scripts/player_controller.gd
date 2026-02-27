extends Node
## Human player controller — reads input and drives the player character.
## Uses buffered input: flags are SET here but only CLEARED by the player after consumption.

var player: CharacterBody3D = null

func _process(_delta: float) -> void:
	if player == null:
		return
	
	# Movement (WASD / Left Stick) — continuous, set every frame
	var move_input = Vector2.ZERO
	move_input.x = Input.get_axis("move_left", "move_right")
	move_input.y = Input.get_axis("move_up", "move_down")
	player.input_move = move_input
	
	# Aim (Arrow Keys / Right Stick) — continuous
	var aim_input = Vector2.ZERO
	aim_input.x = Input.get_axis("aim_left", "aim_right")
	aim_input.y = Input.get_axis("aim_up", "aim_down")
	player.input_aim = aim_input
	
	# Sprint — continuous
	player.input_sprint = Input.is_action_pressed("action_sprint")
	
	# --- Buffered action inputs (only SET, never cleared here) ---
	# These get cleared by the player script after being consumed
	
	if Input.is_action_just_pressed("action_pass"):
		if player.has_ball:
			player.input_pass = true
		else:
			player.input_call_pass = true
	
	if Input.is_action_just_pressed("action_shoot"):
		if player.has_ball:
			player.input_shoot = true
		else:
			player.input_tackle = true
			player.input_tackle = true
			player.input_jump = true
	
	if Input.is_key_pressed(KEY_L):
		player.input_kiss = true
