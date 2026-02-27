extends Node3D
## Power-Up — floating orb that grants a temporary buff on pickup.

enum PowerUpType { SPEED, ACCURACY, TACKLE, FREEZE }

var power_type: PowerUpType = PowerUpType.SPEED
var buff_duration: float = 8.0
var despawn_time: float = 12.0
var _timer: float = 0.0
var _collected: bool = false
var _main_mesh: MeshInstance3D = null
var _main_mat: StandardMaterial3D = null
var _second_mesh: MeshInstance3D = null
var _base_y: float = 0.0

var type_colors: Dictionary = {
	PowerUpType.SPEED: Color(0.1, 1.0, 0.3),
	PowerUpType.ACCURACY: Color(1.0, 0.8, 0.1), # Changed accuracy to gold/yellow
	PowerUpType.TACKLE: Color(1.0, 0.2, 0.2),
	PowerUpType.FREEZE: Color(0.3, 0.8, 1.0),   # Icy cyan
}

var type_names: Dictionary = {
	PowerUpType.SPEED: "speed",
	PowerUpType.ACCURACY: "accuracy",
	PowerUpType.TACKLE: "tackle",
	PowerUpType.FREEZE: "freeze",
}

func _ready() -> void:
	add_to_group("hazards")
	_base_y = position.y + 0.8
	_build_visuals()
	_build_trigger()

func _build_visuals() -> void:
	var color = type_colors.get(power_type, Color.WHITE)
	_main_mesh = MeshInstance3D.new()
	
	_main_mat = StandardMaterial3D.new()
	_main_mat.albedo_color = color
	_main_mat.emission_enabled = true
	_main_mat.emission = color
	_main_mat.emission_energy_multiplier = 3.0
	_main_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_main_mat.albedo_color.a = 0.8
	_main_mat.metallic = 0.5
	_main_mat.roughness = 0.2
	_main_mesh.material_override = _main_mat
	
	if power_type == PowerUpType.ACCURACY:
		# Accuracy: Spinning target ring with an arrow
		var ring = TorusMesh.new()
		ring.inner_radius = 0.35
		ring.outer_radius = 0.45
		_main_mesh.mesh = ring
		
		# Arrow inside
		_second_mesh = MeshInstance3D.new()
		var arrow = CylinderMesh.new()
		arrow.top_radius = 0.0
		arrow.bottom_radius = 0.15
		arrow.height = 0.35
		_second_mesh.mesh = arrow
		var arrow_mat = StandardMaterial3D.new()
		arrow_mat.albedo_color = Color.WHITE
		arrow_mat.emission_enabled = true
		arrow_mat.emission = Color.WHITE
		arrow_mat.emission_energy_multiplier = 4.0
		_second_mesh.material_override = arrow_mat
		_second_mesh.position.y = _base_y
		add_child(_second_mesh)
		
	elif power_type == PowerUpType.FREEZE:
		# Freeze: Icy diamond/crystal
		var crystal = CylinderMesh.new()
		crystal.top_radius = 0.0
		crystal.bottom_radius = 0.0
		crystal.height = 0.8
		crystal.radial_segments = 4 # 4-sided diamond
		_main_mesh.mesh = crystal
		
		# Inner core
		_second_mesh = MeshInstance3D.new()
		var core_mesh = CylinderMesh.new()
		core_mesh.top_radius = 0.0
		core_mesh.bottom_radius = 0.0
		core_mesh.height = 0.4
		core_mesh.radial_segments = 4
		_second_mesh.mesh = core_mesh
		var core_mat = StandardMaterial3D.new()
		core_mat.albedo_color = Color.WHITE
		core_mat.emission_enabled = true
		core_mat.emission = Color.WHITE
		core_mat.emission_energy_multiplier = 6.0
		_second_mesh.material_override = core_mat
		_second_mesh.position.y = _base_y
		add_child(_second_mesh)
		
	else:
		# Speed/Tackle: Glowing orb
		var sphere = SphereMesh.new()
		sphere.radius = 0.3
		sphere.height = 0.6
		_main_mesh.mesh = sphere
		
		# Inner glow core
		_second_mesh = MeshInstance3D.new()
		var core_mesh = SphereMesh.new()
		core_mesh.radius = 0.15
		core_mesh.height = 0.3
		_second_mesh.mesh = core_mesh
		var core_mat = StandardMaterial3D.new()
		core_mat.albedo_color = Color.WHITE
		core_mat.emission_enabled = true
		core_mat.emission = color
		core_mat.emission_energy_multiplier = 6.0
		_second_mesh.material_override = core_mat
		_second_mesh.position.y = _base_y
		add_child(_second_mesh)

	_main_mesh.position.y = _base_y
	add_child(_main_mesh)

func _build_trigger() -> void:
	var area = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # Players
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.2
	col.shape = shape
	col.position.y = _base_y
	area.add_child(col)
	area.body_entered.connect(_on_body_entered)
	area.area_entered.connect(_on_area_entered)
	add_child(area)

func _process(delta: float) -> void:
	if _collected:
		return
	
	_timer += delta
	
	# Float and bob
	if _main_mesh:
		_main_mesh.position.y = _base_y + sin(_timer * 2.0) * 0.15
		_main_mesh.rotation.y += delta * 1.5
	if _second_mesh:
		_second_mesh.position.y = _base_y + sin(_timer * 2.0) * 0.15
		_second_mesh.rotation.y -= delta * 2.0 # Spin opposite direction
	
	# Despawn timer
	if _timer >= despawn_time:
		# Fade out
		if _main_mat:
			var tween = create_tween()
			tween.tween_property(_main_mat, "albedo_color:a", 0.0, 0.5)
			tween.tween_callback(queue_free)
		else:
			queue_free()

func _on_body_entered(body: Node3D) -> void:
	_process_pickup(body)

func _on_area_entered(area: Area3D) -> void:
	if area.owner and area.owner.is_in_group("players"):
		_process_pickup(area.owner)

func _process_pickup(body: Node3D) -> void:
	if _collected:
		return
	if body.is_in_group("players") and body.has_method("apply_buff"):
		_collected = true
		
		if "team_index" in body and "roster_index" in body:
			var game_mgr = get_tree().get_first_node_in_group("game_manager")
			if game_mgr and game_mgr.has_method("record_stat"):
				game_mgr.record_stat(body.team_index, body.roster_index, "powerups", 1)
		
		# VFX
		var color = type_colors.get(power_type, Color.WHITE)
		if VFX:
			VFX.spawn_pickup_pop(global_position, color)
		
		if power_type == PowerUpType.FREEZE:
			# Freeze applies to all players on the OPPOSING team
			var opposing_team = 1 - body.team_index
			var all_players = get_tree().get_nodes_in_group("players")
			for p in all_players:
				if p.team_index == opposing_team and p.has_method("apply_buff"):
					p.apply_buff("freeze", buff_duration)
			
			# Icy Gaudy Message
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_gaudy_message"):
				hud.show_gaudy_message("FREEZE!", 2.5, "ice")
				
		else:
			# Normal buff applies to the player who picked it up
			var buff_name = type_names.get(power_type, "speed")
			body.apply_buff(buff_name, buff_duration)
			
			if power_type == PowerUpType.ACCURACY:
				var hud = get_tree().get_first_node_in_group("hud")
				if hud and hud.has_method("show_gaudy_message"):
					hud.show_gaudy_message("ACCURACY BONUS!", 2.0, "gold")
			elif power_type == PowerUpType.SPEED:
				var hud = get_tree().get_first_node_in_group("hud")
				if hud and hud.has_method("show_gaudy_message"):
					hud.show_gaudy_message("SPEED BONUS!", 1.5, "green")
			elif power_type == PowerUpType.TACKLE:
				var hud = get_tree().get_first_node_in_group("hud")
				if hud and hud.has_method("show_gaudy_message"):
					hud.show_gaudy_message("TACKLE BONUS!", 1.5, "red")
		
		queue_free()
