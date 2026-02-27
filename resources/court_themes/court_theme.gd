extends Resource
class_name CourtTheme

@export var theme_name: String = "Neon Grid"
@export var floor_color: Color = Color(0.08, 0.08, 0.12)
@export var wall_color: Color = Color(0.15, 0.15, 0.2)
@export var line_color: Color = Color(0.0, 0.9, 1.0)
@export var hoop_color: Color = Color(1.0, 0.5, 0.0)
@export var ambient_color: Color = Color(0.02, 0.02, 0.06)
@export var main_light_color: Color = Color(0.9, 0.92, 1.0)
# Extended fields
@export var spotlight_color: Color = Color(1.0, 0.7, 0.3)
@export var floor_accent_color: Color = Color(0.0, 0.9, 1.0)
@export var glow_enabled: bool = true
@export var swatch_color: Color = Color(0.0, 0.9, 1.0)
@export var animated_floor: bool = false  # Enables ShaderMaterial sweep animation
@export var hazard_scenes: Array[PackedScene] = []
@export var hazard_count: int = 0
