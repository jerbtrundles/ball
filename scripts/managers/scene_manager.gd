extends Node

const LOADING_SCREEN_SCENE = preload("res://ui/loading_screen.tscn")

# How fast the display bar lerps toward its target
const LERP_SPEED        := 7.0
# The init phase keeps the loading screen alive after change_scene_to_packed().
# It auto-advances the bar 92→99 % over this many seconds, then stays at 99 %.
const INIT_PHASE_DURATION := 3.0
# Hard-kill the loading screen after this long no matter what (safety net).
const INIT_PHASE_TIMEOUT  := 12.0

var _loading_screen = null
var _target_scene_path := ""

# ── Dependency tracking ───────────────────────────────────────────────────────
var _all_deps_map: Dictionary = {}   # path → file_size (used only for scan)
var _deps_in_flight: Array    = []   # paths still being loaded in parallel
var _deps_total_count: int    = 0
var _deps_done_count:  int    = 0

# ── Main scene loading ────────────────────────────────────────────────────────
var _loading_main_scene   := false
var _main_scene_progress: Array = []
var _main_virtual_elapsed := 0.0

# ── Post-load initialisation phase ───────────────────────────────────────────
var _waiting_for_scene_ready := false
var _init_elapsed            := 0.0
var _manual_target           := -1.0   # set by report_progress()

# ── Display ───────────────────────────────────────────────────────────────────
var _display := 0.0

# ─────────────────────────────────────────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

func change_scene(target_path: String) -> void:
	_target_scene_path       = target_path
	_loading_main_scene      = false
	_waiting_for_scene_ready = false
	_init_elapsed            = 0.0
	_main_virtual_elapsed    = 0.0
	_manual_target           = -1.0
	_display                 = 0.0
	_all_deps_map.clear()
	_deps_in_flight.clear()
	_deps_total_count = 0
	_deps_done_count  = 0

	if not _loading_screen:
		_loading_screen = LOADING_SCREEN_SCENE.instantiate()
		get_tree().root.add_child(_loading_screen)

	_loading_screen.update_progress(0.0, "Scanning…")

	# 1. Deep-scan all dependencies recursively
	_get_all_dependencies_recursive(target_path, _all_deps_map)

	# 2. Request all non-cached deps in parallel
	for path in _all_deps_map:
		if path == _target_scene_path: continue
		if ResourceLoader.has_cached(path): continue
		if ResourceLoader.load_threaded_request(path) == OK:
			_deps_in_flight.append(path)

	_deps_total_count = _deps_in_flight.size()
	print("[SceneManager] Parallel loading %d assets." % _deps_total_count)

	if _deps_in_flight.is_empty():
		_loading_screen.update_progress(0.05, "Loading scene…")
		_start_loading_main_scene()
	else:
		_loading_screen.update_progress(0.05, "Loading %d assets…" % _deps_total_count)

	set_process(true)


## Push a named progress update during scene initialisation.
## value should be in 0.92–0.99. Only moves the bar forward.
func report_progress(value: float, status: String = "") -> void:
	if not _loading_screen or not _waiting_for_scene_ready: return
	_manual_target = clamp(value, _display, 0.99)
	if status != "":
		_loading_screen.set_status(status)


## Call once the scene is fully initialised and ready to show.
func notify_scene_ready() -> void:
	if not _loading_screen: return
	_waiting_for_scene_ready = false
	set_process(false)
	_display = 1.0
	_loading_screen.update_progress(1.0, "Ready!")
	# Hold at 100% for one brief moment so the player sees it
	var t = get_tree().create_timer(0.2)
	t.timeout.connect(_dismiss_loading_screen)

# ─────────────────────────────────────────────────────────────────────────────
#  INTERNAL PROCESS LOOP
# ─────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# ── Post-load initialisation phase ───────────────────────────────
	if _waiting_for_scene_ready:
		_init_elapsed += delta

		# Auto-advance: 92 % → 99 % over INIT_PHASE_DURATION, then hold at 99 %
		var auto_frac   = min(_init_elapsed / INIT_PHASE_DURATION, 1.0)
		var auto_target = lerp(0.92, 0.99, pow(auto_frac, 0.55))

		# Let report_progress() push it further but never backward
		var effective = max(auto_target, _manual_target if _manual_target >= 0 else 0.0)
		_smooth_to(effective, delta)

		if _init_elapsed >= INIT_PHASE_TIMEOUT:
			notify_scene_ready()
		return

	# ── Dependency loading (parallel) ────────────────────────────────
	if not _loading_main_scene:
		var newly_done: Array = []
		for path in _deps_in_flight:
			var prog: Array = []
			var st = ResourceLoader.load_threaded_get_status(path, prog)
			match st:
				ResourceLoader.THREAD_LOAD_LOADED, \
				ResourceLoader.THREAD_LOAD_FAILED, \
				ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
					newly_done.append(path)
					_deps_done_count += 1

		for p in newly_done:
			_deps_in_flight.erase(p)

		# Progress: 5 % base + up to 80 % for deps (many small increments)
		if _deps_total_count > 0:
			var dep_frac = float(_deps_done_count) / float(_deps_total_count)
			var msg = "Loading assets… (%d / %d)" % [_deps_done_count, _deps_total_count]
			_smooth_to(0.05 + dep_frac * 0.80, delta, msg)

		if _deps_in_flight.is_empty():
			_smooth_to(0.85, delta, "Building scene…")
			_start_loading_main_scene()
		return

	# ── Main scene loading (85 %–92 %) ───────────────────────────────
	var st = ResourceLoader.load_threaded_get_status(_target_scene_path, _main_scene_progress)
	match st:
		ResourceLoader.THREAD_LOAD_LOADED:
			_smooth_to(0.92, delta)
			var new_scene = ResourceLoader.load_threaded_get(_target_scene_path)
			get_tree().change_scene_to_packed(new_scene)
			_loading_main_scene      = false
			_waiting_for_scene_ready = true
			_init_elapsed            = 0.0
			return

		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_main_virtual_elapsed += delta
			var raw_p     = _main_scene_progress[0] if _main_scene_progress.size() > 0 else 0.0
			# Virtual slow creep so bar never freezes (0.8 %/s toward 91 %)
			var virtual_p = min(_main_virtual_elapsed * 0.008, 0.06)
			_smooth_to(0.85 + max(raw_p * 0.07, virtual_p), delta, "Building scene…")

		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_dismiss_loading_screen()


func _smooth_to(target: float, delta: float, status: String = "") -> void:
	if target > _display:
		_display += (target - _display) * delta * LERP_SPEED
		if _display > target: _display = target
	if _loading_screen:
		_loading_screen.update_progress(_display, status)


func _dismiss_loading_screen() -> void:
	if _loading_screen:
		_loading_screen.queue_free()
		_loading_screen = null
	_waiting_for_scene_ready = false
	set_process(false)

# ─────────────────────────────────────────────────────────────────────────────
#  DEPENDENCY SCAN
# ─────────────────────────────────────────────────────────────────────────────

func _get_all_dependencies_recursive(path: String, found_deps: Dictionary) -> void:
	var clean_path = path
	if "::::" in path: clean_path = path.split("::::")[1]
	if not clean_path.begins_with("res://"): return
	if found_deps.has(clean_path): return

	var size = 1024
	if FileAccess.file_exists(clean_path):
		var f = FileAccess.open(clean_path, FileAccess.READ)
		if f:
			size = f.get_length()
			if clean_path.ends_with(".tscn") or clean_path.ends_with(".tres"):
				var content = f.get_as_text()
				var regex = RegEx.new()
				regex.compile("res://[a-zA-Z0-9_/\\.]+")
				for result in regex.search_all(content):
					var sub_path = result.get_string()
					if sub_path != clean_path:
						_get_all_dependencies_recursive(sub_path, found_deps)
			f.close()

	found_deps[clean_path] = size

	var deps = ResourceLoader.get_dependencies(clean_path)
	for d in deps:
		_get_all_dependencies_recursive(d, found_deps)


# ─────────────────────────────────────────────────────────────────────────────
#  STARTUP & GLOBAL INPUT
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_process(false)
	set_process_input(true)

func _start_loading_main_scene() -> void:
	_loading_main_scene = true
	ResourceLoader.load_threaded_request(_target_scene_path)

func _input(event: InputEvent) -> void:
	# Forward joypad confirm to focused buttons (joypad doesn't always reach Button._gui_input)
	var is_confirm = event.is_action_pressed("ui_accept") or \
		(event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A)
	if is_confirm:
		var focused = get_viewport().gui_get_focus_owner()
		if focused is Button and focused.is_visible_in_tree() and not focused.disabled:
			var btn := focused as Button
			if btn.toggle_mode:
				btn.button_pressed = not btn.button_pressed
				btn.emit_signal("toggled", btn.button_pressed)
			else:
				btn.emit_signal("pressed")
			get_viewport().set_input_as_handled()
