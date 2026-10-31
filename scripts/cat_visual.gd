extends Node3D
## Rounded, articulated toy-cat model. Forward is -Z and the paws rest on Y = 0.
## All meshes are local assets generated at runtime, including wearable clothes.

const MeshBatch = preload("res://scripts/mesh_batch.gd")

var _cat_id: String = "orange"
var _outfit_id: String = "none"
var _rig: Node3D
var _head: Node3D
var _tail: Node3D
var _outfit: Node3D
var _legs: Array[Node3D] = []
var _clock: float = 0.0
var _stride: float = 0.0
var _bounce_tween: Tween
var _fur: StandardMaterial3D
var _dark: StandardMaterial3D
var _cream: StandardMaterial3D


func _ready() -> void:
	_build_cat()


func set_appearance(cat_id: String, outfit_id: String) -> void:
	_cat_id = cat_id
	_outfit_id = outfit_id
	if is_inside_tree():
		_build_cat()


func animate_motion(delta: float, planar_speed: float, vertical_speed: float, grounded: bool) -> void:
	if not is_instance_valid(_rig):
		return
	_clock += delta
	var movement: float = clampf(planar_speed / 5.0, 0.0, 1.0)
	_stride += delta * (7.0 + movement * 10.0)
	var stride_strength: float = movement * 0.58 if grounded else 0.12
	for index: int in range(_legs.size()):
		var phase: float = 0.0 if index == 0 or index == 3 else PI
		var leg_target: float = sin(_stride + phase) * stride_strength
		if not grounded:
			leg_target = -0.22 if index < 2 else 0.3
		_legs[index].rotation.x = lerpf(_legs[index].rotation.x, leg_target, minf(delta * 14.0, 1.0))
	_head.rotation.z = sin(_clock * 2.5) * 0.018 + sin(_stride) * movement * 0.018
	_head.rotation.x = lerpf(_head.rotation.x, clampf(-vertical_speed * 0.009, -0.12, 0.12), minf(delta * 8.0, 1.0))
	_tail.rotation.z = sin(_clock * 3.1) * (0.10 + movement * 0.09)
	_tail.rotation.y = sin(_clock * 2.0) * 0.18
	_rig.position.y = sin(_clock * 3.2) * 0.006 + absf(sin(_stride)) * movement * 0.021
	if is_instance_valid(_outfit) and _outfit_id == "star_cape":
		_outfit.rotation.x = sin(_clock * 4.0) * 0.025 - movement * 0.05


func play_bounce() -> void:
	if not is_instance_valid(_rig):
		return
	if is_instance_valid(_bounce_tween):
		_bounce_tween.kill()
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(_rig, "scale", Vector3(1.16, 0.76, 1.13), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_rig, "scale", Vector3(0.91, 1.16, 0.94), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_rig, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _palette() -> Dictionary:
	match _cat_id:
		"white":
			return {"fur": Color("fff5ee"), "dark": Color("ddc9c0"), "cream": Color("fffdf6"), "paw": Color("fff5ee"), "eye": Color("71c3dd")}
		"gray":
			return {"fur": Color("9eabc5"), "dark": Color("596882"), "cream": Color("e8edf7"), "paw": Color("dce3ee"), "eye": Color("cfe17e")}
		"brown":
			return {"fur": Color("b77a53"), "dark": Color("75442f"), "cream": Color("ffe2b4"), "paw": Color("e7bc88"), "eye": Color("a6d6aa")}
		"ragdoll":
			return {"fur": Color("f3e6d0"), "dark": Color("71647b"), "cream": Color("fffaf0"), "paw": Color("81738a"), "eye": Color("69cbea")}
		_:
			return {"fur": Color("ffb34f"), "dark": Color("e07932"), "cream": Color("fff0cf"), "paw": Color("ffe2a1"), "eye": Color("9bcb8b")}


func _build_cat() -> void:
	if is_instance_valid(_bounce_tween):
		_bounce_tween.kill()
	if is_instance_valid(_rig):
		remove_child(_rig)
		_rig.queue_free()
	_legs.clear()
	_rig = Node3D.new()
	_rig.name = "CatModel"
	add_child(_rig)
	var palette: Dictionary = _palette()
	_fur = _material(palette["fur"])
	_dark = _material(palette["dark"])
	_cream = _material(palette["cream"])
	var paw_material: StandardMaterial3D = _material(palette["paw"])
	var pink: StandardMaterial3D = _material(Color("ffa6b2"))
	var black: StandardMaterial3D = _material(Color("393343"))
	var white: StandardMaterial3D = _material(Color("ffffff"))
	var iris: StandardMaterial3D = _material(palette["eye"])
	var blush: StandardMaterial3D = _material(Color("f59f8f"))
	_sphere(_rig, Vector3(0, 0.49, 0.055), Vector3(0.345, 0.355, 0.39), _fur)
	_sphere(_rig, Vector3(0, 0.43, -0.258), Vector3(0.245, 0.264, 0.116), _cream)
	_sphere(_rig, Vector3(-0.23, 0.32, 0.20), Vector3(0.165, 0.205, 0.20), _fur)
	_sphere(_rig, Vector3(0.23, 0.32, 0.20), Vector3(0.165, 0.205, 0.20), _fur)
	for index: int in range(4):
		var leg: Node3D = Node3D.new()
		leg.name = "Paw%d" % index
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var front: bool = index < 2
		leg.position = Vector3(side * 0.22, 0.31, -0.20 if front else 0.23)
		_rig.add_child(leg)
		_legs.append(leg)
		_sphere(leg, Vector3(0, -0.105, 0), Vector3(0.093, 0.17, 0.11), _fur if _cat_id != "ragdoll" else _dark)
		_sphere(leg, Vector3(0, -0.222, -0.035), Vector3(0.116, 0.089, 0.143), paw_material)
		for toe: int in range(2):
			_link(leg, Vector3(-0.028 + toe * 0.056, -0.211, -0.169), Vector3(-0.028 + toe * 0.056, -0.244, -0.167), 0.005, _dark)
	_build_back_stripes()
	_build_tail()
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.86, -0.21)
	_rig.add_child(_head)
	_sphere(_head, Vector3.ZERO, Vector3(0.38, 0.303, 0.31), _fur)
	for side: float in [-1.0, 1.0]:
		var ear: Node3D = Node3D.new()
		ear.position = Vector3(side * 0.245, 0.185, 0.004)
		ear.rotation.z = side * -0.15
		_head.add_child(ear)
		_triangle_prism(ear, Vector3.ZERO, Vector3(0.265, 0.306, 0.135), _dark if _cat_id == "ragdoll" else _fur)
		_triangle_prism(ear, Vector3(0, 0.038, -0.073), Vector3(0.163, 0.193, 0.008), pink)
		_sphere(_head, Vector3(side * 0.26, -0.065, -0.157), Vector3(0.14, 0.152, 0.145), _fur)
		if _cat_id == "ragdoll":
			var mask: MeshInstance3D = _sphere(_head, Vector3(side * 0.171, 0.012, -0.232), Vector3(0.151, 0.185, 0.068), _dark)
			mask.rotation.z = side * -0.20
		_sphere(_head, Vector3(side * 0.149, 0.034, -0.269), Vector3(0.103, 0.123, 0.053), _cream)
		_sphere(_head, Vector3(side * 0.147, 0.032, -0.314), Vector3(0.062, 0.081, 0.027), iris)
		_sphere(_head, Vector3(side * 0.147, 0.034, -0.337), Vector3(0.041, 0.067, 0.017), black)
		_sphere(_head, Vector3(side * 0.147 - 0.017, 0.065, -0.352), Vector3(0.017, 0.021, 0.008), white)
		_sphere(_head, Vector3(side * 0.147 + 0.014, 0.010, -0.350), Vector3(0.008, 0.009, 0.005), white)
		_sphere(_head, Vector3(side * 0.082, -0.107, -0.272), Vector3(0.113, 0.078, 0.077), _cream)
		_sphere(_head, Vector3(side * 0.25, -0.09, -0.268), Vector3(0.048, 0.022, 0.008), blush)
		for whisker: int in range(3):
			var whisker_start: Vector3 = Vector3(side * 0.15, -0.10 - whisker * 0.023, -0.315)
			var whisker_end: Vector3 = Vector3(side * (0.36 + (0.015 if whisker == 1 else 0.0)), -0.08 - whisker * 0.043, -0.327)
			_link(_head, whisker_start, whisker_end, 0.004, black)
	_sphere(_head, Vector3(0, -0.073, -0.343), Vector3(0.038, 0.026, 0.025), pink)
	_link(_head, Vector3(0, -0.087, -0.35), Vector3(0, -0.125, -0.35), 0.005, black)
	_path(_head, [Vector3(-0.065, -0.128, -0.338), Vector3(-0.04, -0.147, -0.347), Vector3(-0.015, -0.141, -0.353), Vector3(0, -0.124, -0.35), Vector3(0.015, -0.141, -0.353), Vector3(0.04, -0.147, -0.347), Vector3(0.065, -0.128, -0.338)], 0.005, black)
	_build_head_stripes()
	var collar: StandardMaterial3D = _material(Color("42d9bd"))
	_torus(_rig, Vector3(0, 0.699, -0.17), 0.255, 0.284, Vector3(1.0, 1.0, 0.92), collar)
	var gold: StandardMaterial3D = _material(Color("ffd95d"), 0.32, 0.25)
	_sphere(_rig, Vector3(0, 0.655, -0.442), Vector3(0.048, 0.050, 0.032), gold)
	_link(_rig, Vector3(-0.023, 0.639, -0.473), Vector3(0.023, 0.639, -0.473), 0.005, black)
	_build_outfit()
	_batch_animated_parts()


func _batch_animated_parts() -> void:
	# Each moving part keeps its pivot; its many tiny meshes share one draw call.
	# The head includes ears and headwear, while clothes keep their own cloth sway.
	MeshBatch.bake_static(_head)
	MeshBatch.bake_static(_tail)
	for leg: Node3D in _legs:
		MeshBatch.bake_static(leg)
	MeshBatch.bake_static(_outfit)
	# Only body/collar meshes belong to the rig; never bake the animated children.
	MeshBatch.bake_direct(_rig)


func _build_back_stripes() -> void:
	if _cat_id == "white" or _cat_id == "ragdoll":
		return
	for stripe: int in range(3):
		var z: float = -0.035 + stripe * 0.14
		var points: Array[Vector3] = []
		for step: int in range(13):
			var x: float = -0.27 + step * 0.045
			var surface: float = sqrt(maxf(0.03, 1.0 - pow(x / 0.35, 2.0) - pow((z - 0.055) / 0.40, 2.0)))
			points.append(Vector3(x, 0.49 + surface * 0.355 + 0.004, z))
		_path(_rig, points, 0.022, _dark)
	for side: float in [-1.0, 1.0]:
		_path(_rig, [Vector3(side * 0.33, 0.49, 0.16), Vector3(side * 0.335, 0.43, 0.18), Vector3(side * 0.318, 0.37, 0.20)], 0.023, _dark)


func _build_head_stripes() -> void:
	if _cat_id == "white" or _cat_id == "ragdoll":
		return
	for mark: int in range(3):
		var x: float = (mark - 1) * 0.094
		_path(_head, [Vector3(x, 0.165, -0.238), Vector3(x * 0.91, 0.214, -0.207), Vector3(x * 0.8, 0.256, -0.161)], 0.020 if mark == 1 else 0.016, _dark)
	for side: float in [-1.0, 1.0]:
		_path(_head, [Vector3(side * 0.321, 0.028, -0.162), Vector3(side * 0.346, 0.038, -0.10), Vector3(side * 0.36, 0.046, -0.034)], 0.017, _dark)
		_path(_head, [Vector3(side * 0.312, -0.028, -0.175), Vector3(side * 0.354, -0.025, -0.10)], 0.014, _dark)
	# The rear crown marks are visible to the player throughout the climb.
	for mark: int in range(3):
		var x: float = (mark - 1) * 0.105
		_path(_head, [Vector3(x, 0.233, 0.166), Vector3(x, 0.181, 0.227), Vector3(x, 0.118, 0.272)], 0.019, _dark)


func _build_tail() -> void:
	_tail = Node3D.new()
	_tail.name = "CurledTail"
	_tail.position = Vector3(0, 0.46, 0.34)
	_rig.add_child(_tail)
	var points: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0.07, 0.045, 0.13), Vector3(0.12, 0.16, 0.20), Vector3(0.145, 0.30, 0.22), Vector3(0.145, 0.44, 0.19), Vector3(0.10, 0.57, 0.13), Vector3(0.005, 0.64, 0.095), Vector3(-0.095, 0.625, 0.08), Vector3(-0.15, 0.545, 0.08), Vector3(-0.135, 0.48, 0.08)]
	for index: int in range(points.size()):
		var radius: float = lerpf(0.075, 0.049, float(index) / float(points.size() - 1))
		var material: StandardMaterial3D = _fur
		if _cat_id == "ragdoll" or (_cat_id != "white" and (index == 3 or index == 6 or index == 9)):
			material = _dark
		_sphere(_tail, points[index], Vector3.ONE * radius, material)
		if index > 0:
			_link(_tail, points[index - 1], points[index], radius, material)


func _build_outfit() -> void:
	_outfit = Node3D.new()
	_outfit.name = "Wardrobe"
	_rig.add_child(_outfit)
	match _outfit_id:
		"mint_scarf":
			var mint: StandardMaterial3D = _material(Color("39dbc2"))
			var light_mint: StandardMaterial3D = _material(Color("b8fff0"))
			_torus(_outfit, Vector3(0, 0.728, -0.145), 0.265, 0.328, Vector3(1, 0.75, 0.94), mint)
			var end_a: MeshInstance3D = _sphere(_outfit, Vector3(-0.105, 0.54, -0.398), Vector3(0.075, 0.192, 0.035), mint)
			end_a.rotation.z = -0.22
			var end_b: MeshInstance3D = _sphere(_outfit, Vector3(0.035, 0.59, -0.426), Vector3(0.067, 0.145, 0.039), light_mint)
			end_b.rotation.z = 0.24
			_sphere(_outfit, Vector3(-0.046, 0.719, -0.441), Vector3(0.089, 0.070, 0.045), mint)
			# A generous bow reads clearly from the third-person camera.
			for side: float in [-1.0, 1.0]:
				var bow: MeshInstance3D = _sphere(_outfit, Vector3(side * 0.13, 0.746, 0.145), Vector3(0.142, 0.089, 0.040), mint)
				bow.rotation.z = side * 0.3
			_sphere(_outfit, Vector3(0, 0.746, 0.18), Vector3(0.054, 0.052, 0.036), light_mint)
		"berry_cap":
			var berry: StandardMaterial3D = _material(Color("f56b9a"))
			var seed: StandardMaterial3D = _material(Color("ffe9a1"))
			_sphere(_head, Vector3(-0.036, 0.291, 0.012), Vector3(0.322, 0.135, 0.255), berry)
			_torus(_head, Vector3(-0.036, 0.236, 0.012), 0.256, 0.276, Vector3(1, 0.66, 0.84), berry)
			var leaf_material: StandardMaterial3D = _material(Color("52cd9a"))
			for leaf: int in range(3):
				var leaf_mesh: MeshInstance3D = _sphere(_head, Vector3(-0.05 + leaf * 0.043, 0.426, 0.015), Vector3(0.043, 0.010, 0.102), leaf_material)
				leaf_mesh.rotation.y = -0.75 + leaf * 0.75
			for point: int in range(9):
				var angle: float = point * TAU / 9.0
				_sphere(_head, Vector3(-0.036 + cos(angle) * 0.253, 0.326, 0.012 + sin(angle) * 0.19), Vector3(0.012, 0.020, 0.010), seed)
		"star_cape":
			var violet: StandardMaterial3D = _material(Color("9976f4"))
			var lilac: StandardMaterial3D = _material(Color("c0a3ff"))
			var star_material: StandardMaterial3D = _material(Color("ffec86"), 0.43, 0.08)
			_torus(_outfit, Vector3(0, 0.719, -0.12), 0.26, 0.30, Vector3(1, 0.8, 0.94), lilac)
			_cape(_outfit, violet)
			_path(_outfit, [Vector3(-0.39, 0.22, 0.49), Vector3(-0.19, 0.195, 0.525), Vector3(0, 0.21, 0.54), Vector3(0.19, 0.195, 0.525), Vector3(0.39, 0.22, 0.49)], 0.018, lilac)
			_star(_outfit, Vector3(0, 0.46, 0.481), 0.112, 0.016, star_material)
			_star(_outfit, Vector3(-0.22, 0.30, 0.518), 0.044, 0.012, star_material)
			_star(_outfit, Vector3(0.22, 0.34, 0.500), 0.038, 0.012, star_material)
			_sphere(_outfit, Vector3(0, 0.70, -0.424), Vector3(0.048, 0.048, 0.025), star_material)
		"crown":
			var gold: StandardMaterial3D = _material(Color("ffd157"), 0.32, 0.35)
			var gem: StandardMaterial3D = _material(Color("ff77aa"), 0.2, 0.08)
			_torus(_head, Vector3(0, 0.299, -0.005), 0.175, 0.212, Vector3(1, 1.0, 0.85), gold)
			for point: int in range(5):
				var angle: float = -PI * 0.5 + point * TAU / 5.0
				var position_crown: Vector3 = Vector3(cos(angle) * 0.192, 0.288, sin(angle) * 0.164 - 0.005)
				var crown_point: Node3D = Node3D.new()
				crown_point.position = position_crown
				crown_point.rotation.y = -angle + PI * 0.5
				_head.add_child(crown_point)
				_triangle_prism(crown_point, Vector3.ZERO, Vector3(0.136, 0.173, 0.023), gold)
				_sphere(crown_point, Vector3(0, 0.174, 0), Vector3.ONE * 0.025, gold)
			_sphere(_head, Vector3(0, 0.345, -0.183), Vector3(0.033, 0.043, 0.021), gem)


func _material(color: Color, roughness: float = 0.72, metallic: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _sphere(parent: Node3D, position_value: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	instance.scale = scale_value
	parent.add_child(instance)
	return instance


func _link(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 16
	instance.mesh = mesh
	instance.material_override = material
	instance.position = (from + to) * 0.5
	var direction: Vector3 = (to - from).normalized()
	if direction.length_squared() > 0.001:
		instance.quaternion = Quaternion(Vector3.UP, direction)
	parent.add_child(instance)
	return instance


func _path(parent: Node3D, points: Array[Vector3], radius: float, material: Material) -> void:
	for index: int in range(points.size()):
		_sphere(parent, points[index], Vector3.ONE * radius, material)
		if index > 0:
			_link(parent, points[index - 1], points[index], radius, material)


func _torus(parent: Node3D, position_value: Vector3, inner: float, outer: float, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 12
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	instance.scale = scale_value
	parent.add_child(instance)
	return instance


func _triangle_prism(parent: Node3D, position_value: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var points: Array[Vector3] = [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0, 1, -0.5), Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, 0.5), Vector3(0, 1, 0.5)]
	var faces: Array[int] = [0, 2, 1, 3, 4, 5, 0, 3, 5, 0, 5, 2, 1, 2, 5, 1, 5, 4, 0, 1, 4, 0, 4, 3]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in faces:
		surface.add_vertex(points[index] * dimensions)
	surface.generate_normals()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	instance.position = position_value
	parent.add_child(instance)
	return instance


func _cape(parent: Node3D, material: StandardMaterial3D) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(8):
		for column: int in range(12):
			var u0: float = column / 12.0
			var u1: float = (column + 1) / 12.0
			var v0: float = row / 8.0
			var v1: float = (row + 1) / 8.0
			var a: Vector3 = _cape_point(u0, v0)
			var b: Vector3 = _cape_point(u1, v0)
			var c: Vector3 = _cape_point(u0, v1)
			var d: Vector3 = _cape_point(u1, v1)
			for vertex: Vector3 in [a, c, b, b, c, d]:
				surface.add_vertex(vertex)
	surface.generate_normals()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = surface.commit()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	parent.add_child(instance)


func _cape_point(u: float, v: float) -> Vector3:
	var across: float = u * 2.0 - 1.0
	var width: float = lerpf(0.20, 0.39, v)
	var y: float = lerpf(0.735, 0.21, v) - sin(u * PI * 4.0) * 0.014 * v
	var z: float = lerpf(0.14, 0.54, sqrt(v)) - across * across * 0.045 + sin(u * PI * 6.0) * 0.012 * v
	return Vector3(across * width, y, z)


func _star(parent: Node3D, position_value: Vector3, radius: float, depth: float, material: Material) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point: int in range(10):
		var angle_a: float = PI * 0.5 + point * TAU / 10.0
		var angle_b: float = PI * 0.5 + (point + 1) * TAU / 10.0
		var radius_a: float = radius if point % 2 == 0 else radius * 0.45
		var radius_b: float = radius if point % 2 == 1 else radius * 0.45
		var a: Vector3 = Vector3(cos(angle_a) * radius_a, sin(angle_a) * radius_a, 0)
		var b: Vector3 = Vector3(cos(angle_b) * radius_b, sin(angle_b) * radius_b, 0)
		for vertex: Vector3 in [Vector3(0, 0, depth), a, b]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = surface.commit()
	var double_material: Material = material.duplicate()
	(double_material as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = double_material
	instance.position = position_value
	parent.add_child(instance)
