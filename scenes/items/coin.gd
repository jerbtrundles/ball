extends Node3D
## Coin — spinning golden disc that adds 1 bonus point on pickup.

var despawn_time: float = 10.0
var _timer: float = 0.0
var _collected: bool = false
var _coin_mesh: MeshInstance3D = null
var _coin_mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("hazards")
	_build_visuals()
	_build_trigger()

func _build_visuals() -> void:
	_coin_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	cyl.height = 0.04
	cyl.radial_segments = 16
	_coin_mesh.mesh = cyl
	_coin_mat = StandardMaterial3D.new()
	_coin_mat.albedo_color = Color(1.0, 0.85, 0.2)
	_coin_mat.emission_enabled = true
	_coin_mat.emission = Color(1.0, 0.8, 0.1)
	_coin_mat.emission_energy_multiplier = 2.0
	_coin_mat.metallic = 0.9
	_coin_mat.roughness = 0.15
	_coin_mesh.material_override = _coin_mat
	_coin_mesh.position.y = 0.5
	add_child(_coin_mesh)

func _build_trigger() -> void:
	var area = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # Players
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.0
	col.shape = shape
	col.position.y = 0.5
	area.add_child(col)
	area.body_entered.connect(_on_body_entered)
	area.area_entered.connect(_on_area_entered)
	add_child(area)

func _process(delta: float) -> void:
	if _collected:
		return
	_timer += delta
	
	# Spin
	if _coin_mesh:
		_coin_mesh.rotation.y += delta * 3.0
		_coin_mesh.position.y = 0.5 + sin(_timer * 3.0) * 0.1
	
	# Despawn
	if _timer >= despawn_time:
		var tween = create_tween()
		if _coin_mat:
			tween.tween_property(_coin_mat, "albedo_color:a", 0.0, 0.3)
		tween.tween_callback(queue_free)

func _on_body_entered(body: Node3D) -> void:
	_process_pickup(body)

func _on_area_entered(area: Area3D) -> void:
	if area.owner and area.owner.is_in_group("players"):
		_process_pickup(area.owner)

func _process_pickup(body: Node3D) -> void:
	if _collected:
		return
	if body.is_in_group("players"):
		
		# Add 1 bonus point to the player's team
		if "team_index" in body and "roster_index" in body:
			var game_mgr = get_tree().get_first_node_in_group("game_manager")
			if game_mgr and game_mgr.has_method("award_score"):
				# game_mgr.award_score(body.team_index, 1, false)
				# game_mgr.record_stat(body.team_index, body.roster_index, "coins", 1)
				if body.has_method("add_pending_points"):
					body.add_pending_points(1)
		
		_collected = true
		# VFX
		if VFX:
			VFX.spawn_pickup_pop(global_position, Color.GOLD)
		
		queue_free()
