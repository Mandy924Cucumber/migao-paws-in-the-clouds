extends CharacterBody3D

signal landed(platform_index: int)
signal jumped(assisted: bool)

const CatVisual = preload("res://scripts/cat_visual.gd")
const GRAVITY: float = 22.0
const JUMP_SPEED: float = 10.1
const MOVE_SPEED: float = 5.7
var active: bool = false
var camera_yaw: float = 0.0
var next_target := Vector3.ZERO
var current_platform: int = 0
var checkpoint_surface: bool = true
var cat: Node3D
var assist_active: bool = false
var landing_delay: float = 0.0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var previous_grounded: bool = false
var in_air: bool = false

func _ready() -> void:
	name = "CatPlayer"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.18
	safe_margin = 0.012
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.12
	collision.shape = capsule
	collision.position.y = 0.56
	add_child(collision)
	cat = CatVisual.new()
	add_child(cat)

func set_appearance(cat_id: String, outfit: String) -> void:
	cat.set_appearance(cat_id, outfit)

func teleport_to(point: Vector3, look_direction: Vector3) -> void:
	global_position = point + Vector3.UP * 0.025
	velocity = Vector3.ZERO
	assist_active = false
	in_air = false
	previous_grounded = false
	landing_delay = 0.35
	jump_buffer = 0.0
	coyote = 0.0
	cat.rotation.y = atan2(-look_direction.x, -look_direction.z)
	reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	if not active:
		cat.animate_motion(delta, 0.0, 0.0, true)
		return
	landing_delay = maxf(0.0, landing_delay - delta)
	jump_buffer = maxf(0.0, jump_buffer - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.16
	var movement: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = Vector3(movement.x, 0.0, movement.y).rotated(Vector3.UP, camera_yaw)
	var grounded: bool = is_on_floor()
	if grounded:
		coyote = 0.12
	else:
		coyote = maxf(0.0, coyote - delta)
	if direction.length_squared() > 0.01:
		assist_active = false
		velocity.x = move_toward(velocity.x, direction.x * MOVE_SPEED, delta * 26.0)
		velocity.z = move_toward(velocity.z, direction.z * MOVE_SPEED, delta * 26.0)
	elif not assist_active:
		velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
	if grounded and landing_delay <= 0.0:
		if jump_buffer > 0.0 or Input.is_action_pressed("jump"):
			launch(movement.length_squared() < 0.01)
		elif not checkpoint_surface:
			launch(false)
	elif coyote > 0.0 and jump_buffer > 0.0 and not in_air:
		launch(movement.length_squared() < 0.01)
	if not is_on_floor() or velocity.y > 0.0:
		velocity.y -= GRAVITY * delta
	var falling: bool = velocity.y <= 0.0
	move_and_slide()
	grounded = is_on_floor()
	if grounded and falling and (not previous_grounded or in_air):
		for i in range(get_slide_collision_count()):
			var hit := get_slide_collision(i)
			var collider: Object = hit.get_collider()
			if hit.get_normal().y > 0.65 and collider != null and collider.has_meta("platform_index"):
				current_platform = int(collider.get_meta("platform_index"))
				checkpoint_surface = bool(collider.get_meta("checkpoint", false))
				landing_delay = 0.19 if not checkpoint_surface else 0.32
				assist_active = false
				in_air = false
				cat.play_bounce()
				landed.emit(current_platform)
				break
	previous_grounded = grounded
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length_squared() > 0.1:
		var target_yaw: float = atan2(-horizontal.x, -horizontal.z)
		cat.rotation.y = lerp_angle(cat.rotation.y, target_yaw, 1.0 - exp(-delta * 12.0))
	cat.animate_motion(delta, horizontal.length(), velocity.y, grounded)

func launch(assisted: bool) -> void:
	velocity.y = JUMP_SPEED
	jump_buffer = 0.0
	coyote = 0.0
	in_air = true
	assist_active = assisted
	if assisted:
		var height_difference: float = next_target.y - global_position.y
		var discriminant: float = JUMP_SPEED * JUMP_SPEED - 2.0 * GRAVITY * height_difference
		var flight_time: float = (JUMP_SPEED + sqrt(maxf(0.1, discriminant))) / GRAVITY
		var displacement: Vector3 = next_target - global_position
		velocity.x = displacement.x / flight_time
		velocity.z = displacement.z / flight_time
	jumped.emit(assisted)
