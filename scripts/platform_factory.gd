extends RefCounted
## Procedural toy-scale props. All playable surfaces are at local y = 0.

const MeshBatch = preload("res://scripts/mesh_batch.gd")

const CREAM := Color("fff6e7")
const PINK := Color("ff629c")
const BLUE := Color("79c9ff")
const MINT := Color("78e4c2")
const LILAC := Color("bc94f5")
const GOLD := Color("ffd05a")
static var _materials: Dictionary = {}
static var _unit_sphere: SphereMesh

static func create(kind: String, index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Prop_%s_%02d" % [kind, index]
	match kind:
		"card": _card(root, index)
		"candy": _candy(root, index)
		"ball": _ball(root, index)
		"burger": _burger(root)
		"cookie": _cookie(root, index)
		"gift": _gift(root, index)
		"finish": _finish(root)
		_: _candy(root, index)
	MeshBatch.bake_static(root)
	return root

static func material(color: Color, roughness: float = 0.63) -> StandardMaterial3D:
	var key := str(color) + str(roughness)
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic_specular = 0.35
	_materials[key] = mat
	return mat

static func mesh_node(parent: Node3D, mesh: Mesh, color: Color, position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = position
	parent.add_child(node)
	return node

static func sphere(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if _unit_sphere == null:
		_unit_sphere = SphereMesh.new()
		_unit_sphere.radius = 0.5
		_unit_sphere.height = 1.0
		_unit_sphere.radial_segments = 24
		_unit_sphere.rings = 12
	var node := mesh_node(parent, _unit_sphere, color, position)
	node.scale = size
	return node

static func box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_node(parent, mesh, color, position)

static func cylinder(parent: Node3D, position: Vector3, radius: float, height: float, color: Color, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	return mesh_node(parent, mesh, color, position)

static func ring(parent: Node3D, position: Vector3, radius: float, thickness: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 48
	mesh.ring_segments = 8
	return mesh_node(parent, mesh, color, position)

static func capsule_between(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = a.distance_to(b) + radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 2
	var node := mesh_node(parent, mesh, color, (a + b) / 2.0)
	var direction := (b - a).normalized()
	node.quaternion = Quaternion(Vector3.UP, direction)
	return node

static func rounded_rect(parent: Node3D, center: Vector3, width: float, depth: float, height: float, radius: float, color: Color) -> void:
	# One smooth, closed mesh rather than overlapping boxes at the rounded corners.
	var outline := PackedVector2Array()
	for corner in range(4):
		var sx := 1.0 if corner == 0 or corner == 3 else -1.0
		var sz := 1.0 if corner < 2 else -1.0
		var corner_center := Vector2(sx * (width / 2.0 - radius), sz * (depth / 2.0 - radius))
		var start := float(corner) * PI / 2.0
		for j in range(9):
			var angle := start + float(j) * PI / 16.0
			outline.append(corner_center + Vector2(cos(angle), sin(angle)) * radius)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := outline.size()
	for i in range(count):
		var j := (i + 1) % count
		var a := Vector3(outline[i].x, height / 2.0, outline[i].y)
		var b := Vector3(outline[j].x, height / 2.0, outline[j].y)
		var c := a - Vector3.UP * height
		var d := b - Vector3.UP * height
		st.set_smooth_group(0)
		_triangle(st, Vector3(0, height / 2.0, 0), b, a)
		st.set_smooth_group(1)
		_triangle(st, Vector3(0, -height / 2.0, 0), c, d)
		st.set_smooth_group(2)
		_triangle(st, a, b, c)
		_triangle(st, b, d, c)
	st.generate_normals()
	mesh_node(parent, st.commit(), color, center)

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)

static func flat_polygon(parent: Node3D, points: PackedVector2Array, y: float, color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		# Clockwise when viewed from above is Godot's front face.
		for j in [0, 2, 1]:
			var p: Vector2 = points[indices[i + j]]
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(p.x, y, p.y))
	var node := mesh_node(parent, st.commit(), color)
	# Thin paper artwork remains visible regardless of polygon winding.
	var mat := material(color).duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat

static func lathe(parent: Node3D, profile: Array[Vector2], color: Color, slices: int = 64) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(profile.size() - 1):
		st.set_smooth_group(0 if level == 0 else (2 if level == profile.size() - 2 else 1))
		for i in range(slices):
			var a := TAU * float(i) / float(slices)
			var b := TAU * float(i + 1) / float(slices)
			var p := profile[level]
			var q := profile[level + 1]
			var va := Vector3(cos(a) * p.x, p.y, sin(a) * p.x)
			var vb := Vector3(cos(b) * p.x, p.y, sin(b) * p.x)
			var vc := Vector3(cos(a) * q.x, q.y, sin(a) * q.x)
			var vd := Vector3(cos(b) * q.x, q.y, sin(b) * q.x)
			_triangle(st, va, vb, vc)
			_triangle(st, vb, vd, vc)
	st.generate_normals()
	mesh_node(parent, st.commit(), color)

static func _heart(parent: Node3D, center: Vector2, scale_value: float, y: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(48):
		var t := TAU * float(i) / 48.0
		var px := 16.0 * pow(sin(t), 3.0)
		var py := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		points.append(center + Vector2(px, -py) * scale_value / 32.0)
	flat_polygon(parent, points, y, color)

static func _diamond(parent: Node3D, center: Vector2, width: float, y: float, color: Color) -> void:
	flat_polygon(parent, PackedVector2Array([center + Vector2(0, -width * 0.67), center + Vector2(width * 0.48, 0), center + Vector2(0, width * 0.67), center + Vector2(-width * 0.48, 0)]), y, color)

static func _ace(parent: Node3D, center: Vector2, flip: float, color: Color) -> void:
	var left := Vector3(center.x - 0.13, 0.012, center.y + 0.18 * flip)
	var right := Vector3(center.x + 0.13, 0.012, center.y + 0.18 * flip)
	var peak := Vector3(center.x, 0.012, center.y - 0.18 * flip)
	capsule_between(parent, left, peak, 0.025, color)
	capsule_between(parent, right, peak, 0.025, color)
	capsule_between(parent, left.lerp(peak, 0.40), right.lerp(peak, 0.40), 0.020, color)

static func _card(parent: Node3D, index: int) -> void:
	var red := Color("f25b83") if index % 2 == 0 else Color("7272c6")
	rounded_rect(parent, Vector3(0, -0.17, 0), 3.4, 2.5, 0.34, 0.22, Color("a78ac8"))
	rounded_rect(parent, Vector3(0, -0.055, 0), 3.37, 2.47, 0.11, 0.21, CREAM)
	# Fine edge border printed into the card.
	rounded_rect(parent, Vector3(0, 0.003, 0), 3.12, 2.22, 0.005, 0.16, Color("f6bcd0"))
	rounded_rect(parent, Vector3(0, 0.007, 0), 3.07, 2.17, 0.005, 0.14, CREAM)
	_ace(parent, Vector2(-1.33, -0.69), 1.0, red)
	_ace(parent, Vector2(1.33, 0.69), -1.0, red)
	if index % 2 == 0:
		_heart(parent, Vector2.ZERO, 1.30, 0.016, red)
		_heart(parent, Vector2(-1.33, -0.20), 0.29, 0.016, red)
		_heart(parent, Vector2(1.33, 0.20), 0.29, 0.016, red)
	else:
		_diamond(parent, Vector2.ZERO, 1.08, 0.016, red)
		_diamond(parent, Vector2(-1.33, -0.20), 0.23, 0.016, red)
		_diamond(parent, Vector2(1.33, 0.20), 0.23, 0.016, red)

static func _candy(parent: Node3D, index: int) -> void:
	var palette := [PINK, MINT, LILAC, BLUE]
	var color: Color = palette[index % palette.size()]
	lathe(parent, [Vector2(0, 0), Vector2(1.37, 0), Vector2(1.46, -0.08), Vector2(1.50, -0.27), Vector2(1.46, -0.50), Vector2(1.32, -0.62), Vector2(0, -0.62)], color)
	ring(parent, Vector3(0, -0.12, 0), 1.45, 0.032, CREAM)
	# Four broad peppermint ribbons cut into the flat sugar surface.
	for arm in range(4):
		var points := PackedVector2Array()
		for i in range(25):
			var r := 0.12 + float(i) / 24.0 * 1.24
			var angle := float(arm) * PI / 2.0 + r * 1.15
			points.append(Vector2(cos(angle), sin(angle)) * r)
		for i in range(24, -1, -1):
			var r := 0.12 + float(i) / 24.0 * 1.24
			var angle := float(arm) * PI / 2.0 + r * 1.15 + 0.38
			points.append(Vector2(cos(angle), sin(angle)) * r)
		flat_polygon(parent, points, 0.008, CREAM)
	for side in [-1.0, 1.0]:
		var twist := sphere(parent, Vector3(side * 1.53, -0.30, 0), Vector3(0.37, 0.45, 0.42), color.lightened(0.15))
		twist.rotation.x = 0.4
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(6):
			var a := TAU * float(i) / 6.0
			var b := TAU * float(i + 1) / 6.0
			_triangle(st, Vector3(side * 1.56, -0.30, 0), Vector3(side * 2.25, -0.30 + sin(a) * 0.30, cos(a) * 0.69), Vector3(side * 2.25, -0.30 + sin(b) * 0.30, cos(b) * 0.69))
		st.generate_normals()
		var wrap := mesh_node(parent, st.commit(), color.lightened(0.28))
		var mat := material(color.lightened(0.28)).duplicate() as StandardMaterial3D
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		wrap.material_override = mat
		for z in [-0.34, 0.34]:
			capsule_between(parent, Vector3(side * 1.64, -0.02, z * 0.15), Vector3(side * 2.23, -0.04, z), 0.025, CREAM)

static func _ball(parent: Node3D, index: int) -> void:
	var colors := [BLUE, CREAM, PINK, GOLD, MINT, CREAM]
	var profile: Array[Vector2] = [Vector2(0, 0), Vector2(1.34, 0), Vector2(1.53, -0.20), Vector2(1.66, -0.54), Vector2(1.62, -0.94), Vector2(1.44, -1.30), Vector2(1.09, -1.60), Vector2(0.56, -1.80), Vector2(0, -1.87)]
	for sector in range(6):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for level in range(profile.size() - 1):
			st.set_smooth_group(0 if level == 0 else 1)
			for i in range(10):
				var a := TAU * (float(sector) / 6.0 + float(i) / 60.0)
				var b := a + TAU / 60.0
				var p := profile[level]
				var q := profile[level + 1]
				var va := Vector3(cos(a) * p.x, p.y, sin(a) * p.x)
				var vb := Vector3(cos(b) * p.x, p.y, sin(b) * p.x)
				var vc := Vector3(cos(a) * q.x, q.y, sin(a) * q.x)
				var vd := Vector3(cos(b) * q.x, q.y, sin(b) * q.x)
				_triangle(st, va, vb, vc)
				_triangle(st, vb, vd, vc)
		st.generate_normals()
		mesh_node(parent, st.commit(), colors[(sector + index) % colors.size()])
	cylinder(parent, Vector3(0, 0.004, 0), 0.29, 0.012, CREAM)
	ring(parent, Vector3(0, 0.012, 0), 0.22, 0.023, PINK)

static func _burger(parent: Node3D) -> void:
	# Squashed dome leaves a genuinely flat landing area at the bun crown.
	lathe(parent, [Vector2(0, 0), Vector2(1.68, 0), Vector2(1.82, -0.08), Vector2(1.96, -0.31), Vector2(2.0, -0.47), Vector2(1.96, -0.58), Vector2(0, -0.58)], Color("f7b651"))
	ring(parent, Vector3(0, -0.50, 0), 1.93, 0.04, Color("ed9840"))
	lathe(parent, [Vector2(0, -1.08), Vector2(1.82, -1.08), Vector2(1.97, -1.15), Vector2(1.94, -1.34), Vector2(1.77, -1.43), Vector2(0, -1.43)], Color("e99b42"))
	cylinder(parent, Vector3(0, -0.94, 0), 1.94, 0.22, Color("80462e"))
	cylinder(parent, Vector3(0, -0.66, 0), 1.92, 0.15, Color("ff705d"))
	var cheese := box(parent, Vector3(0, -0.77, 0), Vector3(3.03, 0.105, 3.03), GOLD)
	cheese.rotation.y = 0.32
	for i in range(10):
		var a := TAU * float(i) / 10.0
		var leaf := sphere(parent, Vector3(cos(a) * 1.62, -1.07 + 0.028 * sin(a * 3), sin(a) * 1.62), Vector3(0.93, 0.15, 0.60), Color("86dc79"))
		leaf.rotation.y = -a
	for i in range(20):
		var a := float(i) * 2.39996
		var r := 0.30 + sqrt(float(i) / 20.0) * 1.18
		var seed := sphere(parent, Vector3(cos(a) * r, 0.012, sin(a) * r), Vector3(0.15, 0.028, 0.062), CREAM)
		seed.rotation.y = a + 0.7
	# A tiny picnic pick is placed outside the playable crown.
	capsule_between(parent, Vector3(1.66, -0.16, -0.90), Vector3(1.66, 0.87, -0.90), 0.023, CREAM)
	var flag := box(parent, Vector3(1.94, 0.68, -0.90), Vector3(0.56, 0.33, 0.022), MINT)
	flag.rotation.z = -0.06

static func _cookie(parent: Node3D, index: int) -> void:
	lathe(parent, [Vector2(0, 0), Vector2(1.40, 0), Vector2(1.55, -0.07), Vector2(1.59, -0.20), Vector2(1.53, -0.36), Vector2(1.37, -0.43), Vector2(0, -0.43)], Color("e9aa62"))
	var frosting: Color = [PINK, LILAC, MINT][index % 3]
	cylinder(parent, Vector3(0, -0.016, 0), 1.37, 0.026, frosting)
	ring(parent, Vector3(0, -0.007, 0), 1.33, 0.045, frosting.lightened(0.16))
	var sprinkle_colors := [CREAM, GOLD, BLUE, PINK, MINT]
	for i in range(17):
		var a := float(i) * 2.39996
		var r := 0.22 + sqrt(float(i) / 17.0) * 0.94
		var center := Vector3(cos(a) * r, 0.013, sin(a) * r)
		var direction := Vector3(cos(a * 2.3), 0, sin(a * 2.3)) * 0.066
		capsule_between(parent, center - direction, center + direction, 0.022, sprinkle_colors[i % sprinkle_colors.size()])

static func _gift(parent: Node3D, index: int) -> void:
	var color: Color = [LILAC, MINT, BLUE, PINK][index % 4]
	rounded_rect(parent, Vector3(0, -0.68, 0), 2.67, 2.67, 1.30, 0.14, color.darkened(0.05))
	rounded_rect(parent, Vector3(0, -0.13, 0), 2.84, 2.84, 0.26, 0.15, color)
	box(parent, Vector3(0, 0.006, 0), Vector3(0.39, 0.012, 2.81), CREAM)
	box(parent, Vector3(0, 0.014, 0), Vector3(2.81, 0.012, 0.39), CREAM)
	for side in [-1.0, 1.0]:
		box(parent, Vector3(0, -0.73, side * 1.341), Vector3(0.39, 1.15, 0.014), CREAM)
		box(parent, Vector3(side * 1.341, -0.73, 0), Vector3(0.014, 1.15, 0.39), CREAM)
	# Printed bow preserves a smooth landing surface.
	for side in [-1.0, 1.0]:
		var loop := ring(parent, Vector3(side * 0.40, 0.021, 0), 0.32, 0.032, GOLD)
		loop.scale = Vector3(1.36, 0.34, 0.67)
		sphere(parent, Vector3(side * 0.40, 0.022, 0), Vector3(0.68, 0.018, 0.27), color)
	sphere(parent, Vector3(0, 0.024, 0), Vector3(0.19, 0.025, 0.19), GOLD)
	for i in range(8):
		var a := TAU * float(i) / 8.0 + PI / 8.0
		_diamond(parent, Vector2(cos(a), sin(a)) * 1.04, 0.14, 0.009, color.lightened(0.44))

static func _finish(parent: Node3D) -> void:
	cylinder(parent, Vector3(0, -1.48, 0), 2.51, 0.14, GOLD)
	lathe(parent, [Vector2(0, 0), Vector2(2.19, 0), Vector2(2.29, -0.10), Vector2(2.31, -1.28), Vector2(2.18, -1.40), Vector2(0, -1.40)], CREAM)
	cylinder(parent, Vector3(0, -0.93, 0), 2.318, 0.25, PINK)
	cylinder(parent, Vector3(0, -0.47, 0), 2.320, 0.16, Color("c9a5ee"))
	ring(parent, Vector3(0, -0.07, 0), 2.20, 0.095, PINK)
	for i in range(18):
		var a := TAU * float(i) / 18.0
		sphere(parent, Vector3(cos(a) * 2.20, -0.22, sin(a) * 2.20), Vector3(0.22, 0.39, 0.22), PINK)
	for i in range(12):
		var a := TAU * float(i) / 12.0
		var p := Vector3(cos(a) * 1.88, 0.025, sin(a) * 1.88)
		sphere(parent, p, Vector3(0.24, 0.10, 0.24), [PINK, MINT, BLUE, GOLD][i % 4])
	_heart(parent, Vector2.ZERO, 1.65, 0.012, PINK)
	# Twin celebration flags sit on the far perimeter.
	for side in [-1.0, 1.0]:
		capsule_between(parent, Vector3(side * 1.77, 0, -0.94), Vector3(side * 1.77, 1.12, -0.94), 0.027, GOLD)
		box(parent, Vector3(side * 1.49, 0.91, -0.94), Vector3(0.54, 0.35, 0.025), MINT if side < 0 else LILAC)
