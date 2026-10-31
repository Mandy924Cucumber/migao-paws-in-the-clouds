extends RefCounted
## Combine opaque, untextured static toy meshes into one colored draw surface.
## Call before attaching animation to individual MeshInstance3D nodes.

static var _material: StandardMaterial3D

static func bake_static(root: Node3D) -> void:
	_bake(root, true)

static func bake_direct(root: Node3D) -> void:
	_bake(root, false)

static func _bake(root: Node3D, recursive: bool) -> void:
	var sources: Array[Dictionary] = []
	_gather(root, Transform3D.IDENTITY, recursive, sources)
	if sources.is_empty():
		return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var casts_shadow: bool = false
	for source: Dictionary in sources:
		var node: MeshInstance3D = source["node"]
		casts_shadow = casts_shadow or node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var transform: Transform3D = source["transform"]
		var normal_basis: Basis = transform.basis.inverse().transposed()
		var mirrored: bool = transform.basis.determinant() < 0.0
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var source_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var source_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var mat: Material = node.material_override
			if mat == null:
				mat = node.get_surface_override_material(surface)
			if mat == null:
				mat = node.mesh.surface_get_material(surface)
			var color := Color.WHITE
			var use_source_colors: bool = false
			var double_sided: bool = false
			if mat is BaseMaterial3D:
				color = mat.albedo_color
				use_source_colors = mat.vertex_color_use_as_albedo
				double_sided = mat.cull_mode == BaseMaterial3D.CULL_DISABLED
			var offset: int = vertices.size()
			for i: int in range(source_vertices.size()):
				vertices.append(transform * source_vertices[i])
				normals.append((normal_basis * source_normals[i]).normalized() if i < source_normals.size() else Vector3.UP)
				uvs.append(source_uvs[i] if i < source_uvs.size() else Vector2.ZERO)
				colors.append(color * source_colors[i] if use_source_colors and i < source_colors.size() else color)
			var count: int = source_indices.size() if not source_indices.is_empty() else source_vertices.size()
			for i: int in range(0, count, 3):
				var a: int = offset + (source_indices[i] if not source_indices.is_empty() else i)
				var b: int = offset + (source_indices[i + 1] if not source_indices.is_empty() else i + 1)
				var c: int = offset + (source_indices[i + 2] if not source_indices.is_empty() else i + 2)
				if mirrored:
					var swap: int = b
					b = c
					c = swap
				if double_sided:
					# Paper artwork can have either winding. Make its front agree
					# with the supplied normals, then supply a real reversed back.
					var face: Vector3 = (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
					if face.dot(normals[a] + normals[b] + normals[c]) < 0.0:
						var swap: int = b
						b = c
						c = swap
				indices.append(a)
				indices.append(b)
				indices.append(c)
				if double_sided:
					for original: int in [a, c, b]:
						indices.append(vertices.size())
						vertices.append(vertices[original])
						normals.append(-normals[original])
						colors.append(colors[original])
						uvs.append(uvs[original])
	if vertices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var merged := MeshInstance3D.new()
	merged.name = "BakedToyMesh"
	merged.mesh = mesh
	merged.material_override = _batch_material()
	merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Sources can contain non-mesh descendants (such as labels). Keep them and
	# their transform relative to the root even when a mesh ancestor disappears.
	for source: Dictionary in sources:
		var node: MeshInstance3D = source["node"]
		var transform: Transform3D = source["transform"]
		for child: Node in node.get_children():
			if child is MeshInstance3D and _contains(sources, child):
				continue
			node.remove_child(child)
			root.add_child(child)
			if child is Node3D:
				child.transform = transform * child.transform
	# Remove deepest sources first so every mesh is freed exactly once.
	for i: int in range(sources.size() - 1, -1, -1):
		var node: MeshInstance3D = sources[i]["node"]
		node.get_parent().remove_child(node)
		node.free()
	root.add_child(merged)

static func _gather(parent: Node, parent_transform: Transform3D, recursive: bool, sources: Array[Dictionary]) -> void:
	for child: Node in parent.get_children():
		var transform: Transform3D = parent_transform
		if child is Node3D:
			if not child.visible:
				continue
			transform = parent_transform * child.transform
		if child is MeshInstance3D and child.mesh != null:
			sources.append({"node": child, "transform": transform})
		if recursive:
			_gather(child, transform, true, sources)

static func _contains(sources: Array[Dictionary], node: Node) -> bool:
	for source: Dictionary in sources:
		if source["node"] == node:
			return true
	return false

static func _batch_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color.WHITE
		_material.vertex_color_use_as_albedo = true
		# Compatibility uses the sRGB vertex values directly; Forward+/Mobile
		# honor this flag and convert them to their linear rendering space.
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.65
		_material.metallic_specular = 0.35
		# Compatibility changes normal handling for CULL_DISABLED. Explicit
		# reversed triangles preserve thin artwork without darkening solid toys.
		_material.cull_mode = BaseMaterial3D.CULL_BACK
	return _material
