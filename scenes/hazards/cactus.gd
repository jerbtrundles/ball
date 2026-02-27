extends StaticBody3D

@export var knockback_force: float = 15.0

func _ready() -> void:
	add_to_group("hazards")
	if get_child_count() == 0:
		_build_visuals()

func _build_visuals() -> void:
	# Main cactus body
	var mesh_inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.4
	cyl.height = 1.5
	cyl.radial_segments = 8
	mesh_inst.mesh = cyl
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.6, 0.2)
	mat.roughness = 0.9
	mesh_inst.material_override = mat
	mesh_inst.position.y = 0.75
	add_child(mesh_inst)
	
	# Arms
	_add_arm(Vector3(0.3, 1.0, 0), Vector3(0, 0, -45))
	_add_arm(Vector3(-0.3, 0.8, 0), Vector3(0, 0, 45))
	
	# Collision
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 1.5
	col.shape = shape
	col.position.y = 0.75
	add_child(col)
	
	# Hurt area
	var area = Area3D.new()
	var area_col = CollisionShape3D.new()
	var area_shape = CylinderShape3D.new()
	area_shape.radius = 0.5
	area_shape.height = 1.6
	area_col.shape = area_shape
	area_col.position.y = 0.75
	area.add_child(area_col)
	area.body_entered.connect(_on_body_entered)
	area.collision_mask = 2 # Players
	add_child(area)

func _add_arm(pos: Vector3, rot: Vector3) -> void:
	var arm = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.15, 0.5, 0.15)
	arm.mesh = box
	arm.material_override = get_child(0).material_override
	arm.position = pos
	arm.rotation_degrees = rot
	add_child(arm)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("receive_hazard_hit"):
		var dir = (body.global_position - global_position).normalized()
		body.receive_hazard_hit(dir, knockback_force)
		
		# Visual confirmation (flash red)
		var mesh = get_child(0) as MeshInstance3D
		if mesh:
			var tween = create_tween()
			tween.tween_property(mesh.material_override, "emission_enabled", true, 0.05)
			tween.tween_property(mesh.material_override, "emission", Color.RED, 0.05)
			tween.tween_interval(0.1)
			tween.tween_property(mesh.material_override, "emission_enabled", false, 0.1)

