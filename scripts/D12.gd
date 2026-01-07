extends Node3D

signal rolled(value: int)

@export var roll_duration := 0.9
@export var lift_height := 0.50
@export var settle_duration := 0.18
@export var min_spins := 2
@export var max_spins := 4

@export var mirror_numbers := true
@export var body_scale := 0.95
@export var label_font_size := 88
@export var label_pixel_size := 0.0085
@export var face_label_outset := 0.03
@export var label_local_outset := 0.012

@export var outline_enabled := false

var is_rolling := false
var _rng := RandomNumberGenerator.new()
var _face_normals: Array = []
var _target_value: int = 1
var _rest_pos: Vector3 = Vector3.ZERO
var _dodeca_verts: Array[Vector3] = []
var _dodeca_faces: Array = [] # Array of Array[int] (12 pentagons)

@onready var body: MeshInstance3D = $Body
@onready var outline: MeshInstance3D = $Body/Outline
@onready var edges: MeshInstance3D = $Body/Edges


func _ready() -> void:
	_rng.randomize()
	_build_mesh()
	_configure_outline()
	_configure_edges()
	_build_numbers()
	rotation = Vector3.ZERO
	_rest_pos = position


func roll() -> void:
	if is_rolling:
		return

	_target_value = _rng.randi_range(1, 12)

	var spins := Vector3(
		_rng.randi_range(min_spins, max_spins),
		_rng.randi_range(min_spins, max_spins),
		_rng.randi_range(min_spins, max_spins)
	) * TAU
	var wobble := Vector3(
		_rng.randf_range(-0.6, 0.6),
		_rng.randf_range(-0.6, 0.6),
		_rng.randf_range(-0.6, 0.6)
	)

	is_rolling = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _rest_pos + Vector3(0, lift_height, 0), 0.18)
	tween.tween_property(self, "rotation", rotation + spins + wobble, roll_duration)
	tween.set_parallel(false)
	tween.tween_property(self, "scale", Vector3(1.07, 0.93, 1.07), 0.10).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(self, "_finish_roll"))


func _finish_roll() -> void:
	rotation = Vector3(
		wrapf(rotation.x, -PI, PI),
		wrapf(rotation.y, -PI, PI),
		wrapf(rotation.z, -PI, PI)
	)

	var cam := get_viewport().get_camera_3d()
	var desired_dir: Vector3 = Vector3.FORWARD
	if cam != null:
		desired_dir = (cam.global_position - global_position).normalized()

	var face := _get_face_for_value(_target_value)
	var target_basis := _compute_target_basis(desired_dir, face["normal"], face["up"])
	var snap_rot := target_basis.get_euler()
	var safe_pos := _compute_safe_position(target_basis)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", snap_rot, settle_duration)
	tween.tween_property(self, "position", safe_pos, settle_duration)
	tween.tween_callback(Callable(self, "_emit_roll").bind(_target_value))


func _emit_roll(value: int) -> void:
	is_rolling = false
	rolled.emit(value)


func _build_mesh() -> void:
	# Build a regular dodecahedron robustly as the dual of an icosahedron.
	# This avoids fragile hard-coded face index lists.
	_generate_dodecahedron()

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Triangulate each pentagon as a fan around its first vertex.
	for face in _dodeca_faces:
		var idxs: Array = face
		if idxs.size() != 5:
			continue
		var i0: int = int(idxs[0])
		var i1: int = int(idxs[1])
		var i2: int = int(idxs[2])
		var i3: int = int(idxs[3])
		var i4: int = int(idxs[4])

		var a: Vector3 = _dodeca_verts[i0]
		var b: Vector3 = _dodeca_verts[i1]
		var c: Vector3 = _dodeca_verts[i2]
		var d: Vector3 = _dodeca_verts[i3]
		var e: Vector3 = _dodeca_verts[i4]

		_add_tri(st, a, b, c)
		_add_tri(st, a, c, d)
		_add_tri(st, a, d, e)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.95, 1.0)
	mat.roughness = 0.45
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mesh.surface_set_material(0, mat)

	body.mesh = mesh
	body.scale = Vector3.ONE * body_scale

	if outline != null:
		outline.mesh = mesh
	if edges != null:
		edges.mesh = null


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Ensure outward winding relative to origin.
	var center: Vector3 = (a + b + c) / 3.0
	var n: Vector3 = (b - a).cross(c - a)
	if n.dot(center) < 0.0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)


func _configure_outline() -> void:
	if outline == null:
		return
	outline.visible = outline_enabled
	if not outline_enabled:
		return
	outline.scale = Vector3.ONE * 1.05
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.04, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.material_override = mat


func _configure_edges() -> void:
	if edges == null:
		return
	# For pentagon faces, we want only boundary edges (no triangulation diagonals).
	if _dodeca_verts.size() == 0 or _dodeca_faces.size() == 0:
		return

	var edge_set := {}
	for face in _dodeca_faces:
		var idxs: Array = face
		if idxs.size() != 5:
			continue
		for i in range(5):
			var i0: int = int(idxs[i])
			var i1: int = int(idxs[(i + 1) % 5])
			_edge_add(edge_set, i0, i1)

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in edge_set.keys():
		var pair: Array = k.split(":")
		var i0: int = int(pair[0])
		var i1: int = int(pair[1])
		im.surface_add_vertex(_dodeca_verts[i0])
		im.surface_add_vertex(_dodeca_verts[i1])
	im.surface_end()

	edges.mesh = im
	edges.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.04, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = false
	edges.material_override = mat


func _edge_add(edge_set: Dictionary, i0: int, i1: int) -> void:
	var a := mini(i0, i1)
	var b := maxi(i0, i1)
	var key := "%d:%d" % [a, b]
	edge_set[key] = true


func _build_numbers() -> void:
	var labels_root: Node3D
	if body.has_node("Labels"):
		labels_root = body.get_node("Labels") as Node3D
		for c in labels_root.get_children():
			c.queue_free()
	else:
		labels_root = Node3D.new()
		labels_root.name = "Labels"
		body.add_child(labels_root)

	_face_normals.clear()
	# Use the pentagon faces we generated (clean, one label per face).
	for face_i in range(_dodeca_faces.size()):
		var idxs: Array = _dodeca_faces[face_i]
		if idxs.size() != 5:
			continue
		var value: int = face_i + 1

		var pts: Array[Vector3] = []
		for j in range(5):
			pts.append(_dodeca_verts[int(idxs[j])])

		var center: Vector3 = (pts[0] + pts[1] + pts[2] + pts[3] + pts[4]) / 5.0
		var normal: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
		if normal.dot(center) < 0.0:
			normal = -normal

		var face_node := Node3D.new()
		face_node.name = "Face_%d" % value
		face_node.position = center + normal * face_label_outset
		labels_root.add_child(face_node)

		var world_basis: Basis = body.global_transform.basis.orthonormalized()
		var world_normal: Vector3 = (world_basis * normal).normalized()
		var world_up: Vector3 = Vector3.UP - world_normal * Vector3.UP.dot(world_normal)
		if world_up.length() < 0.001:
			world_up = Vector3.RIGHT - world_normal * Vector3.RIGHT.dot(world_normal)
		world_up = world_up.normalized()
		face_node.look_at(face_node.global_position + world_normal, world_up)

		var label := Label3D.new()
		label.text = str(value)
		label.font_size = label_font_size
		label.pixel_size = label_pixel_size
		label.modulate = Color(0.1, 0.1, 0.1, 1.0)
		label.outline_modulate = Color(1, 1, 1, 1)
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.shaded = false
		if mirror_numbers:
			label.scale = Vector3(-1, 1, 1)
		label.position = Vector3(0, 0, -label_local_outset)
		face_node.add_child(label)

		var up_dir: Vector3 = face_node.basis.y.normalized()
		_face_normals.append({"value": value, "normal": normal, "up": up_dir})


func _get_face_for_value(value: int) -> Dictionary:
	for f in _face_normals:
		if int(f["value"]) == value:
			return {"normal": f["normal"], "up": f["up"]}
	return {"normal": Vector3.UP, "up": Vector3.UP}


func _compute_target_basis(desired_dir: Vector3, face_normal: Vector3, face_up: Vector3) -> Basis:
	var dir := desired_dir.normalized()
	var z_world := -dir

	var desired_up := Vector3.UP - dir * Vector3.UP.dot(dir)
	if desired_up.length() < 0.001:
		desired_up = Vector3.FORWARD - dir * Vector3.FORWARD.dot(dir)
	desired_up = desired_up.normalized()

	var x_world := desired_up.cross(z_world).normalized()
	var y_world := z_world.cross(x_world).normalized()
	var world_basis := Basis(x_world, y_world, z_world)

	var z_local := -face_normal.normalized()
	var y_local := face_up - z_local * face_up.dot(z_local)
	if y_local.length() < 0.001:
		y_local = Vector3.UP - z_local * Vector3.UP.dot(z_local)
	y_local = y_local.normalized()
	var x_local := y_local.cross(z_local).normalized()
	var local_basis := Basis(x_local, y_local, z_local)

	return world_basis * local_basis.inverse()


func _compute_safe_position(target_basis: Basis) -> Vector3:
	# Lift so lowest vertex is above floor y=0.
	var s: float = body.scale.x
	var min_y: float = INF
	for v: Vector3 in _dodeca_verts:
		var y: float = (target_basis * (v * s)).y
		min_y = min(min_y, y)

	var clearance: float = 0.02
	var pos: Vector3 = _rest_pos
	var needed: float = -min_y + clearance
	if needed > 0.0:
		pos.y += needed
	return pos


func _generate_dodecahedron() -> void:
	# Build dodecahedron as dual of an icosahedron.
	var phi: float = (1.0 + sqrt(5.0)) / 2.0

	var ico: Array[Vector3] = [
		Vector3(-1, phi, 0),
		Vector3(1, phi, 0),
		Vector3(-1, -phi, 0),
		Vector3(1, -phi, 0),
		Vector3(0, -1, phi),
		Vector3(0, 1, phi),
		Vector3(0, -1, -phi),
		Vector3(0, 1, -phi),
		Vector3(phi, 0, -1),
		Vector3(phi, 0, 1),
		Vector3(-phi, 0, -1),
		Vector3(-phi, 0, 1),
	]

	var ico_faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]

	# Dodecahedron vertices = normalized face centers of the icosahedron.
	_dodeca_verts.clear()
	for f: Array in ico_faces:
		var a: Vector3 = ico[int(f[0])]
		var b: Vector3 = ico[int(f[1])]
		var c: Vector3 = ico[int(f[2])]
		var center: Vector3 = (a + b + c) / 3.0
		_dodeca_verts.append(center.normalized())

	# For each icosahedron vertex, collect the 5 adjacent face-centers (indices into _dodeca_verts).
	_dodeca_faces.clear()
	for v_i in range(ico.size()):
		var incident: Array[int] = []
		for f_i in range(ico_faces.size()):
			var f: Array = ico_faces[f_i]
			if int(f[0]) == v_i or int(f[1]) == v_i or int(f[2]) == v_i:
				incident.append(f_i)

		# Sort around the icosa vertex so the pentagon is ordered.
		var n: Vector3 = ico[v_i].normalized()
		var u: Vector3 = Vector3.UP - n * Vector3.UP.dot(n)
		if u.length() < 0.001:
			u = Vector3.RIGHT - n * Vector3.RIGHT.dot(n)
		u = u.normalized()
		var v: Vector3 = n.cross(u).normalized()

		incident.sort_custom(func(a_i: int, b_i: int) -> bool:
			var pa: Vector3 = _dodeca_verts[a_i]
			var pb: Vector3 = _dodeca_verts[b_i]
			var pa_p: Vector3 = (pa - n * pa.dot(n)).normalized()
			var pb_p: Vector3 = (pb - n * pb.dot(n)).normalized()
			var aa: float = atan2(pa_p.dot(v), pa_p.dot(u))
			var ab: float = atan2(pb_p.dot(v), pb_p.dot(u))
			return aa < ab
		)

		# Each incident list is one pentagon face (5 vertices).
		# Reverse so normals point outward consistently from origin.
		var face: Array[int] = []
		for idx in incident:
			face.append(idx)
		_dodeca_faces.append(face)


