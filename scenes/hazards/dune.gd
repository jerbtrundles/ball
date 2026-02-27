extends StaticBody3D

@export var bounce_factor: float = 1.5

func _ready() -> void:
	add_to_group("hazards")
	if get_child_count() == 0:
		_build_visuals()
	
	# Physics material for high bounce
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.8
	physics_material_override.friction = 0.3

func _build_visuals() -> void:
	var mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 1.0
	sphere.is_hemisphere = true
	mesh_inst.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.6, 0.3)
	mat.roughness = 1.0
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	
	# Collision (Sphere shape, but scaled)
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.5
	col.shape = shape
	col.position.y = 0.0 # Hemisphere sits on 0 roughly?
	# Adjust for hemisphere center
	# Hemisphere mesh origin is usually at base physically?
	# Godot SphereMesh is centered. is_hemisphere cuts bottom half.
	# So origin is center of sphere. We want it buried in ground.
	col.position.y = -0.5
	mesh_inst.position.y = -0.5
	
	add_child(col)
	
	# Detect ball for extra bounce boost
	var area = Area3D.new()
	var area_col = CollisionShape3D.new()
	area_col.shape = shape
	area_col.position = col.position
	area.add_child(area_col)
	area.body_entered.connect(_on_body_entered)
	area.collision_mask = 4 # Ball
	add_child(area)

func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D and "linear_velocity" in body:
		# Boost the bounce
		body.linear_velocity.y = abs(body.linear_velocity.y) * bounce_factor + 5.0
