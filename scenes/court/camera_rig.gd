extends Node3D
## Camera rig — isometric camera that follows the ball with smooth tracking.

@export var follow_speed: float = 5.0
@export var camera_height: float = 20.0
@export var camera_angle: float = -55.0  # Degrees of tilt
@export var camera_distance: float = 15.0
@export var look_ahead: float = 2.0  # How far ahead of the ball to look

var target: Node3D = null
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	_setup_camera()
	# Find ball to follow
	await get_tree().process_frame
	var balls = get_tree().get_nodes_in_group("ball")
	if balls.size() > 0:
		target = balls[0]

func _setup_camera() -> void:
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	
	camera.position = Vector3(0, camera_height, camera_distance)
	camera.rotation_degrees = Vector3(camera_angle, 0, 0)
	camera.fov = 45.0
	camera.current = true

func _process(delta: float) -> void:
	if target == null:
		return
	
	var target_pos = target.global_position
	# Add look-ahead based on ball velocity
	if target is RigidBody3D:
		var vel = target.linear_velocity
		target_pos += vel.normalized() * look_ahead * min(vel.length() / 10.0, 1.0)
	
	# Smooth follow on XZ plane only
	var desired_pos = Vector3(target_pos.x, 0, target_pos.z)
	var current_xz = Vector3(global_position.x, 0, global_position.z)
	var new_xz = current_xz.lerp(desired_pos, follow_speed * delta)
	global_position = Vector3(new_xz.x, global_position.y, new_xz.z)
