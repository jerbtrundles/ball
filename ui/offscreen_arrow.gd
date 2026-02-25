extends Control
## Off-screen player arrow — shows a border arrow pointing toward your player when off camera.

var human_player: CharacterBody3D = null
var camera: Camera3D = null
var arrow_color: Color = Color(1.0, 1.0, 0.0, 0.9)  # Yellow
var arrow_size: float = 20.0
var edge_margin: float = 40.0

func _ready() -> void:
	# Make this control fill the screen
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	await get_tree().create_timer(0.6).timeout
	_find_references()

func _find_references() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if "is_human" in p and p.is_human:
			human_player = p
			break
	camera = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if human_player == null or camera == null:
		return
	
	# Project player position to screen
	var screen_pos = camera.unproject_position(human_player.global_position + Vector3(0, 0.8, 0))
	var vp_size = get_viewport_rect().size
	
	# Check if on screen (with margin)
	var on_screen = (screen_pos.x > edge_margin and screen_pos.x < vp_size.x - edge_margin
		and screen_pos.y > edge_margin and screen_pos.y < vp_size.y - edge_margin)
	
	# Also check if player is behind camera
	var behind_camera = camera.is_position_behind(human_player.global_position)
	
	if on_screen and not behind_camera:
		return  # Player is visible, no arrow needed
	
	# If behind camera, flip the screen position
	if behind_camera:
		screen_pos = vp_size - screen_pos
	
	# Clamp to screen edges with margin
	var center = vp_size / 2.0
	var dir = (screen_pos - center).normalized()
	
	# Find the edge intersection
	var clamped_pos = _clamp_to_edge(center, dir, vp_size)
	
	# Draw arrow at clamped position pointing outward
	_draw_arrow(clamped_pos, dir)

func _clamp_to_edge(center: Vector2, dir: Vector2, vp_size: Vector2) -> Vector2:
	# Ray from center in direction dir, find where it hits screen edge
	var max_x = vp_size.x - edge_margin
	var max_y = vp_size.y - edge_margin
	var min_x = edge_margin
	var min_y = edge_margin
	
	var t_min = 99999.0
	
	# Check each edge
	if dir.x > 0.001:
		var t = (max_x - center.x) / dir.x
		t_min = min(t_min, t)
	elif dir.x < -0.001:
		var t = (min_x - center.x) / dir.x
		t_min = min(t_min, t)
	
	if dir.y > 0.001:
		var t = (max_y - center.y) / dir.y
		t_min = min(t_min, t)
	elif dir.y < -0.001:
		var t = (min_y - center.y) / dir.y
		t_min = min(t_min, t)
	
	return center + dir * t_min

func _draw_arrow(pos: Vector2, dir: Vector2) -> void:
	# Arrow triangle pointing in direction of player
	var perp = Vector2(-dir.y, dir.x)
	var tip = pos
	var base1 = pos - dir * arrow_size + perp * arrow_size * 0.6
	var base2 = pos - dir * arrow_size - perp * arrow_size * 0.6
	
	var points = PackedVector2Array([tip, base1, base2])
	var colors = PackedColorArray([arrow_color, arrow_color, arrow_color])
	draw_polygon(points, colors)
	
	# Outline for visibility
	draw_line(tip, base1, Color.BLACK, 2.0)
	draw_line(base1, base2, Color.BLACK, 2.0)
	draw_line(base2, tip, Color.BLACK, 2.0)
	
	# Small inner triangle (brighter)
	var inner_tip = pos - dir * 2.0
	var inner_b1 = pos - dir * (arrow_size * 0.6) + perp * arrow_size * 0.25
	var inner_b2 = pos - dir * (arrow_size * 0.6) - perp * arrow_size * 0.25
	var inner_pts = PackedVector2Array([inner_tip, inner_b1, inner_b2])
	var inner_colors = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
	draw_polygon(inner_pts, inner_colors)
