extends Node3D

const MeshBatch = preload("res://scripts/mesh_batch.gd")

var index: int = 0
var elapsed: float = 0.0
var collected: bool = false
var visual: Node3D

func _ready() -> void:
	visual = Node3D.new()
	add_child(visual)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffb54e")
	material.metallic = 0.18
	material.roughness = 0.36
	material.emission_enabled = true
	material.emission = Color("ffc76e")
	material.emission_energy_multiplier = 0.25
	var coin := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.32
	cylinder.bottom_radius = 0.32
	cylinder.height = 0.12
	cylinder.radial_segments = 32
	coin.mesh = cylinder
	coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coin.rotation_degrees.x = 90.0
	coin.material_override = material
	visual.add_child(coin)
	var paw_material := StandardMaterial3D.new()
	paw_material.albedo_color = Color("fff3c6")
	paw_material.roughness = 0.65
	for side in [-1.0, 1.0]:
		var center := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.1
		sphere.height = 0.2
		sphere.radial_segments = 12
		sphere.rings = 6
		center.mesh = sphere
		center.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		center.scale = Vector3(1.22, 0.95, 0.34)
		center.position = Vector3(0.0, -0.075, side * 0.07)
		center.material_override = paw_material
		visual.add_child(center)
		for toe in range(3):
			var dot := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radius = 0.052
			ball.height = 0.12
			ball.radial_segments = 12
			ball.rings = 6
			dot.mesh = ball
			dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dot.scale.z = 0.42
			dot.position = Vector3((toe - 1) * 0.108, 0.055 + (0.052 if toe == 1 else 0.0), side * 0.076)
			dot.material_override = paw_material
			visual.add_child(dot)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.40
	torus.outer_radius = 0.425
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.material_override = paw_material
	ring.rotation_degrees.x = 90.0
	visual.add_child(ring)
	MeshBatch.bake_static(visual)
	for child: Node in visual.get_children():
		if child is GeometryInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	if collected:
		return
	elapsed += delta
	visual.position.y = sin(elapsed * 2.5 + index) * 0.12
	visual.rotation.y += delta * 1.4

func take() -> void:
	if collected:
		return
	collected = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 1.1, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE * 0.02, 0.32)
	tween.chain().tween_callback(queue_free)
