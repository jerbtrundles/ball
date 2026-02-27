extends Node3D
## Court Builder — procedurally creates the court geometry, walls, hoops, and court lines.

@export var court_length: float = 30.0  # Z axis (full court)
@export var court_width: float = 16.0   # X axis
@export var wall_height: float = 4.0
@export var wall_thickness: float = 0.5
@export var hoop_height: float = 3.0

# Materials
var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var line_material: StandardMaterial3D
var hoop_material: StandardMaterial3D
var _current_theme: CourtTheme = null
var _floor_mesh: MeshInstance3D = null  # Stored so we can swap materials on theme change

func apply_theme(theme: CourtTheme) -> void:
	if theme == null:
		return
		
	_current_theme = theme
	
	if floor_material:
		floor_material.albedo_color = theme.floor_color
	if wall_material:
		wall_material.albedo_color = theme.wall_color
	if line_material:
		line_material.albedo_color = theme.line_color
		line_material.emission = theme.line_color
		line_material.emission_energy_multiplier = 2.5 if theme.glow_enabled else 0.5
	if hoop_material:
		hoop_material.albedo_color = theme.hoop_color
		hoop_material.emission = theme.hoop_color
		hoop_material.emission_energy_multiplier = 2.0 if theme.glow_enabled else 0.5
	
	# Animated floor override
	if _floor_mesh:
		if theme.animated_floor:
			_floor_mesh.material_override = _build_animated_floor_material(theme)
		else:
			_floor_mesh.material_override = floor_material
			if floor_material:
				floor_material.albedo_color = theme.floor_color
		
	# Apply lighting changes immediately
	_apply_theme_lighting()
	
	# Spawn hazards
	_spawn_theme_hazards(theme)

func _spawn_theme_hazards(theme: CourtTheme) -> void:
	# Clear existing theme hazards
	for child in get_children():
		if child.is_in_group("theme_hazards"):
			child.queue_free()
	
	if not theme: return
	if not "hazard_scenes" in theme or theme.hazard_scenes.is_empty(): return
	if not "hazard_count" in theme or theme.hazard_count <= 0: return
	
	for i in range(theme.hazard_count):
		var scene = theme.hazard_scenes.pick_random()
		if scene:
			var inst = scene.instantiate()
			inst.add_to_group("theme_hazards")
			add_child(inst)
			
			# Random position on court (avoiding center and hoops)
			# Court is roughly -8 to 8 X, -15 to 15 Z
			# Avoid center circle (radius 2.5) and keys (Z > 10 or Z < -10)
			
			var params = PhysicsShapeQueryParameters3D.new()
			# Simple retry loop for placement
			for attempt in range(10):
				var rx = randf_range(-court_width/2 + 1.0, court_width/2 - 1.0)
				var rz = randf_range(-court_length/2 + 2.0, court_length/2 - 2.0)
				
				# Check avoidance
				if Vector2(rx, rz).length() < 3.0: continue # Center
				if abs(rz) > court_length/2 - 6.0 and abs(rx) < 3.0: continue # Key area
				
				inst.position = Vector3(rx, 0, rz)
				break

func _ready() -> void:
	add_to_group("court_builder")
	_create_materials()
	_build_floor()
	_build_walls()
	_build_court_lines()
	_build_hoops()
	_build_lighting()

func _create_materials() -> void:
	# Floor — dark metallic
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.08, 0.08, 0.12)
	floor_material.metallic = 0.8
	floor_material.roughness = 0.4
	
	# Walls — chain-link industrial  
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.15, 0.15, 0.2)
	wall_material.metallic = 0.9
	wall_material.roughness = 0.3
	wall_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wall_material.albedo_color.a = 0.7
	
	# Court lines — neon cyan
	line_material = StandardMaterial3D.new()
	line_material.albedo_color = Color(0.0, 0.9, 1.0)
	line_material.emission_enabled = true
	line_material.emission = Color(0.0, 0.9, 1.0)
	line_material.emission_energy_multiplier = 2.0
	
	# Hoop — neon orange
	hoop_material = StandardMaterial3D.new()
	hoop_material.albedo_color = Color(1.0, 0.5, 0.0)
	hoop_material.emission_enabled = true
	hoop_material.emission = Color(1.0, 0.5, 0.0)
	hoop_material.emission_energy_multiplier = 1.5
	hoop_material.metallic = 0.7
	hoop_material.roughness = 0.3

func _build_floor() -> void:
	# Floor extends 2m beyond court bounds on each end for inbound passers
	var floor_z_extent = court_length + 4.0
	
	var floor_mesh = MeshInstance3D.new()
	floor_mesh.name = "FloorMesh"
	var box = BoxMesh.new()
	box.size = Vector3(court_width, 0.2, floor_z_extent)
	floor_mesh.mesh = box
	floor_mesh.material_override = floor_material
	floor_mesh.position = Vector3(0, -0.1, 0)
	add_child(floor_mesh)
	_floor_mesh = floor_mesh
	
	# Floor collision
	var floor_body = StaticBody3D.new()
	var floor_col = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(court_width, 0.2, floor_z_extent)
	floor_col.shape = floor_shape
	floor_body.position = Vector3(0, -0.1, 0)
	floor_body.add_child(floor_col)
	floor_body.collision_layer = 1  # Court layer
	add_child(floor_body)

func _build_walls() -> void:
	# Four walls around the court, but North and South have a gap in the middle for inbounders
	var half_w = court_width / 2.0
	var gap_w = 2.0  # 2m gap in the center of the endlines
	var wall_w = (court_width - gap_w) / 2.0 + wall_thickness
	
	var wall_configs = [
		# North wall (split)
		[Vector3(-half_w + wall_w/2.0 - wall_thickness/2.0, wall_height / 2, -court_length / 2 - wall_thickness / 2), Vector3(wall_w, wall_height, wall_thickness)], # North Left
		[Vector3(half_w - wall_w/2.0 + wall_thickness/2.0, wall_height / 2, -court_length / 2 - wall_thickness / 2), Vector3(wall_w, wall_height, wall_thickness)],  # North Right
		
		# South wall (split)
		[Vector3(-half_w + wall_w/2.0 - wall_thickness/2.0, wall_height / 2, court_length / 2 + wall_thickness / 2), Vector3(wall_w, wall_height, wall_thickness)],  # South Left
		[Vector3(half_w - wall_w/2.0 + wall_thickness/2.0, wall_height / 2, court_length / 2 + wall_thickness / 2), Vector3(wall_w, wall_height, wall_thickness)],   # South Right
		
		# West / East walls (solid)
		[Vector3(-court_width / 2 - wall_thickness / 2, wall_height / 2, 0), Vector3(wall_thickness, wall_height, court_length)],  # West
		[Vector3(court_width / 2 + wall_thickness / 2, wall_height / 2, 0), Vector3(wall_thickness, wall_height, court_length)],   # East
	]
	
	for config in wall_configs:
		var pos: Vector3 = config[0]
		var size: Vector3 = config[1]
		
		# Visual
		var wall_mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = size
		wall_mesh.mesh = box
		wall_mesh.material_override = wall_material
		wall_mesh.position = pos
		add_child(wall_mesh)
		
		# Collision
		var wall_body = StaticBody3D.new()
		var wall_col = CollisionShape3D.new()
		var wall_shape = BoxShape3D.new()
		wall_shape.size = size
		wall_col.shape = wall_shape
		wall_body.position = pos
		wall_body.add_child(wall_col)
		wall_body.collision_layer = 1  # Court layer
		add_child(wall_body)

func _build_court_lines() -> void:
	var lh = 0.02  # Line height (just above floor)
	var lw = 0.08  # Line width
	var half_w = court_width / 2
	var half_l = court_length / 2
	
	# === Boundary lines ===
	_add_line(Vector3(0, lh, -half_l + lw/2), Vector3(court_width, 0.02, lw))   # North endline
	_add_line(Vector3(0, lh, half_l - lw/2), Vector3(court_width, 0.02, lw))    # South endline
	_add_line(Vector3(-half_w + lw/2, lh, 0), Vector3(lw, 0.02, court_length))  # West sideline
	_add_line(Vector3(half_w - lw/2, lh, 0), Vector3(lw, 0.02, court_length))   # East sideline
	
	# === Half-court line ===
	_add_line(Vector3(0, lh, 0), Vector3(court_width, 0.02, lw))
	
	# === Center circle ===
	_add_circle(Vector3(0, lh, 0), 2.5, 40)
	# Inner circle
	_add_circle(Vector3(0, lh, 0), 0.6, 20)
	
	# === Keys (paint areas) ===
	var key_width = 4.0    # Width of the key
	var key_depth = 5.5    # How far the key extends from the endline
	var key_hw = key_width / 2
	
	for end_z_sign in [-1.0, 1.0]:
		var endline_z = end_z_sign * half_l
		var key_top_z = endline_z - end_z_sign * key_depth
		
		# Key rectangle — left side
		_add_line(Vector3(-key_hw, lh, (endline_z + key_top_z) / 2), Vector3(lw, 0.02, key_depth))
		# Key rectangle — right side
		_add_line(Vector3(key_hw, lh, (endline_z + key_top_z) / 2), Vector3(lw, 0.02, key_depth))
		# Foul line (top of key)
		_add_line(Vector3(0, lh, key_top_z), Vector3(key_width, 0.02, lw))
		
		# Foul circle (at the foul line)
		_add_circle(Vector3(0, lh, key_top_z), key_hw, 32)
		
		# Backboard tick marks on the key sides
		for tick_i in range(4):
			var tick_z = endline_z - end_z_sign * (1.0 + tick_i * 1.2)
			# Left tick
			_add_line(Vector3(-key_hw - 0.3, lh, tick_z), Vector3(0.6, 0.02, lw))
			# Right tick
			_add_line(Vector3(key_hw + 0.3, lh, tick_z), Vector3(0.6, 0.02, lw))
		
		# === Three-point arc ===
		# The arc is centered at the basket (z = endline_z ± 1.5)
		var basket_z = endline_z - end_z_sign * 1.5
		var three_pt_radius = 7.5
		var arc_segments = 28
		
		# Draw the arc portion
		for seg_i in range(arc_segments):
			# Arc goes from roughly -70 to +70 degrees (measuring from the endline)
			var angle_start = -1.22 + (float(seg_i) / arc_segments) * 2.44  # ~-70° to +70°
			var angle_end = -1.22 + (float(seg_i + 1) / arc_segments) * 2.44
			
			var p1 = Vector3(
				sin(angle_start) * three_pt_radius,
				lh,
				basket_z - end_z_sign * cos(angle_start) * three_pt_radius
			)
			var p2 = Vector3(
				sin(angle_end) * three_pt_radius,
				lh,
				basket_z - end_z_sign * cos(angle_end) * three_pt_radius
			)
			
			# Clamp to court width
			p1.x = clampf(p1.x, -half_w + 0.1, half_w - 0.1)
			p2.x = clampf(p2.x, -half_w + 0.1, half_w - 0.1)
			
			var mid = (p1 + p2) / 2
			var seg_length = p1.distance_to(p2)
			if seg_length < 0.01:
				continue
			var dir_angle = atan2(p2.x - p1.x, p2.z - p1.z)
			
			var seg = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(lw, 0.02, seg_length)
			seg.mesh = box
			seg.material_override = line_material
			seg.position = mid
			seg.rotation.y = dir_angle
			add_child(seg)
		
		# Straight sideline portions of the 3pt line (from corner to where arc starts)
		var corner_x_left = sin(-1.22) * three_pt_radius
		var corner_x_right = sin(1.22) * three_pt_radius
		corner_x_left = clampf(corner_x_left, -half_w + 0.1, half_w - 0.1)
		corner_x_right = clampf(corner_x_right, -half_w + 0.1, half_w - 0.1)
		var corner_z = basket_z - end_z_sign * cos(1.22) * three_pt_radius
		var corner_len = abs(endline_z - corner_z)
		
		# Left corner
		_add_line(Vector3(corner_x_left, lh, (endline_z + corner_z) / 2), Vector3(lw, 0.02, corner_len))
		# Right corner
		_add_line(Vector3(corner_x_right, lh, (endline_z + corner_z) / 2), Vector3(lw, 0.02, corner_len))

func _add_line(pos: Vector3, size: Vector3) -> void:
	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = line_material
	mesh_instance.position = pos
	add_child(mesh_instance)

func _add_circle(center: Vector3, radius: float, segments: int) -> void:
	# Create circle from line segments
	for i in range(segments):
		var angle = (float(i) / segments) * TAU
		var next_angle = (float(i + 1) / segments) * TAU
		var p1 = center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var p2 = center + Vector3(cos(next_angle) * radius, 0, sin(next_angle) * radius)
		var mid = (p1 + p2) / 2
		var length = p1.distance_to(p2)
		var dir_angle = atan2(p2.x - p1.x, p2.z - p1.z)
		
		var seg = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.06, 0.02, length)
		seg.mesh = box
		seg.material_override = line_material
		seg.position = mid
		seg.rotation.y = dir_angle
		add_child(seg)

func _add_arc(center: Vector3, radius: float, direction: float, segments: int) -> void:
	## Draw a semi-circle arc. direction: 1 = opens toward +Z, -1 = opens toward -Z
	for i in range(segments):
		var angle = -PI / 2 + (float(i) / segments) * PI
		var next_angle = -PI / 2 + (float(i + 1) / segments) * PI
		var p1 = center + Vector3(cos(angle) * radius, 0, direction * sin(angle) * radius)
		var p2 = center + Vector3(cos(next_angle) * radius, 0, direction * sin(next_angle) * radius)
		var mid = (p1 + p2) / 2
		var seg_length = p1.distance_to(p2)
		var dir_angle = atan2(p2.x - p1.x, p2.z - p1.z)
		
		var seg = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.06, 0.02, seg_length)
		seg.mesh = box
		seg.material_override = line_material
		seg.position = mid
		seg.rotation.y = dir_angle
		add_child(seg)

func _build_hoops() -> void:
	# North hoop (Team 0's basket — Team 1 scores here)
	_create_hoop(Vector3(0, hoop_height, -court_length / 2 + 1.5), 0)
	# South hoop (Team 1's basket — Team 0 scores here)
	_create_hoop(Vector3(0, hoop_height, court_length / 2 - 1.5), 1)

func _create_hoop(pos: Vector3, team_index: int) -> void:
	var hoop_node = Node3D.new()
	hoop_node.position = pos
	hoop_node.name = "Hoop_%d" % team_index
	
	# Backboard
	var backboard = MeshInstance3D.new()
	var bb_mesh = BoxMesh.new()
	bb_mesh.size = Vector3(2.0, 1.5, 0.1)
	backboard.mesh = bb_mesh
	var bb_mat = StandardMaterial3D.new()
	bb_mat.albedo_color = Color(0.2, 0.2, 0.3)
	bb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bb_mat.albedo_color.a = 0.6
	bb_mat.metallic = 0.8
	backboard.material_override = bb_mat
	backboard.position = Vector3(0, 0.5, 0)
	hoop_node.add_child(backboard)
	
	# Backboard collision
	var bb_body = StaticBody3D.new()
	var bb_col = CollisionShape3D.new()
	var bb_shape = BoxShape3D.new()
	bb_shape.size = Vector3(2.0, 1.5, 0.1)
	bb_col.shape = bb_shape
	bb_body.position = Vector3(0, 0.5, 0)
	bb_body.add_child(bb_col)
	bb_body.collision_layer = 1
	hoop_node.add_child(bb_body)
	
	# Rim — built from cylinder segments in a circle (stable geometry, no distortion)
	var rim_z_offset = 0.6 if team_index == 0 else -0.6
	var rim_radius = 0.4
	var rim_segments = 24
	var rim_tube_radius = 0.035
	var rim_parent = Node3D.new()
	rim_parent.name = "Rim"
	rim_parent.position = Vector3(0, -0.1, rim_z_offset)
	hoop_node.add_child(rim_parent)
	
	for i in range(rim_segments):
		var angle = (float(i) / rim_segments) * TAU
		var next_angle = (float(i + 1) / rim_segments) * TAU
		var mid_angle = (angle + next_angle) / 2.0
		var seg_length = rim_radius * TAU / rim_segments * 1.05  # Slight overlap to close gaps
		
		var seg = MeshInstance3D.new()
		var seg_mesh = CylinderMesh.new()
		seg_mesh.top_radius = rim_tube_radius
		seg_mesh.bottom_radius = rim_tube_radius
		seg_mesh.height = seg_length
		seg_mesh.radial_segments = 8
		seg.mesh = seg_mesh
		seg.material_override = hoop_material
		
		# Position at the midpoint of this arc segment
		seg.position = Vector3(cos(mid_angle) * rim_radius, 0, sin(mid_angle) * rim_radius)
		# Rotate to lie along the tangent of the circle
		seg.rotation.y = -mid_angle
		seg.rotation.z = PI / 2  # Lay the cylinder on its side
		rim_parent.add_child(seg)
	
	# Scoring trigger zone (Area3D) — detects when ball passes through
	var trigger = Area3D.new()
	trigger.name = "ScoreTrigger"
	var trigger_col = CollisionShape3D.new()
	var trigger_shape = CylinderShape3D.new()
	trigger_shape.radius = 0.5
	trigger_shape.height = 0.8
	trigger_col.shape = trigger_shape
	trigger.position = Vector3(0, -0.3, rim_z_offset)
	trigger.collision_layer = 0
	trigger.collision_mask = 4  # Ball layer
	trigger.add_child(trigger_col)
	trigger.body_entered.connect(func(body): _on_score_trigger(body, team_index))
	hoop_node.add_child(trigger)
	
	# Net (tapered rings hanging below the rim, built from cylinder segments)
	var net_rings = 6
	var net_length = 0.6
	var net_mat = StandardMaterial3D.new()
	net_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.4)
	net_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net_mat.emission_enabled = true
	net_mat.emission = Color(1.0, 1.0, 1.0) * 0.15
	
	for ring_i in range(net_rings):
		var t = float(ring_i) / net_rings
		var ring_y = -0.25 - t * net_length
		var ring_radius = rim_radius * (1.0 - t * 0.65)  # Taper
		var ring_tube = 0.012
		var ring_segs = 16
		
		var ring_parent = Node3D.new()
		ring_parent.position = Vector3(0, ring_y, rim_z_offset)
		hoop_node.add_child(ring_parent)
		
		for si in range(ring_segs):
			var a = (float(si) / ring_segs) * TAU
			var na = (float(si + 1) / ring_segs) * TAU
			var ma = (a + na) / 2.0
			var sl = ring_radius * TAU / ring_segs * 1.05
			
			var ns = MeshInstance3D.new()
			var ns_mesh = CylinderMesh.new()
			ns_mesh.top_radius = ring_tube
			ns_mesh.bottom_radius = ring_tube
			ns_mesh.height = sl
			ns_mesh.radial_segments = 4
			ns.mesh = ns_mesh
			ns.material_override = net_mat
			ns.position = Vector3(cos(ma) * ring_radius, 0, sin(ma) * ring_radius)
			ns.rotation.y = -ma
			ns.rotation.z = PI / 2
			ring_parent.add_child(ns)
	
	# Connecting net strings (vertical lines between rings)
	for str_i in range(8):
		var angle = (float(str_i) / 8.0) * TAU
		var string_mesh = MeshInstance3D.new()
		var string_box = BoxMesh.new()
		string_box.size = Vector3(0.015, net_length, 0.015)
		string_mesh.mesh = string_box
		var str_mat = StandardMaterial3D.new()
		str_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.4)
		str_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		string_mesh.material_override = str_mat
		var top_r = 0.33
		var bot_r = 0.33 * 0.4
		var avg_r = (top_r + bot_r) / 2.0
		string_mesh.position = Vector3(
			cos(angle) * avg_r,
			-0.3 - net_length / 2.0,
			rim_z_offset + sin(angle) * avg_r
		)
		hoop_node.add_child(string_mesh)
	
	# Support pole
	var pole = MeshInstance3D.new()
	var pole_mesh = CylinderMesh.new()
	pole_mesh.top_radius = 0.05
	pole_mesh.bottom_radius = 0.08
	pole_mesh.height = hoop_height
	pole.mesh = pole_mesh
	pole.material_override = wall_material
	pole.position = Vector3(0, -hoop_height / 2, 0)
	hoop_node.add_child(pole)
	
	add_child(hoop_node)

func _on_score_trigger(body: Node3D, hoop_team: int) -> void:
	if body.is_in_group("ball") and body.has_method("_on_hoop_entered"):
		body._on_hoop_entered(hoop_team)

func _build_lighting() -> void:
	# Main overhead lights (arena feel)
	var main_light = DirectionalLight3D.new()
	main_light.name = "MainLight"
	main_light.rotation_degrees = Vector3(-60, 30, 0)
	main_light.light_energy = 0.8
	main_light.light_color = Color(0.9, 0.92, 1.0)
	main_light.shadow_enabled = true
	add_child(main_light)
	
	# Ambient fill
	var env = WorldEnvironment.new()
	env.name = "WorldEnv"
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.02, 0.06)
	environment.ambient_light_color = Color(0.15, 0.15, 0.25)
	environment.ambient_light_energy = 0.5
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR

	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_bloom = 0.3
	env.environment = environment
	add_child(env)
	
	# Spot lights on each hoop for drama
	for i in range(2):
		var spot = SpotLight3D.new()
		spot.name = "HoopSpot_%d" % i
		var z = -court_length / 2 + 1.5 if i == 0 else court_length / 2 - 1.5
		spot.position = Vector3(0, 8, z)
		spot.rotation_degrees = Vector3(-90, 0, 0)
		spot.light_energy = 3.0
		spot.light_color = Color(1.0, 0.7, 0.3)
		spot.spot_range = 12.0
		spot.spot_angle = 35.0
		add_child(spot)
	
	# Side neon accent lights
	for side in [-1, 1]:
		var neon = OmniLight3D.new()
		neon.name = "NeonAccent_%d" % (side + 2)
		neon.position = Vector3(side * court_width / 2, 2, 0)
		neon.light_energy = 1.5
		neon.light_color = Color(0.0, 0.8, 1.0)
		neon.omni_range = 8.0
		add_child(neon)
		
	# Setup initial theme lighting if it was provided early
	if _current_theme != null:
		_apply_theme_lighting()

func _apply_theme_lighting() -> void:
	if _current_theme == null: return
	
	var main_light: DirectionalLight3D = get_node_or_null("MainLight")
	if main_light:
		main_light.light_color = _current_theme.main_light_color
		
	var env_node: WorldEnvironment = get_node_or_null("WorldEnv")
	if env_node and env_node.environment:
		env_node.environment.background_color = _current_theme.ambient_color
		env_node.environment.ambient_light_color = _current_theme.ambient_color.lightened(0.1)
		env_node.environment.glow_enabled = _current_theme.glow_enabled
		env_node.environment.glow_intensity = 1.2 if _current_theme.glow_enabled else 0.0
		env_node.environment.glow_bloom = 0.4 if _current_theme.glow_enabled else 0.0
		
	# Update hoop spotlights
	for i in range(2):
		var spot: SpotLight3D = get_node_or_null("HoopSpot_%d" % i)
		if spot:
			spot.light_color = _current_theme.spotlight_color
		
	# Update neon accents
	for i in range(1, 4):
		var neon: OmniLight3D = get_node_or_null("NeonAccent_%d" % i)
		if neon:
			neon.light_color = _current_theme.line_color
			neon.light_energy = 2.0 if _current_theme.glow_enabled else 0.8

## Builds a ShaderMaterial with animated sweeping stripes + ripples for the Cyber Grid court.
func _build_animated_floor_material(theme: CourtTheme) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// === Theme colors ===
uniform vec3 base_color   : source_color = vec3(0.03, 0.02, 0.08);
uniform vec3 stripe_color : source_color = vec3(0.55, 0.0, 1.0);
uniform vec3 cross_color  : source_color = vec3(0.1, 0.8, 1.0);
uniform vec3 ripple_color : source_color = vec3(0.3, 0.05, 0.55);

// Court dimensions
uniform float court_length = 34.0;
uniform float court_width  = 16.0;

// Timing
uniform float sweep_speed  = 0.18;
uniform float cross_speed  = 0.11;
uniform float pulse_speed  = 0.35;
uniform float ripple_speed = 0.9;    // How fast rings expand outward

// Intensity  (all kept intentionally low for subtlety)
uniform float stripe_sharpness  = 9.0;
uniform float cross_sharpness   = 12.0;
uniform float stripe_brightness = 0.18;
uniform float cross_brightness  = 0.10;
uniform float ripple_brightness = 0.09;
uniform float pulse_amplitude   = 0.04;

void fragment() {
	float world_x = (UV.x - 0.5) * court_width;
	float world_z = (UV.y - 0.5) * court_length;

	// -------------------------------------------------------
	// 1. Concentric ripples expanding from court centre
	//    Rings spaced ~2m apart, slowish outward drift.
	// -------------------------------------------------------
	float dist = length(vec2(world_x, world_z));
	float ring_phase = dist * 0.5 - TIME * ripple_speed;
	float rings = sin(ring_phase) * 0.5 + 0.5;
	// Sharpen into thin glowing bands
	rings = pow(rings, 5.0);
	// Fade rings out beyond ~half the court length so they disappear naturally
	float ripple_fade = smoothstep(court_length * 0.55, court_length * 0.1, dist);
	float ripple = rings * ripple_fade;

	// -------------------------------------------------------
	// 2. Diagonal sweep (travels along +Z, slight angle)
	// -------------------------------------------------------
	float diag = (world_z / court_length) + (world_x / court_width) * 0.35;
	float sweep_phase = fract(diag - TIME * sweep_speed);
	float sweep = pow(max(0.0, 1.0 - abs(sweep_phase - 0.5) * stripe_sharpness), 2.0);
	float edge_z = smoothstep(0.0, 0.12, UV.y) * smoothstep(1.0, 0.88, UV.y);
	sweep *= edge_z;

	// -------------------------------------------------------
	// 3. Cross sweep (travels along -X, slower)
	// -------------------------------------------------------
	float cross_diag = (world_x / court_width) - (world_z / court_length) * 0.2;
	float cross_phase = fract(cross_diag - TIME * cross_speed);
	float cross_sweep = pow(max(0.0, 1.0 - abs(cross_phase - 0.5) * cross_sharpness), 2.0);
	float edge_x = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	cross_sweep *= edge_x;

	// -------------------------------------------------------
	// 4. Global dim pulse
	// -------------------------------------------------------
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;

	// -------------------------------------------------------
	// Combine — keep base very dark, add effects additively
	// -------------------------------------------------------
	vec3 col = base_color;
	col += ripple_color * ripple * ripple_brightness * (0.7 + pulse * 0.3);
	col += stripe_color * sweep * stripe_brightness;
	col += cross_color  * cross_sweep * cross_brightness;
	col += base_color   * pulse * pulse_amplitude;

	ALBEDO    = col;
	EMISSION  = col * 0.4;   // Gentle glow — no longer blinding
	ROUGHNESS = 0.2;
	METALLIC  = 0.6;
}
"""
	mat.shader = shader
	mat.set_shader_parameter("base_color",   Vector3(theme.floor_color.r, theme.floor_color.g, theme.floor_color.b))
	mat.set_shader_parameter("stripe_color", Vector3(theme.line_color.r, theme.line_color.g, theme.line_color.b))
	mat.set_shader_parameter("cross_color",  Vector3(theme.hoop_color.r, theme.hoop_color.g, theme.hoop_color.b))
	mat.set_shader_parameter("ripple_color", Vector3(theme.floor_accent_color.r, theme.floor_accent_color.g, theme.floor_accent_color.b))
	mat.set_shader_parameter("court_length", court_length + 4.0)
	mat.set_shader_parameter("court_width",  court_width)
	return mat
