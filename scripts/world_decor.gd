extends Node3D
## A light, airy miniature world kept beyond the playable spiral.

const Factory = preload("res://scripts/platform_factory.gd")
var _floaters: Array[Node3D] = []
var _origins: Array[Vector3] = []
var _time := 0.0
var _cloud_sphere: SphereMesh
var _cloud_materials: Array[StandardMaterial3D] = []

func build() -> void:
	name = "CandyCloudWorld"
	var rng := RandomNumberGenerator.new()
	rng.seed = 824613
	_cloud_sphere = SphereMesh.new()
	_cloud_sphere.radius = 0.5
	_cloud_sphere.height = 1.0
	_cloud_sphere.radial_segments = 20
	_cloud_sphere.rings = 10
	for color: Color in [Color("f3e7f1"), Color("e5e2f3"), Color("e8ecf3")]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 1.0
		mat.metallic_specular = 0.0
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		mat.disable_receive_shadows = true
		_cloud_materials.append(mat)
	# Open sky between independent cloud banks: no giant disc or horizon edge.
	for i in range(34):
		var a := float(i) * 2.39996
		var radius := 11.0 + sqrt(float(i) / 34.0) * 39.0
		var cloud := Node3D.new()
		add_child(cloud)
		cloud.position = Vector3(cos(a) * radius, rng.randf_range(-12.0, -9.4), sin(a) * radius)
		_cloud(cloud, rng.randf_range(2.2, 4.8), i)
	# Floating cloud banks are widely spaced so they never hide a jump.
	for i in range(15):
		var a := TAU * float(i) / 15.0 + 0.3
		var radius := rng.randf_range(27.0, 41.0)
		var cloud := Node3D.new()
		add_child(cloud)
		cloud.position = Vector3(cos(a) * radius, rng.randf_range(-1.0, 32.0), sin(a) * radius)
		_cloud(cloud, rng.randf_range(1.6, 3.5), i)
		_floaters.append(cloud)
		_origins.append(cloud.position)
	var colors := [Factory.PINK, Factory.GOLD, Factory.MINT, Factory.BLUE, Factory.LILAC]
	for i in range(34):
		var a := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(20.0, 36.0)
		var star := Node3D.new()
		add_child(star)
		star.position = Vector3(cos(a) * radius, rng.randf_range(-5.0, 35.0), sin(a) * radius)
		star.rotation = Vector3(rng.randf_range(-0.5, 0.5), -a + PI / 2.0, rng.randf_range(-0.4, 0.4))
		var size := rng.randf_range(0.23, 0.64)
		if i % 3 == 0:
			var donut := Factory.ring(star, Vector3.ZERO, size, size * 0.24, colors[i % 5])
			donut.rotation.x = PI / 2.0
		else:
			_star(star, size, colors[i % 5])
		_floaters.append(star)
		_origins.append(star.position)
	# Giant lollipops and floating baubles suggest everyday objects at toy scale.
	for i in range(6):
		var a := TAU * float(i) / 6.0 + 0.5
		var radius := 29.0 + float(i % 2) * 6.0
		var base := Vector3(cos(a) * radius, -11.0, sin(a) * radius)
		var height := 9.0 + float(i % 3) * 4.0
		Factory.capsule_between(self, base, base + Vector3.UP * height, 0.15, Factory.CREAM)
		var lolly := Node3D.new()
		add_child(lolly)
		lolly.position = base + Vector3.UP * height
		lolly.rotation = Vector3(PI / 2.0, a, 0.2)
		Factory.cylinder(lolly, Vector3.ZERO, 2.0, 0.36, colors[i % 5])
		for r in [0.48, 1.12, 1.74]:
			Factory.ring(lolly, Vector3(0, 0.20, 0), r, 0.10, Factory.CREAM)
			Factory.ring(lolly, Vector3(0, -0.20, 0), r, 0.10, Factory.CREAM)
	# A few orbital hoops provide silhouettes without filling the sky.
	for i in range(3):
		var hoop := Factory.ring(self, Vector3(25.0 * cos(float(i) * 2.1), 13.0 + float(i) * 6.0, 25.0 * sin(float(i) * 2.1)), 3.1, 0.085, colors[(i + 1) % 5])
		hoop.rotation = Vector3(0.6 + float(i) * 0.3, float(i), 0.4)
	_disable_distant_shadows(self)

func _disable_distant_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_disable_distant_shadows(child)

func _cloud(parent: Node3D, size: float, index: int) -> void:
	# Four soft puffs cost one draw call, and distant clouds cast no shadows.
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _cloud_sphere
	multimesh.instance_count = 4
	var offsets := [Vector3.ZERO, Vector3(-0.65, 0.17, 0), Vector3(0.13, 0.33, 0), Vector3(0.85, 0.07, 0)]
	var scales := [Vector3(2.5, 0.72, 1.35), Vector3(1.32, 1.04, 1.25), Vector3(1.62, 1.33, 1.52), Vector3(1.0, 0.83, 1.08)]
	for i in range(4):
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(scales[i] * size), offsets[i] * size))
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = multimesh
	visual.material_override = _cloud_materials[index % _cloud_materials.size()]
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)

func _star(parent: Node3D, size: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var a := -PI / 2.0 + float(i) * PI / 5.0
		var r := size if i % 2 == 0 else size * 0.46
		points.append(Vector2(cos(a), sin(a)) * r)
	var star_node := Node3D.new()
	parent.add_child(star_node)
	star_node.rotation.x = PI / 2.0
	Factory.flat_polygon(star_node, points, 0, color)

func _process(delta: float) -> void:
	_time += delta
	for i in range(_floaters.size()):
		var floater := _floaters[i]
		floater.position.y = _origins[i].y + sin(_time * 0.42 + float(i) * 1.7) * 0.24
