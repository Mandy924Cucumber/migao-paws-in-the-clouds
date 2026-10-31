extends Node3D
## A complete, asset-free 3D parkour scene. Distances and jump arcs share one scale.

const PlatformFactory = preload("res://scripts/platform_factory.gd")
const WorldDecor = preload("res://scripts/world_decor.gd")
const CatVisual = preload("res://scripts/cat_visual.gd")
const Player = preload("res://scripts/player.gd")
const GameUI = preload("res://scripts/game_ui.gd")
const SaveData = preload("res://scripts/save_data.gd")
const Pickup = preload("res://scripts/pickup.gd")
const Sound = preload("res://scripts/sound.gd")
const PLATFORM_COUNT: int = 43
const RISE: float = 0.84
const RADIUS: float = 7.0
const STEP_ANGLE: float = 0.46

var save = SaveData.new()
var player: CharacterBody3D
var ui: CanvasLayer
var camera: Camera3D
var sound: Node
var platforms: Array[StaticBody3D] = []
var platform_visuals: Array[Node3D] = []
var positions: Array[Vector3] = []
var pickups: Dictionary = {}
var stage: int = 0
var started: bool = false
var completed: bool = false
var respawning: bool = false
var elapsed: float = 0.0
var camera_yaw: float = 0.0
var camera_pitch: float = 0.38
var camera_distance: float = 9.2
var camera_focus := Vector3.ZERO
var camera_initialized: bool = false
var dragging: bool = false
var auto_camera: bool = true
var marker: Node3D
var shadow: MeshInstance3D
var home_scene: Node3D
var world_decor: Node3D
var home_cat: Node3D
var home_floaters: Array[Node3D] = []
var home_origins: Array[Vector3] = []
var hud_timer: float = 0.0
var test_mode: bool = false
var flight_trail_timer: float = 0.0

func _ready() -> void:
	test_mode = "--smoke-test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args() or "--benchmark" in OS.get_cmdline_user_args()
	save.persistent = not test_mode
	save.load_game()
	_setup_input()
	_setup_environment()
	_build_course()
	var decor := WorldDecor.new()
	add_child(decor)
	decor.build()
	world_decor = decor
	decor.visible = false
	_build_home()
	player = Player.new()
	add_child(player)
	player.set_appearance(save.cat_id, save.outfit_id)
	player.landed.connect(_on_landed)
	player.jumped.connect(_on_jumped)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 52.0
	camera.near = 0.12
	camera.far = 230.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	_build_markers()
	sound = Sound.new()
	add_child(sound)
	sound.muted = save.muted or test_mode
	ui = GameUI.new()
	add_child(ui)
	_connect_ui()
	ui.show_home(save.checkpoint > 0)
	if ui.has_method("set_muted"):
		ui.set_muted(save.muted)
	_place_at_checkpoint()
	_update_hud()
	get_window().min_size = Vector2i(640, 480)
	get_window().focus_exited.connect(_on_focus_lost)
	if test_mode:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(1280, 720)
		_run_smoke.call_deferred()

func _setup_input() -> void:
	var bindings := {"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE],
		"respawn": [KEY_R], "wardrobe": [KEY_C], "pause_game": [KEY_ESCAPE], "reset_camera": [KEY_F]}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)

func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("a79de1")
	sky_mat.sky_horizon_color = Color("fbe4e7")
	sky_mat.sky_curve = 0.22
	sky_mat.ground_bottom_color = Color("c9bee9")
	sky_mat.ground_horizon_color = Color("fbe4e7")
	sky_mat.ground_curve = 0.42
	sky_mat.sun_angle_max = 2.0
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e8e2ff")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("e9d8f5")
	environment.fog_light_energy = 0.8
	environment.fog_density = 0.0018
	world.environment = environment
	add_child(world)
	var sunlight := DirectionalLight3D.new()
	sunlight.name = "WarmSoftbox"
	sunlight.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sunlight.light_color = Color("fff1dc")
	sunlight.light_energy = 0.62
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 32.0
	sunlight.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sunlight.shadow_blur = 2.5
	sunlight.shadow_opacity = 0.65
	add_child(sunlight)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28.0, 145.0, 0.0)
	fill.light_color = Color("cbd5ff")
	fill.light_energy = 0.16
	add_child(fill)

func _build_course() -> void:
	var kinds := ["card", "candy", "ball", "cookie", "card", "gift"]
	for i in range(PLATFORM_COUNT):
		var angle: float = float(i) * STEP_ANGLE
		var point := Vector3(sin(angle) * RADIUS, float(i) * RISE, cos(angle) * RADIUS)
		positions.append(point)
		var checkpoint: bool = i % 7 == 0
		var kind: String = "burger" if checkpoint else str(kinds[(i - 1) % 6])
		if i == PLATFORM_COUNT - 1:
			kind = "finish"
		var body := StaticBody3D.new()
		body.name = "Platform_%02d_%s" % [i, kind]
		body.position = point
		body.rotation.y = -angle + 0.15
		body.set_meta("platform_index", i)
		body.set_meta("checkpoint", checkpoint)
		body.collision_layer = 1
		body.collision_mask = 2
		var collision := CollisionShape3D.new()
		if kind == "card" or kind == "gift":
			var shape := BoxShape3D.new()
			shape.size = Vector3(3.35, 0.36, 2.45) if kind == "card" else Vector3(2.8, 0.5, 2.8)
			collision.shape = shape
			collision.position.y = -shape.size.y * 0.5
		else:
			var shape := CylinderShape3D.new()
			shape.radius = 1.4
			if kind == "burger":
				shape.radius = 1.75
			elif kind == "ball":
				shape.radius = 1.35
			elif kind == "cookie":
				shape.radius = 1.55
			elif kind == "finish":
				shape.radius = 2.2
			shape.height = 0.44
			collision.shape = shape
			collision.position.y = -0.22
		body.add_child(collision)
		var visual := PlatformFactory.create(kind, i)
		body.add_child(visual)
		add_child(body)
		platforms.append(body)
		platform_visuals.append(visual)
		if checkpoint:
			_add_checkpoint_flag(body, i)
		if i > 0 and (i % 2 == 1 or checkpoint) and not i in save.collected:
			var pickup := Pickup.new()
			pickup.index = i
			add_child(pickup)
			pickup.position = point + Vector3.UP * 0.8
			pickups[i] = pickup
	# Dotted little arcs between successive props quietly show the spiral route.
	var dots_mesh := SphereMesh.new()
	dots_mesh.radius = 0.033
	dots_mesh.height = 0.066
	dots_mesh.radial_segments = 8
	dots_mesh.rings = 4
	var dots := MultiMesh.new()
	dots.transform_format = MultiMesh.TRANSFORM_3D
	dots.mesh = dots_mesh
	dots.instance_count = (PLATFORM_COUNT - 1) * 3
	for i in range(PLATFORM_COUNT - 1):
		for j in range(3):
			var t: float = 0.40 + float(j) * 0.10
			var point: Vector3 = positions[i].lerp(positions[i + 1], t)
			point.y -= 0.35
			dots.set_instance_transform(i * 3 + j, Transform3D(Basis.IDENTITY, point))
	var dot_node := MultiMeshInstance3D.new()
	dot_node.multimesh = dots
	dot_node.material_override = PlatformFactory.material(Color("fff7de"))
	dot_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dot_node)

func _add_checkpoint_flag(parent: Node3D, index: int) -> void:
	if index == PLATFORM_COUNT - 1:
		return
	var flag := Node3D.new()
	parent.add_child(flag)
	flag.position = Vector3(-1.35, 0, -0.85)
	PlatformFactory.capsule_between(flag, Vector3.ZERO, Vector3.UP * 1.9, 0.027, Color("fff7de"))
	PlatformFactory.sphere(flag, Vector3.UP * 1.95, Vector3.ONE * 0.13, Color("ffda75"))
	var banner := PlatformFactory.box(flag, Vector3(0.26, 1.63, 0), Vector3(0.5, 0.36, 0.045), Color("f47da1"))
	banner.rotation.z = -0.1
	var label := Label3D.new()
	label.text = "%02d" % (index / 7 + 1)
	label.font_size = 48
	label.pixel_size = 0.004
	label.position = Vector3(0.25, 1.64, 0.032)
	label.modulate = Color("fff7de")
	label.outline_size = 0
	flag.add_child(label)

func _build_markers() -> void:
	marker = Node3D.new()
	add_child(marker)
	var ring := PlatformFactory.ring(marker, Vector3(0, 0.04, 0), 0.64, 0.028, Color("fff6bf"))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("fff5bf")
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var arrow := Label3D.new()
	arrow.text = "NEXT"
	arrow.font_size = 32
	arrow.pixel_size = 0.006
	arrow.position.y = 0.14
	arrow.rotation_degrees.x = -90.0
	arrow.modulate = Color("fff8d3")
	arrow.outline_size = 0
	marker.add_child(arrow)
	shadow = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.3, 1.3)
	shadow.mesh = plane
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, blend_mix, depth_draw_never, cull_disabled; void fragment(){ float d=length(UV-vec2(0.5))*2.0; ALBEDO=vec3(0.32,0.22,0.34); ALPHA=(1.0-smoothstep(0.1,0.95,d))*0.26; }"
	var shadow_mat := ShaderMaterial.new()
	shadow_mat.shader = shader
	shadow.material_override = shadow_mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

func _build_home() -> void:
	home_scene = Node3D.new()
	home_scene.name = "TitleDiorama"
	home_scene.position = Vector3(100, 0, 0)
	add_child(home_scene)
	var base := PlatformFactory.create("burger", 0)
	base.scale = Vector3.ONE * 1.45
	home_scene.add_child(base)
	home_cat = CatVisual.new()
	home_scene.add_child(home_cat)
	home_cat.scale = Vector3.ONE * 2.7
	home_cat.rotation.y = 0.3 + PI
	home_cat.position.y = 0.04
	home_cat.set_appearance(save.cat_id, save.outfit_id)
	var props := ["card", "candy", "ball", "cookie", "gift"]
	var spots := [Vector3(-3.7, 1.5, -2.8), Vector3(3.8, 3.0, -3.4), Vector3(3.6, -0.5, 2.0), Vector3(-3.3, -1.2, 2.3), Vector3(0, 4.6, -4.8)]
	for i in range(props.size()):
		var prop := PlatformFactory.create(props[i], i + 1)
		home_scene.add_child(prop)
		prop.position = spots[i]
		prop.scale = Vector3.ONE * (0.66 if i != 0 else 0.85)
		prop.rotation = Vector3(0.08, float(i) * 0.9, 0.12 if i % 2 == 0 else -0.12)
		home_floaters.append(prop)
		home_origins.append(prop.position)
	for i in range(10):
		var angle: float = TAU * float(i) / 10.0
		var cloud_pos := Vector3(cos(angle) * 4.8, -3.8 + sin(angle * 3.0) * 0.3, sin(angle) * 3.0)
		PlatformFactory.sphere(home_scene, cloud_pos, Vector3(3.4, 1.5, 2.4), Color("fff5fa"))
	var halo := PlatformFactory.ring(home_scene, Vector3(0, 1.3, -3.8), 4.8, 0.055, Color("fff3d1"))
	halo.rotation_degrees.x = 76.0
	for i in range(13):
		var angle: float = float(i) * 2.4
		var point := Vector3(sin(angle) * 5.4, cos(angle * 1.8) * 3.4 + 1.0, -2.7)
		PlatformFactory.sphere(home_scene, point, Vector3.ONE * (0.12 + 0.06 * (i % 3)), [Color("ffcb62"), Color("fb8eba"), Color("93ddc8")][i % 3])

func _connect_ui() -> void:
	ui.start_requested.connect(_start_game)
	ui.pause_requested.connect(_pause)
	ui.resume_requested.connect(_resume)
	ui.respawn_requested.connect(_request_respawn)
	ui.wardrobe_requested.connect(_open_wardrobe)
	ui.cat_selected.connect(_select_cat)
	ui.outfit_selected.connect(_select_outfit)
	ui.purchase_requested.connect(_purchase)
	ui.sound_toggled.connect(_set_sound)
	ui.camera_reset_requested.connect(_reset_camera)

func _process(delta: float) -> void:
	elapsed += delta
	if not started:
		home_cat.animate_motion(delta, 0.0, 0.0, true)
		for i in range(home_floaters.size()):
			home_floaters[i].position.y = home_origins[i].y + sin(elapsed * 0.85 + float(i) * 1.4) * 0.17
		_update_home_camera(delta)
		return
	_update_camera(delta)
	player.active = not ui.modal_open and not completed and not respawning
	marker.visible = not completed
	marker.position = positions[mini(stage + 1, PLATFORM_COUNT - 1)]
	marker.scale = Vector3.ONE * (1.0 + sin(elapsed * 3.0) * 0.06)
	_update_shadow()
	if player.active:
		for index: int in pickups.keys():
			var pickup: Node3D = pickups[index]
			if is_instance_valid(pickup) and player.global_position.distance_to(pickup.global_position - Vector3.UP * 0.4) < 1.02:
				_collect(index)
		var fall_limit: float = maxf(positions[save.checkpoint].y - 4.5, positions[stage].y - 6.0)
		if player.position.y < fall_limit and not respawning:
			_respawn()
		flight_trail_timer += delta
		if player.velocity.y > 1.0 and flight_trail_timer > 0.09:
			flight_trail_timer = 0.0
			_spawn_trail()
	hud_timer += delta
	if hud_timer > 0.15:
		hud_timer = 0.0
		_update_hud()

func _update_home_camera(_delta: float) -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = size.x / maxf(size.y, 1.0)
	camera.fov = 48.0
	if aspect < 1.25:
		camera.position = Vector3(104.0, 7.0, 19.0)
		camera.look_at(Vector3(99.2, 2.1, 0.0))
	else:
		camera.position = Vector3(104.2, 6.5, 16.2)
		camera.look_at(Vector3(95.3 - maxf(0.0, aspect - 1.78) * 2.0, 1.15, 0.0))

func _update_camera(delta: float) -> void:
	var next: Vector3 = positions[mini(stage + 1, PLATFORM_COUNT - 1)]
	var forward: Vector3 = next - positions[stage]
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	if auto_camera and not dragging:
		var desired_yaw: float = atan2(-forward.x, -forward.z)
		camera_yaw = lerp_angle(camera_yaw, desired_yaw, 1.0 - exp(-delta * 2.4))
	player.camera_yaw = camera_yaw
	var target: Vector3 = player.global_position + Vector3.UP * 1.25 + forward * 0.45
	if not camera_initialized:
		camera_focus = target
		camera_initialized = true
	camera_focus = camera_focus.lerp(target, 1.0 - exp(-delta * 9.0))
	var aspect: float = get_viewport().get_visible_rect().size.aspect()
	var distance: float = camera_distance * (1.15 if aspect < 1.25 else 1.0)
	var offset := Vector3(sin(camera_yaw) * cos(camera_pitch), sin(camera_pitch), cos(camera_yaw) * cos(camera_pitch)) * distance
	var desired_position: Vector3 = camera_focus + offset
	var query := PhysicsRayQueryParameters3D.create(camera_focus, desired_position, 1, [player.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired_position = Vector3(hit["position"]) + Vector3(hit["normal"]) * 0.3
		if desired_position.distance_to(camera_focus) < 2.0:
			desired_position = camera_focus + offset.normalized() * 2.0 + Vector3.UP
	camera.position = desired_position
	camera.fov = lerpf(camera.fov, 60.0 if aspect < 1.25 else 56.0, 1.0 - exp(-delta * 6.0))
	camera.look_at(camera_focus)

func _update_shadow() -> void:
	var from: Vector3 = player.position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 5.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	shadow.visible = not hit.is_empty()
	if shadow.visible:
		shadow.position = Vector3(hit["position"]) + Vector3.UP * 0.035
		var height: float = player.position.y - shadow.position.y
		shadow.scale = Vector3.ONE * (1.0 + height * 0.12)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if ui.modal_open:
			_resume()
		elif started and not completed:
			_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("wardrobe"):
		if ui.modal_open:
			_resume()
		else:
			_open_wardrobe()
		return
	if ui.modal_open:
		return
	if event.is_action_pressed("reset_camera"):
		_reset_camera()
	if event.is_action_pressed("respawn") and started:
		_request_respawn()
	if not started:
		if event.is_action_pressed("jump"):
			_start_game()
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			dragging = event.pressed
			if dragging:
				auto_camera = false
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(4.5, camera_distance - 0.6)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(15.0, camera_distance + 0.6)
	elif event is InputEventMouseMotion and dragging:
		camera_yaw -= event.relative.x * 0.006
		camera_pitch = clampf(camera_pitch + event.relative.y * 0.005, -0.15, 1.2)

func _input(event: InputEvent) -> void:
	# A release over a HUD control still ends the camera drag.
	if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		dragging = false

func _start_game() -> void:
	started = true
	completed = false
	home_scene.visible = false
	world_decor.visible = true
	ui.hide_modal()
	ui.show_game()
	get_viewport().gui_release_focus()
	_place_at_checkpoint()
	player.active = true
	_reset_camera()
	ui.show_toast("按空格跳向下一块，按住可连续跳跃。猫粮包 +3！")

func _place_at_checkpoint() -> void:
	stage = save.checkpoint
	player.current_platform = stage
	player.checkpoint_surface = true
	player.next_target = positions[mini(stage + 1, PLATFORM_COUNT - 1)]
	var direction: Vector3 = player.next_target - positions[stage]
	player.teleport_to(positions[stage], direction)
	camera_yaw = atan2(-direction.x, -direction.z)
	camera_initialized = false
	if is_instance_valid(marker):
		marker.position = player.next_target

func _on_landed(index: int) -> void:
	stage = index
	player.next_target = positions[mini(index + 1, PLATFORM_COUNT - 1)]
	var visual: Node3D = platform_visuals[index]
	if visual.has_meta("bounce_tween"):
		var old: Tween = visual.get_meta("bounce_tween")
		if old != null and old.is_valid():
			old.kill()
	var tween := create_tween()
	visual.set_meta("bounce_tween", tween)
	tween.tween_property(visual, "scale", Vector3(1.09, 0.69, 1.09), 0.09).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(visual, "scale", Vector3(0.96, 1.17, 0.96), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_spawn_burst(positions[index] + Vector3.UP * 0.06, Color("fff2c5"), 8, 0.65)
	_collect(index)
	if index % 7 == 0 and index > save.checkpoint and index < PLATFORM_COUNT - 1:
		save.checkpoint = index
		save.save_game()
		sound.play("checkpoint")
		ui.show_toast("汉堡检查站 %02d 已保存 · 放心向上跳！" % (index / 7 + 1))
		_spawn_burst(positions[index] + Vector3.UP * 0.3, Color("ffb2cd"), 24, 1.3)
	else:
		sound.play("bounce")
	if index > save.best_platform:
		save.best_platform = index
		save.save_game()
	if index == PLATFORM_COUNT - 1 and not completed:
		_finish()
	_update_hud()

func _on_jumped(_assisted: bool) -> void:
	sound.play("jump")

func _collect(index: int) -> void:
	if not pickups.has(index):
		return
	var pickup: Node3D = pickups[index]
	if save.collect(index, 3):
		sound.play("food")
		_spawn_burst(pickup.position, Color("ffd266"), 11, 0.8)
		pickup.take()
		pickups.erase(index)
		_update_hud()

func _respawn() -> void:
	if respawning:
		return
	respawning = true
	player.active = false
	sound.play("fall")
	ui.show_toast("扑通！回到汉堡检查站 · 猫粮已经替你收好")
	await get_tree().create_timer(0.42).timeout
	_place_at_checkpoint()
	respawning = false
	player.active = not ui.modal_open and started and not completed
	_update_hud()

func _request_respawn() -> void:
	if not started:
		return
	if completed:
		_return_to_start()
		return
	ui.hide_modal()
	get_viewport().gui_release_focus()
	completed = false
	_respawn()

func _pause() -> void:
	player.active = false
	dragging = false
	ui.show_pause()

func _resume() -> void:
	ui.hide_modal()
	get_viewport().gui_release_focus()
	if completed:
		_return_to_start()
		return
	player.active = started and not completed and not respawning

func _return_to_start() -> void:
	# Start a new run while retaining earned food, outfits and collection history.
	save.checkpoint = 0
	save.save_game()
	completed = false
	ui.hide_modal()
	ui.show_game()
	get_viewport().gui_release_focus()
	_place_at_checkpoint()
	_reset_camera()
	player.active = started and not respawning
	_update_hud()
	ui.show_toast("已回到起点，再来一次云端冒险吧！")

func _open_wardrobe() -> void:
	player.active = false
	dragging = false
	ui.show_wardrobe(save.state())

func _select_cat(cat_id: String) -> void:
	if not cat_id in SaveData.CATS:
		return
	save.cat_id = cat_id
	_apply_appearance()

func _select_outfit(outfit_id: String) -> void:
	if not outfit_id in save.owned:
		return
	save.outfit_id = outfit_id
	_apply_appearance()

func _purchase(outfit_id: String) -> void:
	if save.purchase(outfit_id):
		sound.play("buy")
		_apply_appearance()
		ui.show_toast("新衣服已穿好，继续出发吧！")
	else:
		ui.show_toast("猫粮还不够，再去云端收集一些吧。")

func _apply_appearance() -> void:
	player.set_appearance(save.cat_id, save.outfit_id)
	home_cat.set_appearance(save.cat_id, save.outfit_id)
	save.save_game()
	ui.show_wardrobe(save.state())
	_update_hud()

func _set_sound(enabled: bool) -> void:
	save.muted = not enabled
	sound.muted = not enabled
	save.save_game()

func _reset_camera() -> void:
	auto_camera = true
	camera_pitch = 0.38
	camera_distance = 9.2
	dragging = false

func _on_focus_lost() -> void:
	if started and not ui.modal_open and not completed and not test_mode:
		_pause()

func _update_hud() -> void:
	ui.update_hud(save.food, stage, PLATFORM_COUNT - 1, save.checkpoint / 7 + 1, maxf(0.0, player.position.y))

func _finish() -> void:
	completed = true
	player.active = false
	save.finished = true
	save.checkpoint = 0
	save.save_game()
	sound.play("finish")
	_spawn_burst(player.position + Vector3.UP, Color("ffb4dc"), 60, 3.0)
	await get_tree().create_timer(0.65).timeout
	if completed:
		_place_at_checkpoint()
		_reset_camera()
		_update_hud()
		if not ui.modal_open:
			ui.show_finish(save.state())

func _spawn_burst(point: Vector3, color: Color, amount: int, reach: float) -> void:
	for i in range(amount):
		var random := RandomNumberGenerator.new()
		random.seed = int(elapsed * 10000.0) + i * 37
		var particle := PlatformFactory.sphere(self, point, Vector3.ONE * random.randf_range(0.06, 0.13), color if i % 3 != 0 else Color("a4ebcd"))
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var vector := Vector3(random.randf_range(-1.0, 1.0), random.randf_range(0.25, 1.6), random.randf_range(-1.0, 1.0)) * reach
		var tween := create_tween().set_parallel(true)
		tween.tween_property(particle, "position", point + vector, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "scale", Vector3.ONE * 0.005, 0.6)
		tween.chain().tween_callback(particle.queue_free)

func _spawn_trail() -> void:
	var particle := PlatformFactory.sphere(self, player.position + Vector3.UP * 0.25, Vector3.ONE * 0.10, Color("fff1cf"))
	particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := create_tween()
	tween.tween_property(particle, "scale", Vector3.ONE * 0.002, 0.35)
	tween.tween_callback(particle.queue_free)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save.save_game()

func _run_smoke() -> void:
	# Runs only with explicit CLI user args. Never reads or writes the player's save.
	await get_tree().process_frame
	await get_tree().process_frame
	print("SMOKE: scene built; platforms=", platforms.size(), " pickups=", pickups.size())
	if "--benchmark" in OS.get_cmdline_user_args():
		save.checkpoint = 14
		_start_game()
		sound.muted = true
		await get_tree().create_timer(3.0).timeout
		var start_frames: int = Engine.get_process_frames()
		var start_time: int = Time.get_ticks_usec()
		await get_tree().create_timer(5.0).timeout
		var frame_count: int = Engine.get_process_frames() - start_frames
		var seconds: float = float(Time.get_ticks_usec() - start_time) / 1000000.0
		print("BENCHMARK: ", snappedf(frame_count / seconds, 0.1), " fps at ", get_window().size, "; draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "; tris=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		get_tree().quit()
		return
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		await _capture("home")
		_start_game()
		await get_tree().create_timer(1.0).timeout
		await _capture("gameplay")
		_open_wardrobe()
		await get_tree().create_timer(0.3).timeout
		await _capture("wardrobe")
		_resume()
		save.checkpoint = 14
		_place_at_checkpoint()
		await get_tree().create_timer(1.0).timeout
		await _capture("cloud_route")
		for size in [Vector2i(640, 480), Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(1600, 700), Vector2i(720, 960)]:
			get_window().size = size
			await get_tree().create_timer(0.45).timeout
			await _capture("resize_%dx%d" % [size.x, size.y])
			_open_wardrobe()
			await get_tree().create_timer(0.2).timeout
			await _capture("wardrobe_%dx%d" % [size.x, size.y])
			_resume()
		started = false
		player.active = false
		world_decor.visible = false
		home_scene.visible = true
		ui.show_home(true)
		await get_tree().create_timer(0.3).timeout
		await _capture("home_portrait")
		print("CAPTURE: done")
		get_tree().quit()
		return
	_start_game()
	Input.action_press("jump")
	var last: int = -1
	var deadline: int = 60 * 65
	for frame in range(deadline):
		await get_tree().physics_frame
		if stage != last:
			print("SMOKE: landed ", stage, " y=", snappedf(player.position.y, 0.01), " food=", save.food)
			last = stage
		if stage == PLATFORM_COUNT - 1:
			break
	Input.action_release("jump")
	if stage != PLATFORM_COUNT - 1:
		push_error("SMOKE FAILED: continuous assisted traversal stopped at %d" % stage)
		get_tree().quit(1)
		return
	print("SMOKE PASS: all 43 platforms traversed; final checkpoint=", save.checkpoint, " food=", save.food)
	var finish_state: Dictionary = save.state()
	var collected_at_finish: Array[int] = save.collected.duplicate()
	await get_tree().create_timer(0.8).timeout
	assert(completed and stage == 0 and save.checkpoint == 0, "Finishing must automatically return to the start")
	assert(player.position.distance_to(positions[0]) < 0.1 and not player.active)
	_resume()
	assert(not completed and player.active and stage == 0)
	assert(save.state() == finish_state and save.collected == collected_at_finish, "Starting again must retain earned rewards")
	var amount: int = save.food
	assert(not save.collect(save.collected[0]), "Previously collected food must not duplicate")
	assert(save.food == amount)
	assert(save.purchase("mint_scarf"))
	assert(save.food == amount - 8)
	assert(not save.purchase("mint_scarf"))
	for cat_id: String in SaveData.CATS:
		player.set_appearance(cat_id, "mint_scarf")
	# Freeze and resume an actual airborne character through both UI entry points.
	player.launch(true)
	await get_tree().physics_frame
	_pause()
	var frozen_position: Vector3 = player.position
	var frozen_velocity: Vector3 = player.velocity
	for frame in range(12):
		await get_tree().physics_frame
	assert(player.position.is_equal_approx(frozen_position), "Pause must freeze position")
	assert(player.velocity.is_equal_approx(frozen_velocity), "Pause must retain momentum")
	_resume()
	await get_tree().physics_frame
	assert(player.active, "Resume must enable physics")
	_open_wardrobe()
	frozen_position = player.position
	for frame in range(12):
		await get_tree().physics_frame
	assert(player.position.is_equal_approx(frozen_position), "Wardrobe must freeze position")
	_resume()
	# Replay checkpoints must advance normally even though lifetime finished is true.
	_on_landed(7)
	await _respawn()
	assert(stage == 7 and save.checkpoint == 7 and player.active)
	assert(player.position.distance_to(positions[7]) < 0.1)
	# R during the finish celebration must return immediately, without a stale dialog.
	var replay_state: Dictionary = save.state()
	_finish()
	_request_respawn()
	await get_tree().create_timer(0.8).timeout
	assert(not completed and player.active and stage == 0 and save.checkpoint == 0)
	assert(not ui.modal_open and save.state() == replay_state)
	await _respawn()
	assert(stage == 0 and save.checkpoint == 0)
	print("SMOKE PASS: automatic finish return, replay checkpoints, rewards retained, collection deduplication, purchase/equip, all five cats, airborne pause/wardrobe, finish R")
	get_tree().quit()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "res://captures/%s.png" % label
	var error: Error = image.save_png(path)
	print("CAPTURE: ", path, " ", image.get_size(), " result=", error)
	print("PERF: fps=", Performance.get_monitor(Performance.TIME_FPS), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " triangles=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
