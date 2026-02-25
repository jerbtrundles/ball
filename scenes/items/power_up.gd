extends Node3D
## Power-Up — floating orb that grants a temporary buff on pickup.

enum PowerUpType { SPEED, ACCURACY, TACKLE }

var power_type: PowerUpType = PowerUpType.SPEED
var buff_duration: float = 8.0
var despawn_time: float = 12.0
var _timer: float = 0.0
var _collected: bool = false
var _orb_mesh: MeshInstance3D = null
var _orb_mat: StandardMaterial3D = null
var _base_y: float = 0.0

var type_colors: Dictionary = {
	PowerUpType.SPEED: Color(0.1, 1.0, 0.3),
	PowerUpType.ACCURACY: Color(0.2, 0.5, 1.0),
	PowerUpType.TACKLE: Color(1.0, 0.2, 0.2),
}

var type_names: Dictionary = {
	PowerUpType.SPEED: "speed",
	PowerUpType.ACCURACY: "accuracy",
	PowerUpType.TACKLE: "tackle",
}

func _ready() -> void:
	add_to_group("hazards")
	_base_y = position.y + 0.8
	_build_visuals()
	_build_trigger()

func _build_visuals() -> void:
	var color = type_colors.get(power_type, Color.WHITE)
	
	# Glowing orb
	_orb_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	_orb_mesh.mesh = sphere
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.albedo_color = color
	_orb_mat.emission_enabled = true
	_orb_mat.emission = color
	_orb_mat.emission_energy_multiplier = 3.0
	_orb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_orb_mat.albedo_color.a = 0.8
	_orb_mat.metallic = 0.5
	_orb_mat.roughness = 0.2
	_orb_mesh.material_override = _orb_mat
	_orb_mesh.position.y = _base_y
	add_child(_orb_mesh)
	
	# Inner glow core
	var core = MeshInstance3D.new()
	var core_mesh = SphereMesh.new()
	core_mesh.radius = 0.15
	core_mesh.height = 0.3
	core.mesh = core_mesh
	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color.WHITE
	core_mat.emission_enabled = true
	core_mat.emission = color
	core_mat.emission_energy_multiplier = 6.0
	core.material_override = core_mat
	core.position.y = _base_y
	add_child(core)

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
	add_child(area)

func _process(delta: float) -> void:
	if _collected:
		return
	
	_timer += delta
	
	# Float and bob
	if _orb_mesh:
		_orb_mesh.position.y = _base_y + sin(_timer * 2.0) * 0.15
		_orb_mesh.rotation.y += delta * 1.5
	
	# Despawn timer
	if _timer >= despawn_time:
		# Fade out
		if _orb_mat:
			var tween = create_tween()
			tween.tween_property(_orb_mat, "albedo_color:a", 0.0, 0.5)
			tween.tween_callback(queue_free)
		else:
			queue_free()

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if body.is_in_group("players") and body.has_method("apply_buff"):
		_collected = true
		var buff_name = type_names.get(power_type, "speed")
		body.apply_buff(buff_name, buff_duration)
		
		# VFX
		var color = type_colors.get(power_type, Color.WHITE)
		if VFX:
			VFX.spawn_pickup_pop(global_position, color)
		
		queue_free()
