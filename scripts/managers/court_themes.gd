extends Node
## CourtThemes — singleton providing all named court theme presets.
## Registered as autoload "CourtThemes" in project settings.

# =============================================================
#  Preset IDs
# =============================================================
const ID_DEFAULT    = 0
const ID_HOME_COURT = 1
const ID_INFERNO    = 2
const ID_GLACIAL    = 3
const ID_VOID       = 4
const ID_GOLD_RUSH  = 5

const PRESET_COUNT = 7

# Human-readable names in same order as ID_* constants
const PRESET_NAMES: Array = [
	"Default Neon",
	"Home Court",
	"Inferno",
	"Glacial",
	"Void",
	"Gold Rush",
	"Cyber Grid"
]

# Emoji/icon per preset (used in UI cards)
const PRESET_ICONS: Array = [
	"⚡", "🏠", "🔥", "❄️", "🌑", "✨", "🟣"
]

# =============================================================
#  Public API
# =============================================================

## Returns a built CourtTheme for the given preset index.
## For ID_HOME_COURT pass team_data too (optional — falls back to cyan).
func get_preset(index: int, team_data: Resource = null) -> CourtTheme:
	match index:
		ID_HOME_COURT:
			return get_home_court(team_data)
		ID_INFERNO:
			return _make_inferno()
		ID_GLACIAL:
			return _make_glacial()
		ID_VOID:
			return _make_void()
		ID_GOLD_RUSH:
			return _make_gold_rush()
		6:  # Cyber Grid
			return _make_cyber_grid()
		_:  # ID_DEFAULT and fallback
			return _make_default()

## Derives a home court theme from a TeamData resource.
func get_home_court(team_data: Resource) -> CourtTheme:
	var t = CourtTheme.new()
	if team_data == null:
		return _make_default()

	var pri: Color = team_data.color_primary
	var sec: Color = team_data.color_secondary if "color_secondary" in team_data else pri.lightened(0.3)

	t.theme_name      = team_data.name + " Home Court"
	t.floor_color     = Color(pri.r * 0.08, pri.g * 0.08, pri.b * 0.10)
	t.wall_color      = Color(pri.r * 0.18, pri.g * 0.18, pri.b * 0.22, 0.7)
	t.line_color      = sec.lightened(0.1)
	t.hoop_color      = sec.lightened(0.2)
	t.ambient_color   = Color(pri.r * 0.04, pri.g * 0.04, pri.b * 0.08)
	t.main_light_color = Color(0.9, 0.92, 1.0)
	t.spotlight_color  = pri.lightened(0.15)
	t.floor_accent_color = pri.lightened(0.05)
	t.glow_enabled    = true
	t.swatch_color    = pri
	return t

# =============================================================
#  Private preset builders
# =============================================================

func _make_default() -> CourtTheme:
	var t = CourtTheme.new()
	t.theme_name         = "Default Neon"
	t.floor_color        = Color(0.08, 0.08, 0.12)
	t.wall_color         = Color(0.15, 0.15, 0.2, 0.7)
	t.line_color         = Color(0.0, 0.9, 1.0)
	t.hoop_color         = Color(1.0, 0.5, 0.0)
	t.ambient_color      = Color(0.02, 0.02, 0.06)
	t.main_light_color   = Color(0.9, 0.92, 1.0)
	t.spotlight_color    = Color(1.0, 0.7, 0.3)
	t.floor_accent_color = Color(0.0, 0.5, 0.6)
	t.glow_enabled       = true
	t.swatch_color       = Color(0.0, 0.9, 1.0)
	return t

func _make_inferno() -> CourtTheme:
	var t = CourtTheme.new()
	t.theme_name         = "Inferno"
	t.floor_color        = Color(0.10, 0.04, 0.02)
	t.wall_color         = Color(0.25, 0.08, 0.02, 0.7)
	t.line_color         = Color(1.0, 0.35, 0.0)
	t.hoop_color         = Color(1.0, 0.15, 0.0)
	t.ambient_color      = Color(0.08, 0.02, 0.01)
	t.main_light_color   = Color(1.0, 0.75, 0.5)
	t.spotlight_color    = Color(1.0, 0.4, 0.1)
	t.floor_accent_color = Color(0.6, 0.15, 0.0)
	t.glow_enabled       = true
	t.swatch_color       = Color(1.0, 0.35, 0.0)
	return t

func _make_glacial() -> CourtTheme:
	var t = CourtTheme.new()
	t.theme_name         = "Glacial"
	t.floor_color        = Color(0.08, 0.12, 0.16)
	t.wall_color         = Color(0.2, 0.28, 0.36, 0.6)
	t.line_color         = Color(0.5, 0.9, 1.0)
	t.hoop_color         = Color(0.3, 0.8, 1.0)
	t.ambient_color      = Color(0.04, 0.07, 0.12)
	t.main_light_color   = Color(0.8, 0.92, 1.0)
	t.spotlight_color    = Color(0.5, 0.85, 1.0)
	t.floor_accent_color = Color(0.2, 0.5, 0.7)
	t.glow_enabled       = true
	t.swatch_color       = Color(0.5, 0.9, 1.0)
	return t

func _make_void() -> CourtTheme:
	var t = CourtTheme.new()
	t.theme_name         = "Void"
	t.floor_color        = Color(0.04, 0.02, 0.08)
	t.wall_color         = Color(0.1, 0.05, 0.18, 0.5)
	t.line_color         = Color(0.7, 0.2, 1.0)
	t.hoop_color         = Color(0.9, 0.3, 1.0)
	t.ambient_color      = Color(0.03, 0.01, 0.06)
	t.main_light_color   = Color(0.7, 0.6, 0.9)
	t.spotlight_color    = Color(0.8, 0.35, 1.0)
	t.floor_accent_color = Color(0.3, 0.05, 0.5)
	t.glow_enabled       = true
	t.swatch_color       = Color(0.7, 0.2, 1.0)
	return t

func _make_gold_rush() -> CourtTheme:
	var t = CourtTheme.new()
	t.theme_name         = "Gold Rush"
	t.floor_color        = Color(0.10, 0.07, 0.02)
	t.wall_color         = Color(0.22, 0.16, 0.04, 0.7)
	t.line_color         = Color(1.0, 0.82, 0.1)
	t.hoop_color         = Color(1.0, 0.7, 0.05)
	t.ambient_color      = Color(0.06, 0.04, 0.01)
	t.main_light_color   = Color(1.0, 0.95, 0.8)
	t.spotlight_color    = Color(1.0, 0.85, 0.3)
	t.floor_accent_color = Color(0.5, 0.35, 0.0)
	t.glow_enabled       = true
	t.swatch_color       = Color(1.0, 0.82, 0.1)
	return t

func _make_cyber_grid() -> CourtTheme:
	var t = CourtTheme.new()
	t.theme_name         = "Cyber Grid"
	t.floor_color        = Color(0.03, 0.02, 0.08)   # Near-black violet base
	t.wall_color         = Color(0.12, 0.05, 0.22, 0.6)
	t.line_color         = Color(0.55, 0.0, 1.0)      # Vivid purple lines
	t.hoop_color         = Color(0.1, 0.9, 1.0)       # Cyan hoops for contrast
	t.ambient_color      = Color(0.02, 0.01, 0.06)
	t.main_light_color   = Color(0.75, 0.65, 1.0)
	t.spotlight_color    = Color(0.2, 0.8, 1.0)
	t.floor_accent_color = Color(0.55, 0.0, 1.0)
	t.glow_enabled       = true
	t.swatch_color       = Color(0.55, 0.0, 1.0)
	t.animated_floor     = true
	return t
