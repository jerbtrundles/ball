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
var _border_mat: StandardMaterial3D = null  # Perimeter stripe material, updated on theme change

# Team colors (set from game_manager via apply_theme)
var _team0_color: Color = Color(0.2, 0.5, 1.0)
var _team1_color: Color = Color(1.0, 0.3, 0.2)

# Accent elements updated per theme
var _center_logo_mat: StandardMaterial3D = null
var _crash_pad_mats: Array = []

# Container for the active environment geometry (gym / cage / rooftop / garage)
var _env_root: Node3D = null


func apply_theme(theme: CourtTheme, team0_color: Color = Color(0.2, 0.5, 1.0), team1_color: Color = Color(1.0, 0.3, 0.2)) -> void:
	if theme == null:
		return

	_current_theme = theme
	_team0_color = team0_color
	_team1_color = team1_color
	
	if floor_material:
		floor_material.albedo_color = theme.floor_color

	if wall_material:
		wall_material.albedo_color = theme.wall_color
		wall_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wall_material.uv1_scale = Vector3(1, 1, 1)

	if line_material:
		line_material.albedo_color = theme.line_color
		line_material.emission = theme.line_color
		line_material.emission_energy_multiplier = 2.5 if theme.glow_enabled else 0.5
	if hoop_material:
		hoop_material.albedo_color = theme.hoop_color
		hoop_material.emission = theme.hoop_color
		hoop_material.emission_energy_multiplier = 2.0 if theme.glow_enabled else 0.5
	
	# Animated floor or procedural wood override
	if _floor_mesh:
		if "animated_floor" in theme and theme.animated_floor:
			_floor_mesh.material_override = _build_animated_floor_material(theme)
		elif "procedural_wood" in theme and theme.procedural_wood:
			_floor_mesh.material_override = _build_procedural_wood_material(theme)
		else:
			_floor_mesh.material_override = floor_material
			if floor_material:
				floor_material.albedo_color = theme.floor_color
		
	# Border stripe — darken the floor colour by 40% for a clean contrast band.
	# On very dark themes the floor is near-black, so clamp to a visible minimum.
	if _border_mat:
		var bc = theme.floor_color.darkened(0.40)
		# Ensure the stripe is always at least slightly visible against the floor.
		bc = bc.lerp(Color(0.12, 0.06, 0.02), 0.30)
		_border_mat.albedo_color = bc
		# On glow themes add a faint emission so the border reads under coloured light.
		_border_mat.emission_enabled = theme.glow_enabled
		if theme.glow_enabled:
			_border_mat.emission = bc
			_border_mat.emission_energy_multiplier = 0.4

	# Apply lighting changes immediately
	_apply_theme_lighting()

	# Update center court logo color
	if _center_logo_mat:
		var lc = theme.line_color
		_center_logo_mat.albedo_color = Color(lc.r, lc.g, lc.b, 0.12)
		_center_logo_mat.emission = lc * 0.08

	# Update crash pad colors to match teams
	if _crash_pad_mats.size() >= 2:
		_crash_pad_mats[0].albedo_color = _team0_color.darkened(0.35)
		_crash_pad_mats[1].albedo_color = _team1_color.darkened(0.35)

	# Handle crowd and bleachers
	_build_bleachers_and_crowd(theme)

	# Rebuild environment geometry if the theme requires a non-standard court
	_rebuild_environment(theme)

	# Spawn hazards
	_spawn_theme_hazards(theme)

func _build_bleachers_and_crowd(theme: CourtTheme) -> void:
	# Clear existing
	for child in get_children():
		if child.name == "BleachersLayer":
			child.queue_free()
			
	if not "has_bleachers" in theme or not theme.has_bleachers:
		return
		
	var bleachers_node = Node3D.new()
	bleachers_node.name = "BleachersLayer"
	
	var step_count = 5
	var step_width = 1.0
	var step_height = 0.6
	
	var bleacher_mat = StandardMaterial3D.new()
	bleacher_mat.albedo_color = Color(0.2, 0.2, 0.25)
	bleacher_mat.metallic = 0.5
	bleacher_mat.roughness = 0.7
	
	# A helper to build a section of bleachers
	var build_section = func(pos: Vector3, size: Vector3, rot: Vector3, label: String, fan_color: Color):
		var sec_node = Node3D.new()
		sec_node.name = "Section_" + label
		sec_node.position = pos
		sec_node.rotation = rot

		# Build steps
		for i in range(step_count):
			var step_mesh = MeshInstance3D.new()
			var box = BoxMesh.new()
			# Z is horizontal length for this local section, X is depth, Y is height
			# The section runs along local Z axis
			box.size = Vector3(step_width, step_height * (i + 1), size.z)
			step_mesh.mesh = box
			step_mesh.material_override = bleacher_mat
			# Move back in X and up in Y for each step
			step_mesh.position = Vector3(i * step_width, step_height * (i + 1) / 2.0, 0)
			sec_node.add_child(step_mesh)

			# Spawn some crowd members on this step
			_spawn_3d_crowd_on_step(sec_node, i * step_width, step_height * (i + 1), size.z, fan_color)

		bleachers_node.add_child(sec_node)

	var half_w = court_width / 2.0
	var half_l = court_length / 2.0
	var start_dist_x = half_w + wall_thickness + 3.0  # Pushed back by 3m to leave walking room
	var start_dist_z = half_l + wall_thickness + 6.5  # End bleachers at z≈22 — well behind the crash pads at z=±18

	# East Wall → team 1 fans, West Wall → team 0 fans
	# (Matches HUD: team 0 on left/west, team 1 on right/east)
	build_section.call(Vector3(start_dist_x, 0, 0), Vector3(step_width * step_count, 0, court_length + 4.0), Vector3(0, 0, 0), "East", _team1_color)
	build_section.call(Vector3(-start_dist_x, 0, 0), Vector3(step_width * step_count, 0, court_length + 4.0), Vector3(0, PI, 0), "West", _team0_color)
	build_section.call(Vector3(0, 0, -start_dist_z), Vector3(step_width * step_count, 0, court_width + 4.0), Vector3(0, PI/2, 0), "North", _team0_color)
	build_section.call(Vector3(0, 0, start_dist_z), Vector3(step_width * step_count, 0, court_width + 4.0), Vector3(0, -PI/2, 0), "South", _team1_color)
	
	add_child(bleachers_node)

func _spawn_3d_crowd_on_step(parent: Node3D, step_x: float, step_y: float, length_z: float, fan_color: Color = Color.WHITE) -> void:
	var crowd_spacing = 1.2
	var count = int(length_z / crowd_spacing)
	var start_z = -length_z / 2.0 + crowd_spacing / 2.0

	var spec_mesh = CapsuleMesh.new()
	spec_mesh.radius = 0.25
	spec_mesh.height = 1.0

	for i in range(count):
		# Random chance to have an empty seat
		if randf() < 0.2: continue

		var spec = MeshInstance3D.new()
		spec.mesh = spec_mesh

		var mat = StandardMaterial3D.new()
		# 65% of fans wear their team's color, 35% random
		var h: float
		var s: float
		var v: float
		if randf() < 0.65:
			h = fan_color.h
			s = randf_range(0.5, 1.0)
			v = randf_range(0.55, 1.0)
		else:
			h = randf()
			s = randf_range(0.4, 0.8)
			v = randf_range(0.6, 0.9)
		mat.albedo_color = Color.from_hsv(h, s, v)
		mat.roughness = 0.8
		spec.material_override = mat
		
		# Jitter position slightly
		var jitter_z = randf_range(-0.2, 0.2)
		var jitter_x = randf_range(-0.2, 0.2)
		
		# Sit on the step
		spec.position = Vector3(step_x + jitter_x, step_y + spec_mesh.height / 2.0, start_z + i * crowd_spacing + jitter_z)
		
		# Add a simple bobbing script
		var bob_script = GDScript.new()
		bob_script.source_code = """
extends MeshInstance3D
var time_offset: float = 0.0
var speed: float = 1.0
var base_y: float = 0.0
func _ready():
	time_offset = randf() * TAU
	speed = randf_range(5.0, 10.0)
	base_y = position.y
func _process(delta):
	position.y = base_y + max(0.0, sin(Time.get_ticks_msec() / 1000.0 * speed + time_offset)) * 0.2
"""
		bob_script.reload()
		spec.set_script(bob_script)
		
		parent.add_child(spec)

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
	_build_gym_environment()  # outer shell first so it renders behind everything else
	_build_floor()
	_build_court_border()
	_build_walls()
	_build_court_lines()
	_build_center_logo()
	_build_crash_pads()
	_build_hoops()
	_build_lighting()

func _create_materials() -> void:
	# Floor — dark metallic
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.08, 0.08, 0.12)
	floor_material.metallic = 0.8
	floor_material.roughness = 0.4
	
	# Walls — painted concrete / cinder block
	wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.70, 0.69, 0.67)
	wall_material.metallic = 0.0
	wall_material.roughness = 0.95
	wall_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wall_material.albedo_color.a = 0.92
	
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

# ─────────────────────────────────────────────────────────────────────────────
#  GYM ENVIRONMENT  (outer building shell built around the bleachers)
# ─────────────────────────────────────────────────────────────────────────────
#  Layout (all half-distances from center):
#    Court play area   x: ±8.0   z: ±15.0
#    Extended floor    x: ±8.0   z: ±17.0
#    Bleachers (side)  x: 11.5 → 16.5
#    Bleachers (end)   z: 19.0 → 21.5
#    Gym outer walls   x: ±18.5  z: ±23.0
#    Gym height        y:  10.0

func _build_gym_environment() -> void:
	# Create environment container so it can be swapped on theme change
	_env_root = Node3D.new()
	_env_root.name = "GymEnvironment"
	add_child(_env_root)

	var GHX  = 18.5   # gym half-width  — side walls at x = ±GHX
	var GHZ  = 29.0   # gym half-length — end walls at z = ±GHZ (bleachers end at ≈±27, 2m gap to wall)
	var GH   = 10.0   # ceiling height
	var GWT  = 0.45   # gym wall thickness

	# ── Shared materials ─────────────────────────────────────────────────────
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.76, 0.74, 0.72)   # painted cinder block
	wall_mat.roughness    = 0.93
	wall_mat.metallic     = 0.0

	var runoff_mat = StandardMaterial3D.new()
	runoff_mat.albedo_color = Color(0.71, 0.57, 0.38) # warm maple hardwood runoff
	runoff_mat.roughness    = 0.52
	runoff_mat.metallic     = 0.04

	# ── Runoff floor — four strips that hug the court edges ──────────────────
	# Each strip covers only the area the court floor (x:±8 z:±17) does NOT reach,
	# so there is zero overlap and no z-fighting with the court surface.
	#   North/South end strips — full gym width, from court edge to gym wall
	#   East/West side strips  — full court length, from court edge to gym wall
	var cf_hw = court_width  / 2.0   # 8.0  — court floor half-width
	var cf_hl = court_length / 2.0 + 2.0  # 17.0 — court floor half-length (incl. 2m extension)
	var floor_y   = -0.095  # just above the court floor's y = -0.1 so it doesn't z-fight
	var floor_thk = 0.16
	var inner_w = (GHX - GWT) * 2.0  # usable gym width between the walls
	var end_d   = GHZ - GWT - cf_hl  # depth of each end strip (≈ 5.55 m)
	var side_w  = GHX - GWT - cf_hw  # width of each side strip (≈ 10.05 m)

	# North end
	_gym_box("RunoffN", Vector3(0, floor_y, -(cf_hl + end_d / 2.0)),
		Vector3(inner_w, floor_thk, end_d), runoff_mat)
	# South end
	_gym_box("RunoffS", Vector3(0, floor_y,  (cf_hl + end_d / 2.0)),
		Vector3(inner_w, floor_thk, end_d), runoff_mat)
	# East side (spans only the court-length band)
	_gym_box("RunoffE", Vector3( cf_hw + side_w / 2.0, floor_y, 0),
		Vector3(side_w, floor_thk, cf_hl * 2.0), runoff_mat)
	# West side
	_gym_box("RunoffW", Vector3(-(cf_hw + side_w / 2.0), floor_y, 0),
		Vector3(side_w, floor_thk, cf_hl * 2.0), runoff_mat)

	# ── Four outer gym walls (visual + collision) ────────────────────────────
	_gym_box("GymWall_N", Vector3(0,     GH / 2,  -GHZ), Vector3(GHX * 2.0, GH, GWT), wall_mat)
	_gym_box("GymWall_S", Vector3(0,     GH / 2,   GHZ), Vector3(GHX * 2.0, GH, GWT), wall_mat)
	_gym_box("GymWall_E", Vector3( GHX,  GH / 2,   0.0), Vector3(GWT, GH, GHZ * 2.0), wall_mat)
	_gym_box("GymWall_W", Vector3(-GHX,  GH / 2,   0.0), Vector3(GWT, GH, GHZ * 2.0), wall_mat)
	# Collision bodies for the gym walls — these are the physical boundary of
	# the entire playing environment now that court walls have no collision.
	for _gw in [
		[Vector3(0,    GH / 2, -GHZ), Vector3(GHX * 2.0, GH, GWT)],  # North
		[Vector3(0,    GH / 2,  GHZ), Vector3(GHX * 2.0, GH, GWT)],  # South
		[Vector3( GHX, GH / 2,  0.0), Vector3(GWT, GH, GHZ * 2.0)],  # East
		[Vector3(-GHX, GH / 2,  0.0), Vector3(GWT, GH, GHZ * 2.0)],  # West
	]:
		var _gbody = StaticBody3D.new()
		_gbody.position    = _gw[0]
		_gbody.collision_layer = 1
		var _gcol   = CollisionShape3D.new()
		var _gshape = BoxShape3D.new()
		_gshape.size = _gw[1]
		_gcol.shape  = _gshape
		_gbody.add_child(_gcol)
		_env_root.add_child(_gbody)

	# Horizontal accent stripe at mid-wall height on all four walls
	var stripe_mat = StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.62, 0.60, 0.58)
	stripe_mat.roughness    = 0.90
	_gym_box("StripeN", Vector3(0,    3.6, -GHZ + GWT/2 + 0.01), Vector3(GHX*2, 0.22, 0.04), stripe_mat)
	_gym_box("StripeS", Vector3(0,    3.6,  GHZ - GWT/2 - 0.01), Vector3(GHX*2, 0.22, 0.04), stripe_mat)
	_gym_box("StripeE", Vector3( GHX - GWT/2 - 0.01, 3.6, 0), Vector3(0.04, 0.22, GHZ*2), stripe_mat)
	_gym_box("StripeW", Vector3(-GHX + GWT/2 + 0.01, 3.6, 0), Vector3(0.04, 0.22, GHZ*2), stripe_mat)

	# No ceiling — the game camera sits above y≈10 so a ceiling box would block
	# the entire view of the court.  The tall walls provide enough gym enclosure.

	# ── Foam padding strip at base of end walls ───────────────────────────────
	# (Dark gray, 1.6m tall, mounted flush to the end walls)
	var foam_mat = StandardMaterial3D.new()
	foam_mat.albedo_color = Color(0.26, 0.26, 0.26)
	foam_mat.roughness    = 0.97
	_gym_box("FoamPad_N", Vector3(0, 0.80, -(GHZ - GWT * 0.5 - 0.06)), Vector3(GHX * 2.0 - 1.0, 1.60, 0.18), foam_mat)
	_gym_box("FoamPad_S", Vector3(0, 0.80,  (GHZ - GWT * 0.5 - 0.06)), Vector3(GHX * 2.0 - 1.0, 1.60, 0.18), foam_mat)
	# Thinner strip on side walls too
	_gym_box("FoamPad_E", Vector3( GHX - GWT * 0.5 - 0.06, 0.80, 0), Vector3(0.18, 1.60, GHZ * 2.0 - 1.0), foam_mat)
	_gym_box("FoamPad_W", Vector3(-GHX + GWT * 0.5 + 0.06, 0.80, 0), Vector3(0.18, 1.60, GHZ * 2.0 - 1.0), foam_mat)

	# ── High windows on end walls ─────────────────────────────────────────────
	var win_mat = StandardMaterial3D.new()
	win_mat.albedo_color     = Color(0.72, 0.88, 0.98, 0.52)
	win_mat.transparency     = BaseMaterial3D.TRANSPARENCY_ALPHA
	win_mat.roughness        = 0.05
	win_mat.metallic         = 0.30
	win_mat.emission_enabled = true
	win_mat.emission         = Color(0.7, 0.85, 1.0) * 0.18  # mild daylight glow
	var win_xs = [-13.5, -9.0, -4.5, 4.5, 9.0, 13.5]
	for wz_side in [-GHZ + 0.02, GHZ - 0.02]:
		for wxi in range(win_xs.size()):
			var w = MeshInstance3D.new()
			w.name = "Win_%s_%d" % [str(wz_side), wxi]
			var wb = BoxMesh.new()
			wb.size = Vector3(3.0, 1.6, 0.06)
			w.mesh = wb
			w.material_override = win_mat
			w.position = Vector3(win_xs[wxi], GH - 1.5, wz_side)
			_env_root.add_child(w)
	# Side-wall windows (visible above the bleachers between light banks)
	var side_win_zs = [-12.0, -6.0, 0.0, 6.0, 12.0]
	for wx_side in [-GHX + 0.02, GHX - 0.02]:
		for wzi in range(side_win_zs.size()):
			var w = MeshInstance3D.new()
			w.name = "SideWin_%s_%d" % [str(wx_side), wzi]
			var wb = BoxMesh.new()
			wb.size = Vector3(0.06, 1.4, 2.6)
			w.mesh = wb
			w.material_override = win_mat
			w.position = Vector3(wx_side, GH - 1.5, side_win_zs[wzi])
			_env_root.add_child(w)

	# ── Championship banners — mounted flush to the inner face of the side walls ─
	# wall_inner_x = inner face of east wall = GHX - GWT
	_build_gym_banners(GH, GHX - GWT)

## Thin helper — creates a named MeshInstance3D box with the given material.
## Always adds to _env_root when it exists, otherwise falls back to self.
func _gym_box(n: String, pos: Vector3, sz: Vector3, mat: StandardMaterial3D) -> void:
	var node = MeshInstance3D.new()
	node.name = n
	var b = BoxMesh.new()
	b.size = sz
	node.mesh = b
	node.material_override = mat
	node.position = pos
	if _env_root:
		_env_root.add_child(node)
	else:
		add_child(node)

## Championship-style vertical banners mounted flat against the inner face of the side walls.
## wall_inner_x is the inner face X of the east wall (positive value); west is mirrored.
func _build_gym_banners(gym_h: float, wall_inner_x: float) -> void:
	# Each entry: [z_position, x_side (-1=west / +1=east), primary Color]
	var banner_data: Array = [
		[-12.0, -1, Color(0.72, 0.12, 0.08)],  # crimson
		[ -7.0, -1, Color(0.12, 0.18, 0.62)],  # navy
		[ -2.0, -1, Color(0.66, 0.50, 0.08)],  # gold
		[  3.5, -1, Color(0.10, 0.36, 0.12)],  # forest green
		[  9.0, -1, Color(0.55, 0.10, 0.42)],  # purple
		[ -9.5,  1, Color(0.50, 0.22, 0.06)],  # maroon
		[ -4.0,  1, Color(0.10, 0.40, 0.52)],  # teal
		[  1.5,  1, Color(0.66, 0.50, 0.08)],  # gold
		[  7.5,  1, Color(0.72, 0.12, 0.08)],  # crimson
	]
	var banner_h   = 2.8
	var banner_w   = 0.90
	var banner_thk = 0.06
	# Place banner centre so its outward face sits flush with the wall inner face.
	# East wall inner face is at +wall_inner_x; banner centre pulls inward by half its thickness.
	var wall_x = wall_inner_x - banner_thk * 0.5

	for bd in banner_data:
		var z_pos: float  = float(bd[0])
		var x_pos: float  = float(bd[1]) * wall_x   # ± mirrors onto east / west wall
		var col: Color    = bd[2]
		var bi: int       = banner_data.find(bd)

		# Main coloured panel — lies flat against the wall
		var bm = StandardMaterial3D.new()
		bm.albedo_color = col
		bm.roughness    = 0.82
		_gym_box("Banner_%d" % bi, Vector3(x_pos, gym_h - 1.6, z_pos),
			Vector3(banner_thk, banner_h, banner_w), bm)

		# White header stripe across the top
		var hm = StandardMaterial3D.new()
		hm.albedo_color = Color(0.96, 0.96, 0.95)
		hm.roughness    = 0.75
		_gym_box("BannerHead_%d" % bi, Vector3(x_pos, gym_h - 0.14, z_pos),
			Vector3(banner_thk + 0.01, 0.28, banner_w + 0.02), hm)

		# Thin white border line down each long side (left + right edge)
		for side in [-1, 1]:
			var em = StandardMaterial3D.new()
			em.albedo_color = Color(0.96, 0.96, 0.95, 0.7)
			em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			em.roughness    = 0.75
			_gym_box("BannerEdge_%d_%d" % [bi, side],
				Vector3(x_pos, gym_h - 1.6, z_pos + side * (banner_w * 0.5 - 0.03)),
				Vector3(banner_thk + 0.01, banner_h, 0.05), em)

# ─────────────────────────────────────────────────────────────────────────────

func _build_floor() -> void:
	# Floor extends 2m beyond court bounds on each end for inbound passers
	var floor_z_extent = court_length + 4.0
	# Floor extends 3m past each sideline so the wood panelling is clearly visible
	# beyond the east/west boundary lines (sidelines sit at x = ±court_width/2 = ±8).
	var floor_x_extent = court_width + 6.0   # 16 + 6 = 22 → sidelines at ±8, panel edge at ±11

	var floor_mesh = MeshInstance3D.new()
	floor_mesh.name = "FloorMesh"
	var box = BoxMesh.new()
	box.size = Vector3(floor_x_extent, 0.2, floor_z_extent)
	floor_mesh.mesh = box
	floor_mesh.material_override = floor_material
	floor_mesh.position = Vector3(0, -0.1, 0)
	add_child(floor_mesh)
	_floor_mesh = floor_mesh
	
	# Floor collision — deliberately wider/longer than the visual court tile so
	# players have solid ground on all four sides of the boundary line.
	# Matches the inner face of the gym outer walls (GHX=18.5, GWT=0.45 → 18.05;
	# GHZ=29, GWT=0.45 → 28.55) so the entire runoff area is walkable.
	var floor_body = StaticBody3D.new()
	var floor_col = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(36.1, 0.2, 57.1)   # (18.05 * 2) × (28.55 * 2)
	floor_col.shape = floor_shape
	floor_body.position = Vector3(0, -0.1, 0)
	floor_body.add_child(floor_col)
	floor_body.collision_layer = 1
	add_child(floor_body)

func _build_court_border() -> void:
	## Solid stripe running around the outside of the court boundary.
	## Inner edge of each strip is flush with the boundary line — no bleed onto court.
	## Strips sit at y=0.001, just above the floor, to avoid z-fighting.
	const STRIPE_W  := 1.4    # stripe width (entirely outside the boundary line)
	const STRIPE_H  := 0.012  # thin slab height
	const STRIPE_Y  := 0.001

	_border_mat = StandardMaterial3D.new()
	_border_mat.albedo_color = Color(0.20, 0.09, 0.03)  # default: dark walnut
	_border_mat.roughness    = 0.82
	_border_mat.metallic     = 0.0

	var half_w   = court_width  / 2.0   # 8.0  — sidelines
	var half_l   = court_length / 2.0   # 15.0 — baselines
	var floor_hw = half_w + 3.0          # 11.0 — half of the extended floor (court_width + 6)

	# Shared helper
	var make_strip = func(n: String, pos: Vector3, sz: Vector3) -> void:
		var mi = MeshInstance3D.new()
		mi.name = n
		var bm = BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.material_override = _border_mat
		mi.position = pos
		add_child(mi)

	# Each strip's centre is offset outward by half its width so its inner edge
	# sits exactly on the boundary line with zero overlap onto the court surface.

	# ── North baseline — inner edge at z = -half_l, strip extends further north ──
	# Full extended-floor width so corners are always covered.
	make_strip.call("Border_N",
		Vector3(0, STRIPE_Y, -(half_l + STRIPE_W * 0.5)),
		Vector3(floor_hw * 2.0, STRIPE_H, STRIPE_W))

	# ── South baseline — inner edge at z = +half_l ───────────────────────────
	make_strip.call("Border_S",
		Vector3(0, STRIPE_Y,  (half_l + STRIPE_W * 0.5)),
		Vector3(floor_hw * 2.0, STRIPE_H, STRIPE_W))

	# ── East sideline — inner edge at x = +half_w ────────────────────────────
	# Length = court_length only; the baseline strips cover the four corners.
	make_strip.call("Border_E",
		Vector3( (half_w + STRIPE_W * 0.5), STRIPE_Y, 0),
		Vector3(STRIPE_W, STRIPE_H, court_length))

	# ── West sideline — inner edge at x = -half_w ────────────────────────────
	make_strip.call("Border_W",
		Vector3(-(half_w + STRIPE_W * 0.5), STRIPE_Y, 0),
		Vector3(STRIPE_W, STRIPE_H, court_length))

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
	
	for i in range(wall_configs.size()):
		var pos: Vector3  = wall_configs[i][0]
		var size: Vector3 = wall_configs[i][1]

		# Visual
		var wall_mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = size
		wall_mesh.mesh = box
		wall_mesh.material_override = wall_material
		wall_mesh.position = pos
		add_child(wall_mesh)

		# No StaticBody3D on any court wall — players can freely step out of bounds
		# on all four sides.  The physical boundary is the gym outer walls (added
		# in _build_gym_environment) and the crash-pad bodies at z = ±18.

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
	# Primary directional — near-vertical, warm white (like high windows or skylights)
	var main_light = DirectionalLight3D.new()
	main_light.name = "MainLight"
	main_light.rotation_degrees = Vector3(-80, 15, 0)
	main_light.light_energy = 0.75
	main_light.light_color = Color(1.0, 0.97, 0.93)
	main_light.shadow_enabled = true
	add_child(main_light)

	# Ambient — bright warm gray (well-lit gym ceiling)
	var env = WorldEnvironment.new()
	env.name = "WorldEnv"
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.58, 0.58, 0.60)
	environment.ambient_light_color = Color(0.58, 0.58, 0.60)
	environment.ambient_light_energy = 0.75
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.glow_enabled = false
	env.environment = environment
	add_child(env)

	# Hoop spotlights — tight white beams on each basket
	for i in range(2):
		var spot = SpotLight3D.new()
		spot.name = "HoopSpot_%d" % i
		var z = -court_length / 2 + 1.5 if i == 0 else court_length / 2 - 1.5
		spot.position = Vector3(0, 8, z)
		spot.rotation_degrees = Vector3(-90, 0, 0)
		spot.light_energy = 2.2
		spot.light_color = Color(1.0, 0.97, 0.93)
		spot.spot_range = 12.0
		spot.spot_angle = 32.0
		add_child(spot)

	# Overhead gym lights — 2-column × 3-row grid, like ceiling-mounted fluorescent banks
	var gx = court_width * 0.28
	var gz = court_length * 0.3
	var gym_light_pos = [
		Vector3(-gx, 7.0, -gz), Vector3(gx, 7.0, -gz),
		Vector3(-gx, 7.0,  0.0), Vector3(gx, 7.0,  0.0),
		Vector3(-gx, 7.0,  gz),  Vector3(gx, 7.0,  gz),
	]
	for li in range(gym_light_pos.size()):
		var omni = OmniLight3D.new()
		omni.name = "GymLight_%d" % li
		omni.position = gym_light_pos[li]
		omni.light_energy = 1.1
		omni.light_color = Color(1.0, 0.97, 0.92)
		omni.omni_range = 13.0
		add_child(omni)

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
		
	# Update overhead gym lights — tint slightly with theme, boost energy for glow themes
	for i in range(6):
		var omni: OmniLight3D = get_node_or_null("GymLight_%d" % i)
		if omni:
			omni.light_color = _current_theme.main_light_color
			omni.light_energy = 1.8 if _current_theme.glow_enabled else 1.1

func _build_center_logo() -> void:
	var logo = MeshInstance3D.new()
	logo.name = "CenterLogo"
	var cyl = CylinderMesh.new()
	cyl.top_radius = 2.28
	cyl.bottom_radius = 2.28
	cyl.height = 0.015
	cyl.radial_segments = 48
	logo.mesh = cyl
	_center_logo_mat = StandardMaterial3D.new()
	_center_logo_mat.albedo_color = Color(0.0, 0.9, 1.0, 0.12)
	_center_logo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_center_logo_mat.emission_enabled = true
	_center_logo_mat.emission = Color(0.0, 0.9, 1.0) * 0.08
	logo.material_override = _center_logo_mat
	logo.position = Vector3(0, 0.011, 0)
	add_child(logo)

func _build_crash_pads() -> void:
	_crash_pad_mats.clear()
	# Pads live in the runoff zone at z = ±(half_court + 3m), i.e. z = ±18.
	# They also carry a StaticBody3D so players physically stop here instead of at the
	# baseline wall — giving a real few meters of runoff space to chase down the ball.
	var pad_z   = court_length / 2.0 + 3.0   # 15 + 3 = 18
	var pad_w   = 12.0   # narrower than full court; bleachers visible in the gaps
	var pad_h   = 1.8
	var pad_d   = 0.3
	var pad_configs = [
		[Vector3(0, pad_h / 2.0, -pad_z), 0],  # North runoff
		[Vector3(0, pad_h / 2.0,  pad_z), 1],  # South runoff
	]
	for cfg in pad_configs:
		var pos: Vector3  = cfg[0]
		var team_idx: int = cfg[1]
		var base_color = _team0_color if team_idx == 0 else _team1_color
		var mat = StandardMaterial3D.new()
		mat.albedo_color = base_color.darkened(0.35)
		mat.roughness = 0.95
		mat.metallic = 0.0
		_crash_pad_mats.append(mat)

		# Visual
		var pad = MeshInstance3D.new()
		pad.name = "CrashPad_%d" % team_idx
		var box = BoxMesh.new()
		box.size = Vector3(pad_w, pad_h, pad_d)
		pad.mesh = box
		pad.material_override = mat
		pad.position = pos
		add_child(pad)

		# Physical barrier replacing the removed end-wall collision
		var body = StaticBody3D.new()
		body.name = "CrashPadBody_%d" % team_idx
		body.position = pos
		body.collision_layer = 1
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(pad_w, pad_h, pad_d)
		col.shape = shape
		body.add_child(col)
		add_child(body)

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

## Builds a high-gloss procedural wooden floorboard shader for Pro Arena
func _build_procedural_wood_material(theme: CourtTheme) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_wood_color : source_color = vec3(0.8, 0.6, 0.4);
uniform vec3 dark_wood_color : source_color = vec3(0.6, 0.4, 0.2);
uniform float plank_width = 0.5;
uniform float plank_length = 3.0;
uniform float court_width = 16.0;
uniform float court_length = 34.0;

// Pseudo-random function
float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// World UVs
	float world_x = (UV.x - 0.5) * court_width;
	float world_z = (UV.y - 0.5) * court_length;
	
	// Determine which plank column we are in
	float col = floor(world_x / plank_width);
	// Stagger the planks based on the column
	float stagger = rand(vec2(col, 0.0)) * plank_length;
	// Determine which row we are in within that column
	float row = floor((world_z + stagger) / plank_length);
	
	// Create a unique seed for this specific plank
	vec2 plank_id = vec2(col, row);
	float plank_rand = rand(plank_id);
	
	// Mix between light and dark wood based on plank ID
	vec3 wood_col = mix(dark_wood_color, base_wood_color, 0.4 + 0.6 * plank_rand);
	
	// Add some faux procedural grain (simple high-frequency noise stretched along Z)
	float grain = rand(vec2(world_x * 50.0, world_z * 2.0));
	wood_col *= mix(0.9, 1.1, grain);
	
	// Very thin dark lines between planks
	float edge_x = fract(world_x / plank_width);
	float edge_z = fract((world_z + stagger) / plank_length);
	if (edge_x < 0.02 || edge_x > 0.98 || edge_z < 0.01 || edge_z > 0.99) {
		wood_col *= 0.5; // Darken edges
	}
	
	ALBEDO = wood_col;
	ROUGHNESS = mix(0.1, 0.25, grain); // Highly glossy but grain affects it
	METALLIC = 0.05;
}
"""
	mat.shader = shader
	mat.set_shader_parameter("base_wood_color", Vector3(0.85, 0.65, 0.45))
	mat.set_shader_parameter("dark_wood_color", Vector3(0.70, 0.50, 0.30))
	mat.set_shader_parameter("plank_width", 0.5)
	mat.set_shader_parameter("plank_length", 3.0)
	mat.set_shader_parameter("court_width", court_width)
	mat.set_shader_parameter("court_length", court_length + 4.0)
	return mat

# ─────────────────────────────────────────────────────────────────────────────
#  DYNAMIC ENVIRONMENT SYSTEM
#  apply_theme() calls _rebuild_environment() to swap the outer shell.
# ─────────────────────────────────────────────────────────────────────────────

func _clear_environment() -> void:
	if _env_root and is_instance_valid(_env_root):
		_env_root.queue_free()
	_env_root = null

## Choose and build the correct environment for the given theme.
## Called from apply_theme() every time a court theme is applied.
func _rebuild_environment(theme: CourtTheme) -> void:
	if theme == null:
		return
	var needs_cage    = "cage_walls"   in theme and theme.cage_walls
	var needs_outdoor = "outdoor"      in theme and theme.outdoor
	var needs_garage  = ("low_ceiling" in theme and theme.low_ceiling) or \
						("has_pillars" in theme and theme.has_pillars)

	# Only rebuild if the environment type is actually different from the default gym
	if not needs_cage and not needs_outdoor and not needs_garage:
		return  # keep existing gym environment

	_clear_environment()

	if needs_cage:
		_build_cage_environment()
	elif needs_outdoor:
		_build_outdoor_environment()
	elif needs_garage:
		_build_garage_environment()

# ─────────────────────────────────────────────────────────────────────────────
#  THE CAGE — enclosed street court with chain-link fence walls
# ─────────────────────────────────────────────────────────────────────────────
func _build_cage_environment() -> void:
	_env_root = Node3D.new()
	_env_root.name = "CageEnvironment"
	add_child(_env_root)

	var hw: float = court_width  / 2.0 + 0.8   # fence X half-distance  (8.8 m from centre)
	var hl: float = court_length / 2.0 + 0.8   # fence Z half-distance  (15.8 m from centre)
	var cage_h: float = 5.5

	# ── Chain-link fence panels (visual) ─────────────────────────────────
	var fence_mat = StandardMaterial3D.new()
	fence_mat.albedo_color         = Color(0.40, 0.38, 0.34, 0.82)
	fence_mat.transparency         = BaseMaterial3D.TRANSPARENCY_ALPHA
	fence_mat.roughness            = 0.88
	fence_mat.metallic             = 0.35

	var fence_configs: Array = [
		[Vector3(0,       cage_h * 0.5, -hl ), Vector3(hw * 2.0, cage_h, 0.15)],  # North
		[Vector3(0,       cage_h * 0.5,  hl ), Vector3(hw * 2.0, cage_h, 0.15)],  # South
		[Vector3(-hw,     cage_h * 0.5,  0  ), Vector3(0.15, cage_h, hl  * 2.0)],  # West
		[Vector3( hw,     cage_h * 0.5,  0  ), Vector3(0.15, cage_h, hl  * 2.0)],  # East
	]

	for fc in fence_configs:
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size  = fc[1]
		mi.mesh  = bm
		mi.material_override = fence_mat
		mi.position = fc[0]
		_env_root.add_child(mi)

		# Physical wall so ball bounces back
		var body = StaticBody3D.new()
		body.position        = fc[0]
		body.collision_layer = 1
		var col   = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size  = fc[1]
		col.shape   = shape
		body.add_child(col)
		_env_root.add_child(body)

	# ── Vertical steel posts ──────────────────────────────────────────────
	var post_mat = StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.30, 0.28, 0.25)
	post_mat.metallic     = 0.65
	post_mat.roughness    = 0.45

	var post_xs: Array = [-hw, -hw * 0.5, 0.0, hw * 0.5,  hw]
	var post_zs: Array = [-hl, hl]
	for px in post_xs:
		for pz in post_zs:
			var post = MeshInstance3D.new()
			var pm   = CylinderMesh.new()
			pm.top_radius    = 0.06
			pm.bottom_radius = 0.06
			pm.height        = cage_h
			post.mesh = pm
			post.material_override = post_mat
			post.position = Vector3(px, cage_h * 0.5, pz)
			_env_root.add_child(post)
	var side_zs: Array = [-hl * 0.5, 0.0, hl * 0.5]
	for pz2 in side_zs:
		for px2 in [-hw, hw]:
			var post2 = MeshInstance3D.new()
			var pm2   = CylinderMesh.new()
			pm2.top_radius    = 0.06
			pm2.bottom_radius = 0.06
			pm2.height        = cage_h
			post2.mesh = pm2
			post2.material_override = post_mat
			post2.position = Vector3(px2, cage_h * 0.5, pz2)
			_env_root.add_child(post2)

	# ── Floodlights on corner posts ───────────────────────────────────────
	for fl_corner in [Vector3(-hw + 1.0, cage_h - 0.6, -hl + 1.0),
					   Vector3( hw - 1.0, cage_h - 0.6, -hl + 1.0),
					   Vector3(-hw + 1.0, cage_h - 0.6,  hl - 1.0),
					   Vector3( hw - 1.0, cage_h - 0.6,  hl - 1.0)]:
		var spot = OmniLight3D.new()
		spot.position      = fl_corner
		spot.light_energy  = 1.6
		spot.light_color   = Color(0.95, 0.88, 0.70)
		spot.omni_range    = 22.0
		_env_root.add_child(spot)

	# ── Dark asphalt runoff around the court ─────────────────────────────
	var asphalt_mat = StandardMaterial3D.new()
	asphalt_mat.albedo_color = Color(0.15, 0.14, 0.12)
	asphalt_mat.roughness    = 0.96
	var runoff_strips: Array = [
		[Vector3(0, -0.09, -(court_length * 0.5 + 0.4)), Vector3(hw * 2.0, 0.16, 0.8)],  # North gap
		[Vector3(0, -0.09,  (court_length * 0.5 + 0.4)), Vector3(hw * 2.0, 0.16, 0.8)],  # South gap
		[Vector3(-(court_width * 0.5 + 0.4), -0.09, 0), Vector3(0.8, 0.16, court_length + 1.6)],  # West
		[Vector3( (court_width * 0.5 + 0.4), -0.09, 0), Vector3(0.8, 0.16, court_length + 1.6)],  # East
	]
	for rs in runoff_strips:
		var ri = MeshInstance3D.new()
		var rb = BoxMesh.new()
		rb.size = rs[1]
		ri.mesh = rb
		ri.material_override = asphalt_mat
		ri.position = rs[0]
		_env_root.add_child(ri)

# ─────────────────────────────────────────────────────────────────────────────
#  ROOFTOP — open air, no enclosure, city backdrop
# ─────────────────────────────────────────────────────────────────────────────
func _build_outdoor_environment() -> void:
	_env_root = Node3D.new()
	_env_root.name = "OutdoorEnvironment"
	add_child(_env_root)

	var ext: float = 9.0   # how far the rooftop extends past the court
	var pw : float = court_width  / 2.0 + ext
	var pl : float = court_length / 2.0 + ext

	# ── Concrete rooftop surface ──────────────────────────────────────────
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.38, 0.36, 0.33)
	roof_mat.roughness    = 0.92
	for tile in [
		[Vector3(0, -0.09, -(court_length * 0.5 + ext * 0.5)), Vector3(pw * 2.0, 0.16, ext)],  # North
		[Vector3(0, -0.09,  (court_length * 0.5 + ext * 0.5)), Vector3(pw * 2.0, 0.16, ext)],  # South
		[Vector3(-(court_width * 0.5 + ext * 0.5), -0.09, 0), Vector3(ext, 0.16, court_length)],  # West
		[Vector3( (court_width * 0.5 + ext * 0.5), -0.09, 0), Vector3(ext, 0.16, court_length)],  # East
	]:
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = tile[1]
		mi.mesh = bm
		mi.material_override = roof_mat
		mi.position = tile[0]
		_env_root.add_child(mi)

	# ── Parapet walls (visual only — ball going over = OOB as normal) ─────
	var par_mat = StandardMaterial3D.new()
	par_mat.albedo_color = Color(0.44, 0.42, 0.39)
	par_mat.roughness    = 0.90
	var par_h: float = 1.2
	var par_t: float = 0.45
	for pc in [
		[Vector3(0, par_h * 0.5, -pl), Vector3(pw * 2.0, par_h, par_t)],
		[Vector3(0, par_h * 0.5,  pl), Vector3(pw * 2.0, par_h, par_t)],
		[Vector3(-pw, par_h * 0.5, 0), Vector3(par_t, par_h, pl * 2.0)],
		[Vector3( pw, par_h * 0.5, 0), Vector3(par_t, par_h, pl * 2.0)],
	]:
		var mi2 = MeshInstance3D.new()
		var bm2 = BoxMesh.new()
		bm2.size = pc[1]
		mi2.mesh = bm2
		mi2.material_override = par_mat
		mi2.position = pc[0]
		_env_root.add_child(mi2)

	# ── City skyline (silhouette buildings in the distance) ───────────────
	var bldg_mat = StandardMaterial3D.new()
	bldg_mat.albedo_color = Color(0.12, 0.15, 0.20)
	bldg_mat.roughness    = 0.95
	var rng = RandomNumberGenerator.new()
	rng.seed = 7331
	for i in range(24):
		var bh: float = rng.randf_range(18.0, 50.0)
		var bw: float = rng.randf_range(5.0, 14.0)
		var bd: float = rng.randf_range(5.0, 12.0)
		var dist: float = rng.randf_range(55.0, 100.0)
		var angle: float = (float(i) / 24.0) * TAU + rng.randf_range(-0.15, 0.15)
		var bldg = MeshInstance3D.new()
		var bm3  = BoxMesh.new()
		bm3.size = Vector3(bw, bh, bd)
		bldg.mesh = bm3
		bldg.material_override = bldg_mat
		bldg.position = Vector3(cos(angle) * dist, bh * 0.5 - 1.0, sin(angle) * dist)
		_env_root.add_child(bldg)

	# ── AC units and rooftop equipment ────────────────────────────────────
	var equip_mat = StandardMaterial3D.new()
	equip_mat.albedo_color = Color(0.50, 0.49, 0.47)
	equip_mat.roughness    = 0.85
	var equip_pos: Array = [
		Vector3(-pw + 1.5, 0.4,  pl - 2.0),
		Vector3( pw - 1.5, 0.4,  pl - 2.0),
		Vector3(-pw + 1.5, 0.4, -pl + 2.0),
		Vector3( pw - 1.5, 0.4, -pl + 2.0),
	]
	for ep in equip_pos:
		var em = MeshInstance3D.new()
		var eb = BoxMesh.new()
		eb.size = Vector3(2.0, 0.8, 1.2)
		em.mesh = eb
		em.material_override = equip_mat
		em.position = ep
		_env_root.add_child(em)

# ─────────────────────────────────────────────────────────────────────────────
#  UNDERGROUND GARAGE — low ceiling, concrete pillars, dim fluorescents
# ─────────────────────────────────────────────────────────────────────────────
func _build_garage_environment() -> void:
	_env_root = Node3D.new()
	_env_root.name = "GarageEnvironment"
	add_child(_env_root)

	var GHX : float = 16.5
	var GHZ : float = 21.0
	var GH  : float = 4.8   # low ceiling height
	var GWT : float = 0.5

	var concrete_mat = StandardMaterial3D.new()
	concrete_mat.albedo_color = Color(0.28, 0.27, 0.25)
	concrete_mat.roughness    = 0.95

	# ── Outer concrete walls (visual + collision) ─────────────────────────
	var wall_cfgs: Array = [
		["GarageWall_N", Vector3(0,      GH * 0.5, -GHZ), Vector3(GHX * 2.0, GH, GWT)],
		["GarageWall_S", Vector3(0,      GH * 0.5,  GHZ), Vector3(GHX * 2.0, GH, GWT)],
		["GarageWall_E", Vector3( GHX,   GH * 0.5,  0.0), Vector3(GWT, GH, GHZ * 2.0)],
		["GarageWall_W", Vector3(-GHX,   GH * 0.5,  0.0), Vector3(GWT, GH, GHZ * 2.0)],
	]
	for wc in wall_cfgs:
		var mi = MeshInstance3D.new()
		mi.name = wc[0]
		var bm = BoxMesh.new()
		bm.size = wc[2]
		mi.mesh = bm
		mi.material_override = concrete_mat
		mi.position = wc[1]
		_env_root.add_child(mi)
		var body = StaticBody3D.new()
		body.position        = wc[1]
		body.collision_layer = 1
		var col   = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size  = wc[2]
		col.shape   = shape
		body.add_child(col)
		_env_root.add_child(body)

	# ── Low ceiling (visual + collision) ─────────────────────────────────
	var ceil_mi = MeshInstance3D.new()
	ceil_mi.name = "GarageCeiling"
	var cb = BoxMesh.new()
	cb.size = Vector3(GHX * 2.0, 0.35, GHZ * 2.0)
	ceil_mi.mesh = cb
	ceil_mi.material_override = concrete_mat
	ceil_mi.position = Vector3(0, GH + 0.175, 0)
	_env_root.add_child(ceil_mi)

	var ceil_body = StaticBody3D.new()
	ceil_body.position        = Vector3(0, GH, 0)
	ceil_body.collision_layer = 1
	var ceil_col   = CollisionShape3D.new()
	var ceil_shape = BoxShape3D.new()
	ceil_shape.size = Vector3(GHX * 2.0, 0.35, GHZ * 2.0)
	ceil_col.shape  = ceil_shape
	ceil_body.add_child(ceil_col)
	_env_root.add_child(ceil_body)

	# ── Concrete pillars (visual + collision) ────────────────────────────
	var pillar_mat = StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.22, 0.21, 0.19)
	pillar_mat.roughness    = 0.97

	var pillar_sz  = Vector3(0.65, GH, 0.65)
	var pillar_pos: Array = [
		Vector3(-6.5, GH * 0.5, -11.5), Vector3(6.5, GH * 0.5, -11.5),
		Vector3(-6.5, GH * 0.5,   0.0), Vector3(6.5, GH * 0.5,   0.0),
		Vector3(-6.5, GH * 0.5,  11.5), Vector3(6.5, GH * 0.5,  11.5),
	]
	for pp in pillar_pos:
		var pi = MeshInstance3D.new()
		var pb = BoxMesh.new()
		pb.size = pillar_sz
		pi.mesh = pb
		pi.material_override = pillar_mat
		pi.position = pp
		_env_root.add_child(pi)
		var pb2 = StaticBody3D.new()
		pb2.position        = pp
		pb2.collision_layer = 1
		var pcol   = CollisionShape3D.new()
		var pshape = BoxShape3D.new()
		pshape.size = pillar_sz
		pcol.shape  = pshape
		pb2.add_child(pcol)
		_env_root.add_child(pb2)

	# ── Fluorescent light fixtures on ceiling ─────────────────────────────
	var fix_mat = StandardMaterial3D.new()
	fix_mat.albedo_color     = Color(0.85, 0.88, 0.70)
	fix_mat.emission_enabled = true
	fix_mat.emission         = Color(0.85, 0.88, 0.70) * 0.6

	var light_rows: Array = [-court_length * 0.28, 0.0, court_length * 0.28]
	var light_cols: Array = [-court_width * 0.28, court_width * 0.28]
	var li_idx: int = 0
	for lz in light_rows:
		for lx in light_cols:
			# Fixture box
			var fix = MeshInstance3D.new()
			var fb  = BoxMesh.new()
			fb.size = Vector3(0.25, 0.08, 1.4)
			fix.mesh = fb
			fix.material_override = fix_mat
			fix.position = Vector3(lx, GH - 0.05, lz)
			_env_root.add_child(fix)
			# OmniLight
			var omni = OmniLight3D.new()
			omni.name          = "GarageLight_%d" % li_idx
			omni.position      = Vector3(lx, GH - 0.12, lz)
			omni.light_energy  = 1.1
			omni.light_color   = Color(0.82, 0.86, 0.62)
			omni.omni_range    = 9.5
			_env_root.add_child(omni)
			li_idx += 1

	# ── Parking-stripe markings on the runoff floor ───────────────────────
	var stripe_mat = StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.78, 0.72, 0.20, 0.55)
	stripe_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var stripe_xs: Array = [-14.0, -11.5, 11.5, 14.0]
	for sx in stripe_xs:
		var sm = MeshInstance3D.new()
		var sb = BoxMesh.new()
		sb.size = Vector3(0.12, 0.005, GHZ * 1.6)
		sm.mesh = sb
		sm.material_override = stripe_mat
		sm.position = Vector3(sx, 0.005, 0)
		_env_root.add_child(sm)
