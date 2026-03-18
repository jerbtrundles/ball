extends Node3D
## Game Manager — controls match state, scoring, clock, tip-off, throw-ins, and game flow.

signal score_changed(team_index: int, new_score: int)
signal clock_changed(time_remaining: float)
signal quarter_changed(quarter: int)
signal game_over(winner_team: int)
signal ball_possession_changed(player: Node3D)
signal throw_in_started(team_index: int)
signal teams_updated(team0_data: Resource, team1_data: Resource)

enum MatchState { PRE_GAME, TIP_OFF, PLAYING, SCORED, THROW_IN, QUARTER_BREAK, GAME_OVER, INBOUND }

# --- Config ---
@export var quarter_duration: float = 30.0  # 30 seconds for testing
@export var total_quarters: int = 4
@export var quarter_break_duration: float = 3.0
@export var throw_in_delay: float = 1.0

# --- State ---
var match_state: MatchState = MatchState.PRE_GAME
var is_debug: bool = false
var is_season_game: bool = false
var is_tournament_game: bool = false
var is_survival_game: bool = false
var no_out_of_bounds: bool = false  # True for The Cage — OOB signal is ignored
var current_quarter: int = 1
var time_remaining: float = 0.0
var scores: Array[int] = [0, 0]
var free_points: Array[int] = [0, 0]
var player_stats: Array[Array] = [[], []]
var ball: RigidBody3D = null
var teams: Array = [[], []]
var team_data_store: Array = [null, null] # Store TeamData resources
var possession_team: int = -1
var sides_flipped: bool = false
var tip_off_winner: int = -1   # Team that won the initial tip-off
var possession_arrow: int = -1 # Alternating possession: next inbound goes to this team

# Wall scoreboard
var _sb_score_labels: Array[Label3D] = []
var _sb_quarter_label: Label3D = null
var _sb_built: bool = false


# Court geometry
var court_length: float = 30.0
var court_width: float = 16.0
var court_half_w: float = 8.0
var court_half_l: float = 15.0
var three_point_distance: float = 7.5
var hoop_positions: Array[Vector3] = [
	Vector3(0, 3.0, -14.0),
	Vector3(0, 3.0, 14.0),
]

# Tip-off positions (relative to center) — up to 5 per team
var tip_off_positions_team0: Array[Vector3] = [
	Vector3(0, 0, -2.0),   # Center player (jumper)
	Vector3(-3, 0, -5.0),  # Left wing
	Vector3(3, 0, -5.0),   # Right wing
	Vector3(-5, 0, -8.0),  # Left corner (4v4+)
	Vector3(5, 0, -8.0),   # Right corner (5v5)
]
var tip_off_positions_team1: Array[Vector3] = [
	Vector3(0, 0, 2.0),
	Vector3(-3, 0, 5.0),
	Vector3(3, 0, 5.0),
	Vector3(-5, 0, 8.0),
	Vector3(5, 0, 8.0),
]

func _ready() -> void:
	add_to_group("game_manager")
	time_remaining = quarter_duration
	ball = get_node_or_null("../Ball")
	if ball:
		ball.went_out_of_bounds.connect(_on_ball_out_of_bounds)
	
	# Create hazard spawner
	_create_hazard_spawner()
	
	# Connect screen shake
	var vfx = get_node_or_null("/root/VFX")
	if vfx:
		vfx.screen_shake_requested.connect(_on_screen_shake)
	
	# In-Game Soundtrack (Cybernetic Wasteland)
	var music = AudioStreamPlayer.new()
	var stream = load("res://assets/sounds/Cybernetic_Wasteland.mp3")
	if stream is AudioStreamMP3:
		stream.loop = true
	music.stream = stream
	music.bus = "Music"
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)
	music.play()
		
	await get_tree().process_frame
	
	# Check for pending match from LeagueManager
	if LeagueManager.pending_match_data.has("team_a"):
		var data = LeagueManager.pending_match_data
		setup_match(data["team_a"], data["team_b"], data.get("config", {}))
		LeagueManager.clear_pending_match()
		return
	
	# If no pending match, verify if we found teams from the scene (debug play in editor)
	_find_teams()
	if teams[0].size() > 0 and teams[1].size() > 0:
		start_match()

func setup_match(team0_data: Resource, team1_data: Resource, config: Dictionary = {}) -> void:
	# Apply Config
	if config.has("quarter_duration"):
		quarter_duration = config["quarter_duration"]
		time_remaining = quarter_duration
	
	is_debug = config.get("is_debug", false)
	is_season_game = config.get("is_season_game", false)
	is_tournament_game = config.get("is_tournament_game", false)
	is_survival_game = config.get("is_survival_game", false)
	no_out_of_bounds = config.get("no_out_of_bounds", false)
	
	var items_enabled = config.get("items_enabled", true)
	var human_team = config.get("human_team_index", 0)
	var team_size = config.get("team_size", 3)
	
	# Set player team index so items/scoring know which team is the human's
	LeagueManager.player_team_index = human_team
	
	# Clear existing players
	get_tree().call_group("players", "queue_free")
	await get_tree().process_frame # Wait for deletion
	
	# Disable hazard spawner if items disabled
	var hazard_spawner = get_node_or_null("HazardSpawner")
	if hazard_spawner:
		if "is_debug" in hazard_spawner:
			hazard_spawner.is_debug = is_debug
		hazard_spawner.process_mode = Node.PROCESS_MODE_INHERIT if items_enabled else Node.PROCESS_MODE_DISABLED
		if not items_enabled:
			# Also clear existing hazards
			get_tree().call_group("hazards", "queue_free")
		else:
			# Apply per-item config if provided
			var enabled_items = config.get("enabled_items", {})
			if not enabled_items.is_empty() and "enabled_types" in hazard_spawner:
				for item_type in enabled_items:
					hazard_spawner.enabled_types[item_type] = enabled_items[item_type]
	
	teams = [[], []]
	player_stats = [[], []]
	free_points = [0, 0]
	team_data_store = [team0_data, team1_data]
	teams_updated.emit(team0_data, team1_data)
	var PlayerScene = load("res://scenes/characters/player.tscn")

	SceneManager.report_progress(0.93, "Spawning players…")

	# Spawn Team 0
	_spawn_team(team0_data, 0, PlayerScene, human_team, team_size)

	SceneManager.report_progress(0.95, "Spawning players…")

	# Spawn Team 1
	_spawn_team(team1_data, 1, PlayerScene, human_team, team_size)

	SceneManager.report_progress(0.97, "Applying court theme…")

	# Apply Court Theme
	var theme_index = config.get("court_theme_index", 0)
	_apply_court_theme(theme_index, team0_data)

	# Wall scoreboard (built once per match; destroyed with the scene)
	if not _sb_built:
		_build_wall_scoreboard()
		score_changed.connect(_update_scoreboard)
		quarter_changed.connect(_update_scoreboard_quarter)
		_sb_built = true

	SceneManager.report_progress(0.99, "Starting match…")

	# Start match
	start_match()

	# Loading screen can now be dismissed — match is fully ready
	SceneManager.notify_scene_ready()

func _apply_court_theme(theme_index: int, home_team: Resource) -> void:
	var court_builder = get_tree().get_first_node_in_group("court_builder")
	if not court_builder or not court_builder.has_method("apply_theme"):
		return

	var theme: CourtTheme = CourtThemes.get_preset(theme_index, home_team)
	var t0_color = home_team.color_primary if home_team else Color(0.2, 0.5, 1.0)
	var t1_color = team_data_store[1].color_primary if team_data_store[1] else Color(1.0, 0.3, 0.2)
	court_builder.apply_theme(theme, t0_color, t1_color)

	# Inherit OOB behaviour from the court theme (e.g. The Cage disables OOB)
	if theme and "no_out_of_bounds" in theme and theme.no_out_of_bounds:
		no_out_of_bounds = true

func _spawn_team(team_data: Resource, team_idx: int, player_scene: PackedScene, human_team_idx: int, team_size: int = 3) -> void:
	var roster = team_data.roster
	var tip_off_pos = tip_off_positions_team0 if team_idx == 0 else tip_off_positions_team1
	var spawn_count = mini(roster.size(), team_size)
	
	for i in range(spawn_count):
		var p_data = roster[i]
		var player = player_scene.instantiate()
		player.name = "Player_%d_%d" % [team_idx, i]
		
		# Set properties BEFORE adding to tree
		player.team_index = team_idx
		player.roster_index = i
		player.player_name = p_data.name
		player.jersey_number = p_data.number if "number" in p_data else (10 + i) 
		if "logo" in team_data:
			player.team_logo = team_data.logo
		
		# Human Control
		if team_idx == human_team_idx and i == 0:
			player.is_human = true
		else:
			# Add AI Controller
			var ai_script = load("res://scripts/ai_controller.gd")
			if ai_script:
				var ai = ai_script.new()
				ai.name = "AIController"
				player.add_child(ai)
				ai.player = player
		
		# Apply Stats
		player.move_speed   = 6.0  + (p_data.speed     * 0.04)
		# Sprint multiplier scales with speed: slow players get 1.5×, fast players up to ~1.8×
		player.sprint_speed = player.move_speed * (1.5 + p_data.speed * 0.003)
		player.shot_power   = 10.0 + (p_data.shot      * 0.05)
		player.shot_skill   = p_data.shot   # 0-99 accuracy rating for shot-% formula
		player.pass_power   = 12.0 + (p_data.pass_skill * 0.05)
		player.tackle_force = 12.0 + (p_data.tackle    * 0.06)
		player.strength     = 1.0  + (p_data.strength  * 0.01)
		player.aggressiveness = p_data.aggression
		# Physical traits (set before add_sibling so _setup_visuals picks them up)
		player.body_height  = p_data.body_height
		player.body_build   = p_data.body_build
		player.skin_tone    = p_data.skin_tone
		
		# Colors
		if "custom_team_color" in player:
			player.custom_team_color = team_data.color_primary
		
		# Position
		if i < tip_off_pos.size():
			player.global_position = tip_off_pos[i]
		else:
			player.global_position = Vector3(10 * (team_idx * 2 - 1), 0, 10 + i)
		
		add_sibling(player) # Add to scene
			
		teams[team_idx].append(player)
		
		# Append player stats
		var stat_dict = {
			"name": p_data.name,
			"points": 0,
			"2pt": 0,
			"3pt": 0,
			"fgm": 0,
			"fga": 0,
			"tpm": 0,
			"tpa": 0,
			"rebounds": 0,
			"assists": 0,
			"steals": 0,
			"coins": 0,
			"powerups": 0
		}
		player_stats[team_idx].append(stat_dict)
		
		# Add jersey labels
		_add_jersey_labels(player)

	# Update UI with team names?
	pass

func _find_teams() -> void:
	teams = [[], []]
	player_stats = [[], []]
	for player in get_tree().get_nodes_in_group("players"):
		if "team_index" in player:
			var t = player.team_index
			player.roster_index = teams[t].size()
			teams[t].append(player)
			
			var p_name = player.get("player_name") if player.get("player_name") else "Player"
			var stat_dict = {
				"name": p_name,
				"points": 0,
				"2pt": 0,
				"3pt": 0,
				"fgm": 0,
				"fga": 0,
				"tpm": 0,
				"tpa": 0,
				"rebounds": 0,
				"assists": 0,
				"steals": 0,
				"coins": 0,
				"powerups": 0
			}
			player_stats[t].append(stat_dict)
	
	# Assign jersey numbers (1-based per team)
	for t in range(2):
		var jersey_numbers_pool = [1, 3, 5, 7, 11, 13, 15, 23, 24, 33]
		for i in range(teams[t].size()):
			var p = teams[t][i]
			if "jersey_number" in p:
				p.jersey_number = jersey_numbers_pool[i % jersey_numbers_pool.size()]
				# Add jersey labels since _setup_visuals already ran before we set the number
				_add_jersey_labels(p)

func _build_wall_scoreboard() -> void:
	## Mounts a scoreboard panel on the inner face of the North gym wall.
	## The North wall sits at z = -29.0 (GHZ); its inner face is at z ≈ -28.55.
	## Labels face south (rotation_degrees.y = 180) so they read from the court.
	const SB_Z   := -28.4    # just inside north wall inner face
	const SB_Y   := 6.8      # mid-height — above foam pads, below windows
	const PSIZE  := 0.014    # pixel_size for all scoreboard labels
	const FS_NAME := 72      # font_size for team names
	const FS_SCORE := 110    # font_size for score digits
	const FS_SMALL := 48     # font_size for quarter label

	var t0 = team_data_store[0]
	var t1 = team_data_store[1]
	var name0 = t0.name.to_upper() if t0 else "HOME"
	var name1 = t1.name.to_upper() if t1 else "AWAY"
	var col0  = t0.color_primary if t0 else Color(0.2, 0.5, 1.0)
	var col1  = t1.color_primary if t1 else Color(1.0, 0.3, 0.2)

	var sb_root = Node3D.new()
	sb_root.name = "WallScoreboard"
	add_child(sb_root)

	# ── Backing panel ────────────────────────────────────────────────────────
	var panel = MeshInstance3D.new()
	var pm = BoxMesh.new()
	pm.size = Vector3(11.0, 2.8, 0.18)
	panel.mesh = pm
	var panel_mat = StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.06, 0.06, 0.08)
	panel_mat.roughness = 0.9
	panel.material_override = panel_mat
	panel.position = Vector3(0, SB_Y, SB_Z)
	sb_root.add_child(panel)

	# Thin accent border (slightly proud of panel face)
	var border = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(11.2, 2.95, 0.06)
	border.mesh = bm
	var border_mat = StandardMaterial3D.new()
	border_mat.albedo_color = Color(0.3, 0.3, 0.35)
	border_mat.roughness = 0.8
	border.material_override = border_mat
	border.position = Vector3(0, SB_Y, SB_Z + 0.12)
	sb_root.add_child(border)

	# ── Helper: create a Label3D facing south ────────────────────────────────
	var make_label = func(txt: String, fs: int, col: Color, x: float, y: float, bold := false) -> Label3D:
		var lbl = Label3D.new()
		lbl.text = txt
		lbl.font_size = fs
		lbl.pixel_size = PSIZE
		lbl.modulate = col
		lbl.outline_size = 8
		lbl.outline_modulate = Color(0, 0, 0, 0.8)
		lbl.position = Vector3(x, y, SB_Z - 0.12)   # face of panel (south side)
		lbl.rotation_degrees = Vector3(0, 180, 0)     # face into the court
		lbl.no_depth_test = false
		lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sb_root.add_child(lbl)
		return lbl

	# ── Team 0 (left side) ───────────────────────────────────────────────────
	make_label.call(name0, FS_NAME, col0, -3.8, SB_Y + 0.75)
	var sc0: Label3D = make_label.call("0", FS_SCORE, Color.WHITE, -3.8, SB_Y - 0.30)
	_sb_score_labels.append(sc0)

	# ── Divider "–" ──────────────────────────────────────────────────────────
	make_label.call("—", FS_SCORE, Color(0.4, 0.4, 0.45), 0.0, SB_Y - 0.30)

	# ── Team 1 (right side) ──────────────────────────────────────────────────
	make_label.call(name1, FS_NAME, col1, 3.8, SB_Y + 0.75)
	var sc1: Label3D = make_label.call("0", FS_SCORE, Color.WHITE, 3.8, SB_Y - 0.30)
	_sb_score_labels.append(sc1)

	# ── Quarter label (bottom center) ────────────────────────────────────────
	_sb_quarter_label = make_label.call("Q1", FS_SMALL, Color(0.7, 0.7, 0.75), 0.0, SB_Y + 0.72)

func _update_scoreboard(team_index: int, new_score: int) -> void:
	if team_index < _sb_score_labels.size() and is_instance_valid(_sb_score_labels[team_index]):
		_sb_score_labels[team_index].text = str(new_score)

func _update_scoreboard_quarter(q: int) -> void:
	if is_instance_valid(_sb_quarter_label):
		_sb_quarter_label.text = "Q%d" % q

func _add_jersey_labels(player_node: CharacterBody3D) -> void:
	# Get the torso so labels parent to it and move/scale with the model
	var torso = player_node.get_node_or_null("ModelRoot/Torso")
	var label_parent: Node3D = torso if torso else player_node

	# Remove existing labels from both possible parents
	for child in player_node.get_children():
		if child.name.begins_with("JerseyNum_") or child.name.begins_with("JerseyName_") or child.name == "JerseyLogo":
			child.queue_free()
	if torso:
		for child in torso.get_children():
			if child.name.begins_with("JerseyNum_") or child.name.begins_with("JerseyName_") or child.name.begins_with("JerseyNumber") or child.name == "JerseyLogo":
				child.queue_free()

	# Positions below are relative to the torso center (torso sits at y=0.9 in model space).
	# Front face = +Z (z=+0.155), back face = -Z (z=-0.155).
	var num = player_node.jersey_number if "jersey_number" in player_node else 0

	if num > 0:
		var label = Label3D.new()
		label.name = "JerseyNum_Front"
		label.text = str(num)
		label.font_size = 64
		label.pixel_size = 0.004
		label.position = Vector3(0, -0.18, 0.155)
		label.modulate = Color.WHITE
		label.outline_modulate = Color.BLACK
		label.outline_size = 12
		label.no_depth_test = false
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label_parent.add_child(label)

		var num_label_back = Label3D.new()
		num_label_back.name = "JerseyNum_Back"
		num_label_back.text = str(num)
		num_label_back.font_size = 80
		num_label_back.pixel_size = 0.004
		num_label_back.position = Vector3(0, -0.05, -0.155)
		num_label_back.rotation.y = PI
		num_label_back.modulate = Color.WHITE
		num_label_back.outline_modulate = Color.BLACK
		num_label_back.outline_size = 12
		num_label_back.no_depth_test = false
		num_label_back.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label_parent.add_child(num_label_back)

	var p_name = player_node.player_name if "player_name" in player_node else "PLAYER"
	var name_parts = p_name.split(" ")
	var last_name = name_parts[name_parts.size() - 1].to_upper() if name_parts.size() > 0 else "PLAYER"

	var name_label = Label3D.new()
	name_label.name = "JerseyName_Back"
	name_label.text = last_name
	name_label.font_size = 32
	name_label.pixel_size = 0.004
	name_label.position = Vector3(0, 0.15, -0.155)
	name_label.rotation.y = PI
	name_label.modulate = Color.WHITE
	name_label.outline_modulate = Color.BLACK
	name_label.outline_size = 12
	name_label.no_depth_test = false
	name_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label_parent.add_child(name_label)

	# Team Name Front
	var team_idx = player_node.team_index if "team_index" in player_node else 0
	var team_name_str = "TEAM"
	if team_idx >= 0 and team_idx < team_data_store.size() and team_data_store[team_idx]:
		team_name_str = team_data_store[team_idx].name
	else:
		team_name_str = "BLUE" if team_idx == 0 else "RED"

	var team_label = Label3D.new()
	team_label.name = "JerseyName_Front"
	team_label.text = team_name_str.to_upper()
	team_label.font_size = 32
	team_label.pixel_size = 0.004
	team_label.position = Vector3(0, 0.05, 0.155)
	team_label.modulate = Color.WHITE
	team_label.outline_modulate = Color.BLACK
	team_label.outline_size = 12
	team_label.no_depth_test = false
	team_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label_parent.add_child(team_label)

	if "team_logo" in player_node and player_node.team_logo != null:
		var decal = Decal.new()
		decal.name = "JerseyLogo"
		decal.texture_albedo = player_node.team_logo
		decal.size = Vector3(0.5, 0.4, 0.5)
		decal.position = Vector3(0, -0.05, 0.2)
		decal.rotation.x = PI / 2.0
		label_parent.add_child(decal)

func _process(delta: float) -> void:
	_apply_screen_shake(delta)
	match match_state:
		MatchState.PLAYING:
			time_remaining -= delta
			clock_changed.emit(time_remaining)
			if time_remaining <= 0:
				_end_quarter()

func record_stat(team_idx: int, roster_idx: int, stat_type: String, amount: int = 1) -> void:
	if team_idx < 0 or team_idx >= player_stats.size(): return
	var team_stats = player_stats[team_idx]
	if roster_idx < 0 or roster_idx >= team_stats.size(): return
	if stat_type in team_stats[roster_idx]:
		team_stats[roster_idx][stat_type] += amount

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("action_pause"):
		# Toggle pause menu
		if get_tree().paused:
			# If there's already a pause menu, it handles its own input / resume
			pass
		else:
			get_tree().paused = true
			var PauseMenuScene = load("res://ui/pause_menu.tscn")
			if PauseMenuScene:
				var pause_menu = PauseMenuScene.instantiate()
				add_child(pause_menu)

# =========================================================
#  MATCH START & TIP-OFF (Q1 only)
# =========================================================

func start_match() -> void:
	current_quarter = 1
	scores = [0, 0]
	sides_flipped = false
	time_remaining = quarter_duration
	match_state = MatchState.TIP_OFF
	quarter_changed.emit(current_quarter)
	score_changed.emit(0, 0)
	score_changed.emit(1, 0)
	clock_changed.emit(time_remaining)
	_do_tip_off()

func _do_tip_off() -> void:
	match_state = MatchState.TIP_OFF
	
	_set_hazard_spawning(false)
	get_tree().call_group("hazards", "queue_free")
	
	_strip_ball_from_all()
	_freeze_all_players(true)
	
	# Position players in tip-off formation
	for i in range(min(teams[0].size(), tip_off_positions_team0.size())):
		var p = teams[0][i]
		p.global_position = tip_off_positions_team0[i] + Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		p.input_move = Vector2.ZERO
		# Team 0 spawns at -Z and attacks toward +Z
		p.facing_direction = Vector3(0, 0, 1)
		p.aim_direction = Vector3(0, 0, 1)
		p.rotation.y = 0.0

	for i in range(min(teams[1].size(), tip_off_positions_team1.size())):
		var p = teams[1][i]
		p.global_position = tip_off_positions_team1[i] + Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		p.input_move = Vector2.ZERO
		# Team 1 spawns at +Z and attacks toward -Z
		p.facing_direction = Vector3(0, 0, -1)
		p.aim_direction = Vector3(0, 0, -1)
		p.rotation.y = PI
	
	if ball:
		ball.force_position(Vector3(0, 1.0, 0))
	
	var hud = get_tree().get_first_node_in_group("hud")
	
	# Full intro
	if hud and hud.has_method("show_message"):
		hud.show_message("QUARTER 1", 1.5)
	await get_tree().create_timer(2.0).timeout
	
	if hud and hud.has_method("show_message"):
		hud.show_message("READY...", 1.0)
	await get_tree().create_timer(1.5).timeout
	
	if hud and hud.has_method("show_message"):
		hud.show_message("TIP OFF!", 1.5)
	
	# Toss ball
	if ball:
		ball.linear_velocity = Vector3(0, 10, 0)
		ball.angular_velocity = Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	
	# Unfreeze jumpers first
	await get_tree().create_timer(0.6).timeout
	if teams[0].size() > 0:
		teams[0][0].frozen = false
	if teams[1].size() > 0:
		teams[1][0].frozen = false
	
	# Then everyone else
	await get_tree().create_timer(0.6).timeout
	_freeze_all_players(false)
	
	# Track who wins tip-off (whoever gets the ball first)
	# Default: team 0 wins tip-off, so possession arrow starts with team 1
	tip_off_winner = 0
	possession_arrow = 1  # Other team gets next possession
	
	match_state = MatchState.PLAYING
	_set_hazard_spawning(true)

# =========================================================
#  INBOUND PASS (used after scores and quarter changes Q2+)
# =========================================================

func _do_inbound_pass(inbound_team: int, endline_z: float) -> void:
	## One player stands outside the endline holding the ball.
	## Teammates are positioned on the court.
	## After a pause, the inbounder passes to the nearest teammate.
	match_state = MatchState.INBOUND
	_set_hazard_spawning(false)
	get_tree().call_group("hazards", "queue_free")
	
	_strip_ball_from_all()
	_freeze_all_players(true)
	if ball:
		ball._oob_disabled = true
	
	# Clamp endline_z to court bounds
	endline_z = clampf(endline_z, -court_half_l, court_half_l)
	
	# Inbounder stands OUTSIDE the court (1.5m beyond the endline)
	var inbound_x = 0.0
	var inbound_z = endline_z + sign(endline_z) * 1.5
	var inbound_pos = Vector3(inbound_x, 0.1, inbound_z)
	
	# Pick the inbounder — ensure CPU inbounds and human receives if possible
	var inbounder = null
	var receivers = []
	var human_player = null
	
	for p in teams[inbound_team]:
		if p.is_human:
			human_player = p
			
	for i in range(teams[inbound_team].size()):
		var p = teams[inbound_team][i]
		if p != human_player and inbounder == null:
			inbounder = p
		else:
			receivers.append(p)
	
	if inbounder == null and teams[inbound_team].size() > 0:
		inbounder = teams[inbound_team][0]
		receivers.erase(inbounder)
	
	if inbounder == null:
		match_state = MatchState.PLAYING
		return
	
	# Position the inbounder outside the endline
	inbounder.global_position = inbound_pos
	inbounder.velocity = Vector3.ZERO
	inbounder.input_move = Vector2.ZERO
	
	# Position receivers on the court near the endline (spread out)
	var recv_positions = [
		Vector3(-3, 0.1, endline_z - sign(endline_z) * 3.0),
		Vector3(3, 0.1, endline_z - sign(endline_z) * 3.0),
		Vector3(-5, 0.1, endline_z - sign(endline_z) * 5.0),
		Vector3(5, 0.1, endline_z - sign(endline_z) * 5.0),
	]
	for i in range(min(receivers.size(), recv_positions.size())):
		receivers[i].global_position = recv_positions[i]
		receivers[i].velocity = Vector3.ZERO
		receivers[i].input_move = Vector2.ZERO
	
	# Position opposing team further back
	var other_team = 1 - inbound_team
	var def_positions = [
		Vector3(-2, 0.1, endline_z - sign(endline_z) * 6.0),
		Vector3(0, 0.1, endline_z - sign(endline_z) * 8.0),
		Vector3(2, 0.1, endline_z - sign(endline_z) * 6.0),
		Vector3(-4, 0.1, endline_z - sign(endline_z) * 7.0),
		Vector3(4, 0.1, endline_z - sign(endline_z) * 7.0),
	]
	for i in range(min(teams[other_team].size(), def_positions.size())):
		teams[other_team][i].global_position = def_positions[i]
		teams[other_team][i].velocity = Vector3.ZERO
		teams[other_team][i].input_move = Vector2.ZERO
	
	# Give ball directly to inbounder (bypasses physics entirely)
	_force_give_ball_to(inbounder)
	
	# Keep the inbounder facing the court
	inbounder.rotation.y = PI if endline_z > 0 else 0
	
	# HUD
	var hud = get_tree().get_first_node_in_group("hud")
	var team_name = "BLUE"
	var team_color = Color.BLUE
	if team_data_store[inbound_team]:
		team_name = team_data_store[inbound_team].name
		team_color = team_data_store[inbound_team].color_primary
	elif inbound_team == 1:
		team_name = "RED"
		team_color = Color.RED
		
	if hud and hud.has_method("show_message"):
		hud.show_message("%s BALL" % team_name.to_upper(), 1.5, team_color)
	
	# Pause with everyone frozen, then execute the pass
	await get_tree().create_timer(2.0).timeout
	
	# Find nearest receiver to pass to
	var best_recv = null
	if human_player != null and human_player in receivers:
		best_recv = human_player
	else:
		var best_dist = 99999.0
		for r in receivers:
			var d = r.global_position.distance_to(inbounder.global_position)
			if d < best_dist:
				best_dist = d
				best_recv = r
	
	# Unfreeze everyone
	_freeze_all_players(false)
	
	# Freeze the inbounder briefly again so they don't walk into the pass or out of bounds
	if "frozen" in inbounder:
		inbounder.frozen = true
	
	if ball:
		ball.freeze = false  # Re-enable physics for the pass
	
	if best_recv and inbounder.has_ball:
		inbounder.pass_to_player(best_recv)
	
	await get_tree().create_timer(0.5).timeout
	if "frozen" in inbounder:
		inbounder.frozen = false
	
	if ball:
		ball._oob_disabled = false
		ball._oob_cooldown = 2.0  # Grace period after re-enabling
	match_state = MatchState.PLAYING
	_set_hazard_spawning(true)

# =========================================================
#  SCORING
# =========================================================

func award_score(scoring_team: int, points: int, stop_game: bool = true) -> void:
	if match_state != MatchState.PLAYING:
		return
	scores[scoring_team] += points
	score_changed.emit(scoring_team, scores[scoring_team])
	
	# Update stats if we have a shooter
	if ball and ball.last_shooter != null and is_instance_valid(ball.last_shooter):
		var shooter = ball.last_shooter
		if "team_index" in shooter and "roster_index" in shooter:
			record_stat(shooter.team_index, shooter.roster_index, "points", points)
			# Count the make as both a field goal made AND an attempt
			record_stat(shooter.team_index, shooter.roster_index, "fgm", 1)
			record_stat(shooter.team_index, shooter.roster_index, "fga", 1)
			
			if points == 3:
				record_stat(shooter.team_index, shooter.roster_index, "3pt", 1)
				record_stat(shooter.team_index, shooter.roster_index, "tpm", 1)
				record_stat(shooter.team_index, shooter.roster_index, "tpa", 1)
			elif points == 2:
				record_stat(shooter.team_index, shooter.roster_index, "2pt", 1)
			
			# Check for assist
			if ball.previous_holder != null and is_instance_valid(ball.previous_holder) and ball.previous_holder != shooter:
				var passer = ball.previous_holder
				if "team_index" in passer and "roster_index" in passer and passer.team_index == shooter.team_index:
					record_stat(passer.team_index, passer.roster_index, "assists", 1)
		
	
	if not stop_game:
		free_points[scoring_team] += points
		return
	
	if is_debug:
		return # Do not stop the game or freeze players in debug mode
	
	match_state = MatchState.SCORED
	
	_strip_ball_from_all()
	_freeze_all_players(true)
	
	# Celebrate!
	for p in teams[scoring_team]:
		if "current_state" in p:
			p.current_state = p.State.CELEBRATING
			p.celebrate_timer = 2.5
			p.velocity = Vector3.ZERO
			p.input_move = Vector2.ZERO
	
	# HUD message
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		var team_name = "BLUE"
		var team_color = Color.BLUE
		if team_data_store[scoring_team]:
			team_name = team_data_store[scoring_team].name
			team_color = team_data_store[scoring_team].color_primary
		elif scoring_team == 1:
			team_name = "RED"
			team_color = Color.RED

		var msg = "%s SCORES!" % team_name.to_upper()
		if points == 3:
			msg = "THREE POINTER! %s" % team_name.to_upper()
		hud.show_message(msg, 2.0, team_color)
	
	await get_tree().create_timer(3.0).timeout
	
	# Scored-on team inbounds from behind the basket that was scored on
	var receiving_team = 1 - scoring_team
	var scored_on_hoop = get_target_hoop(scoring_team)
	# The endline is at the hoop's z position
	_do_inbound_pass(receiving_team, scored_on_hoop.z)

# =========================================================
#  COIN COMBO RESET
# =========================================================


# =========================================================
#  OUT-OF-BOUNDS / THROW-INS
# =========================================================

func _on_ball_out_of_bounds(last_touch_team: int, oob_position: Vector3) -> void:
	if match_state != MatchState.PLAYING:
		return
	# The Cage and similar courts disable out-of-bounds entirely
	if no_out_of_bounds:
		return
	# Added this log to make sure nothing slipped through
	print("[GameManager] OOB Triggered. Current state: ", match_state)
	
	match_state = MatchState.THROW_IN
	_strip_ball_from_all()
	_lock_camera(true)   # hold the frame — players + ball keep moving during dead-ball

	var receiving_team = 1 - last_touch_team if last_touch_team >= 0 else 0
	
	var team_name = "BLUE"
	var team_color = Color.BLUE
	if team_data_store[receiving_team]:
		team_name = team_data_store[receiving_team].name
		team_color = team_data_store[receiving_team].color_primary
	elif receiving_team == 1:
		team_name = "RED"
		team_color = Color.RED
	print("[OOB] Team %d last touched. %s ball." % [last_touch_team, team_name])
	
	# Figure out the inbound spot — just inside the court near where it went out
	var inbound_spot = _get_inbound_spot(oob_position)
	
	# HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message("OUT OF BOUNDS — %s BALL" % team_name.to_upper(), 1.5, team_color)
	
	await get_tree().create_timer(1.0).timeout
	
	# Run the inbound pass from that spot
	_do_sideline_inbound(receiving_team, inbound_spot, oob_position)

func _get_inbound_spot(oob_pos: Vector3) -> Vector3:
	## Find a position just inside the court boundary near where the ball went out.
	var pos = oob_pos
	pos.y = 0.1
	# Pull inside the court boundary
	pos.x = clampf(pos.x, -court_half_w + 0.5, court_half_w - 0.5)
	pos.z = clampf(pos.z, -court_half_l + 0.5, court_half_l - 0.5)
	return pos

func _do_sideline_inbound(inbound_team: int, court_spot: Vector3, oob_pos: Vector3) -> void:
	## Inbound pass from near an out-of-bounds location.
	## The inbounder stands just outside the boundary, teammates spread nearby.
	_lock_camera(false)      # resume following now that setup is starting
	_freeze_all_players(true)  # hold everyone in place while we position them
	if ball:
		ball._oob_disabled = true
	
	# Determine inbounder position — push them just outside the nearest boundary
	var inbounder_pos = court_spot
	inbounder_pos.y = 0.1
	if abs(oob_pos.x) > abs(oob_pos.z) / (court_half_l / court_half_w):
		# Went out on a sideline (X boundary)
		inbounder_pos.x = sign(oob_pos.x) * (court_half_w + 1.0)
	else:
		# Went out on an endline (Z boundary)
		inbounder_pos.z = sign(oob_pos.z) * (court_half_l + 1.0)
	
	# Pick inbounder (CPU player if possible, so human can receive)
	var inbounder = null
	var receivers = []
	var human_player = null
	
	for p in teams[inbound_team]:
		if p.is_human:
			human_player = p
			
	for i in range(teams[inbound_team].size()):
		var p = teams[inbound_team][i]
		if p != human_player and inbounder == null:
			inbounder = p
		else:
			receivers.append(p)
			
	if inbounder == null and teams[inbound_team].size() > 0:
		inbounder = teams[inbound_team][0]
		receivers.erase(inbounder)
	
	if inbounder == null:
		_freeze_all_players(false)
		match_state = MatchState.PLAYING
		return
	
	# Position everyone
	inbounder.global_position = inbounder_pos
	inbounder.velocity = Vector3.ZERO
	inbounder.input_move = Vector2.ZERO
	
	# Receivers spread near the inbound spot on-court
	var perp = Vector3(1, 0, 0) if abs(oob_pos.z) > abs(oob_pos.x) else Vector3(0, 0, 1)
	var recv_positions = [
		court_spot + perp * 2.5 - Vector3(0, 0, sign(oob_pos.z)) * 2.0,
		court_spot - perp * 2.5 - Vector3(0, 0, sign(oob_pos.z)) * 2.0,
	]
	for i in range(min(receivers.size(), recv_positions.size())):
		var rp = recv_positions[i]
		rp.x = clampf(rp.x, -court_half_w + 1.0, court_half_w - 1.0)
		rp.z = clampf(rp.z, -court_half_l + 1.0, court_half_l - 1.0)
		rp.y = 0.1
		receivers[i].global_position = rp
		receivers[i].velocity = Vector3.ZERO
		receivers[i].input_move = Vector2.ZERO
	
	# Opposing team further from the inbound spot
	var other_team = 1 - inbound_team
	for i in range(teams[other_team].size()):
		var away_dir = (Vector3.ZERO - court_spot).normalized()
		var def_pos = court_spot + away_dir * (4.0 + i * 2.0)
		def_pos.x = clampf(def_pos.x, -court_half_w + 1.0, court_half_w - 1.0)
		def_pos.z = clampf(def_pos.z, -court_half_l + 1.0, court_half_l - 1.0)
		def_pos.y = 0.1
		teams[other_team][i].global_position = def_pos
		teams[other_team][i].velocity = Vector3.ZERO
		teams[other_team][i].input_move = Vector2.ZERO
	
	# Give ball directly to inbounder (bypasses physics entirely)
	_force_give_ball_to(inbounder)
	
	# Freeze everyone for a moment
	await get_tree().create_timer(1.5).timeout
	
	# Find best receiver and pass
	var best_recv = null
	if human_player != null and human_player in receivers:
		best_recv = human_player
	else:
		var best_dist = 99999.0
		for r in receivers:
			var d = r.global_position.distance_to(inbounder.global_position)
			if d < best_dist:
				best_dist = d
				best_recv = r
	
	# Unfreeze and pass
	_freeze_all_players(false)
	if ball:
		ball.freeze = false  # Re-enable physics for the pass
	
	if best_recv and inbounder.has_ball:
		inbounder.pass_to_player(best_recv)
	
	# Move inbounder back onto court
	await get_tree().create_timer(0.3).timeout
	inbounder.global_position = court_spot
	
	if ball:
		ball._oob_disabled = false
	match_state = MatchState.PLAYING
	_set_hazard_spawning(true)

# =========================================================
#  SHARED HELPERS
# =========================================================

func _lock_camera(locked_val: bool) -> void:
	var rig = get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.locked = locked_val

func _freeze_all_players(frozen_val: bool) -> void:
	for team in teams:
		for p in team:
			if "frozen" in p:
				p.frozen = frozen_val
			if frozen_val:
				p.velocity = Vector3.ZERO
				p.input_move = Vector2.ZERO
				# Ensure visual and animation state is cleared during transitions
				if p.has_method("force_reset_state"):
					p.force_reset_state()
			else:
				# When unfreezing, make sure no one is stuck
				if "current_state" in p and p.current_state in [p.State.CELEBRATING, p.State.SHOOTING, p.State.PASSING]:
					p.current_state = p.State.IDLE

func _force_give_ball_to(player_node: CharacterBody3D) -> void:
	## Directly assign ball to a player — no physics, no pickup checks.
	## Used for inbound passes where the ball must be in the player's hands instantly.
	if ball == null or player_node == null:
		return
	
	_strip_ball_from_all()
	
	# Freeze the ball so it doesn't fall
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	
	# Directly set possession
	player_node.has_ball = true
	player_node.held_ball = ball
	ball.holder = player_node
	if "team_index" in player_node:
		ball.last_touch_team = player_node.team_index
	ball._was_shot = false
	
	# Position ball at player's hand
	var hand_pos = player_node.global_position + Vector3(0, 0.8, 0)
	ball.global_position = hand_pos

func _give_ball_to_team(team_index: int, ball_pos: Vector3) -> void:
	if ball == null:
		return
	
	ball.force_position(ball_pos)
	
	var best_player = null
	var best_dist = 99999.0
	for p in teams[team_index]:
		if "current_state" in p and p.current_state == p.State.KNOCKED_DOWN:
			continue
		var d = p.global_position.distance_to(ball_pos)
		if d < best_dist:
			best_dist = d
			best_player = p
	
	if best_player and best_player.has_method("pickup_ball"):
		var offset = (best_player.global_position - ball_pos)
		offset.y = 0
		if offset.length() > 1.5:
			offset = offset.normalized() * 1.0
		best_player.global_position = ball_pos + offset + Vector3(0, 0.1, 0)
		best_player.velocity = Vector3.ZERO
		await get_tree().create_timer(0.2).timeout
		if ball and not ball.is_held():
			best_player.pickup_ball(ball)
	
	match_state = MatchState.PLAYING
	ball_possession_changed.emit(best_player)

func _strip_ball_from_all() -> void:
	for team in teams:
		for p in team:
			if "has_ball" in p and p.has_ball:
				if p.has_method("_release_ball"):
					p._release_ball()
				else:
					p.has_ball = false
					p.held_ball = null
	if ball:
		if ball.has_method("force_release"):
			ball.force_release()
		else:
			ball.holder = null

func is_three_pointer(shoot_position: Vector3, target_hoop_index: int) -> bool:
	var hoop_pos = hoop_positions[target_hoop_index]
	# Use XZ-plane distance only — hoop height (y=3.0) should not inflate the distance
	var shoot_xz = Vector2(shoot_position.x, shoot_position.z)
	var hoop_xz = Vector2(hoop_pos.x, hoop_pos.z)
	var dist = shoot_xz.distance_to(hoop_xz)
	return dist >= three_point_distance

func get_target_hoop(team_index: int) -> Vector3:
	if sides_flipped:
		return hoop_positions[team_index]
	return hoop_positions[1 - team_index]

# =========================================================
#  QUARTER TRANSITIONS
# =========================================================

func _end_quarter() -> void:
	match_state = MatchState.QUARTER_BREAK
	_set_hazard_spawning(false)
	_clear_hazards()
	_strip_ball_from_all()
	_freeze_all_players(true)
	
	if current_quarter >= total_quarters:
		_end_game()
		return
	
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message("END OF QUARTER %d" % current_quarter, 2.0)
	
	current_quarter += 1
	quarter_changed.emit(current_quarter)
	
	# Switch sides at halftime (after Q2)
	if current_quarter == 3:
		sides_flipped = not sides_flipped
	
	await get_tree().create_timer(quarter_break_duration).timeout
	time_remaining = quarter_duration
	
	# Q2+ use inbound pass with alternating possession
	var inbound_team = possession_arrow
	# Flip the arrow for next time
	possession_arrow = 1 - possession_arrow
	
	if hud and hud.has_method("show_message"):
		var team_name = "BLUE"
		var team_color = Color.BLUE
		if team_data_store[inbound_team]:
			team_name = team_data_store[inbound_team].name
			team_color = team_data_store[inbound_team].color_primary
		elif inbound_team == 1:
			team_name = "RED"
			team_color = Color.RED
			
		hud.show_message("QUARTER %d — %s BALL" % [current_quarter, team_name.to_upper()], 2.0, team_color)
	
	await get_tree().create_timer(2.0).timeout
	
	# Inbound from the team's defensive endline
	var defensive_hoop = get_target_hoop(1 - inbound_team)
	_do_inbound_pass(inbound_team, defensive_hoop.z)

func _end_game() -> void:
	match_state = MatchState.GAME_OVER
	_set_hazard_spawning(false)
	_clear_hazards()
	var winner = 0 if scores[0] > scores[1] else (1 if scores[1] > scores[0] else -1)
	
	if is_season_game and LeagueManager.player_team:
		var p_score = 0
		var o_score = 0
		var opponent = null
		if team_data_store[0] == LeagueManager.player_team:
			p_score = scores[0]
			o_score = scores[1]
			opponent = team_data_store[1]
		elif team_data_store[1] == LeagueManager.player_team:
			p_score = scores[1]
			o_score = scores[0]
			opponent = team_data_store[0]
			
		LeagueManager.record_season_match_result(p_score, o_score, opponent)
		
	game_over.emit(winner)

func get_score(team_index: int) -> int:
	return scores[team_index]

func get_formatted_time() -> String:
	var mins = int(time_remaining) / 60
	var secs = int(time_remaining) % 60
	return "%d:%02d" % [mins, secs]



# =========================================================
#  HAZARD SPAWNER
# =========================================================

var hazard_spawner: Node = null
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0

func _create_hazard_spawner() -> void:
	hazard_spawner = Node.new()
	hazard_spawner.set_script(load("res://scripts/hazard_spawner.gd"))
	hazard_spawner.name = "HazardSpawner"
	add_child(hazard_spawner)

func _set_hazard_spawning(enabled: bool) -> void:
	if hazard_spawner and "spawn_enabled" in hazard_spawner:
		hazard_spawner.spawn_enabled = enabled

func _clear_hazards() -> void:
	if hazard_spawner and hazard_spawner.has_method("clear_all_hazards"):
		hazard_spawner.clear_all_hazards()

func _on_screen_shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_timer = duration

func _apply_screen_shake(delta: float) -> void:
	if _shake_timer <= 0:
		return
	_shake_timer -= delta
	var camera = get_viewport().get_camera_3d()
	if camera:
		var offset = Vector3(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity),
			0
		)
		camera.h_offset = offset.x
		camera.v_offset = offset.y
		_shake_intensity *= 0.9  # Decay
	if _shake_timer <= 0:
		# Reset camera offsets
		var cam = get_viewport().get_camera_3d()
		if cam:
			cam.h_offset = 0
			cam.v_offset = 0
