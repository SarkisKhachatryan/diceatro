extends Node3D

signal rolled(value: int)

@export var roll_duration := 0.9
@export var min_spins := 2
@export var max_spins := 4

var is_rolling := false
var _rng := RandomNumberGenerator.new()
var _face_normals: Array = []

@onready var body: MeshInstance3D = $Body


func _ready() -> void:
	_rng.randomize()
	_build_mesh()
	_build_numbers()
	rotation = Vector3.ZERO


func roll() -> void:
	if is_rolling:
		return

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
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", rotation + spins + wobble, roll_duration)
	tween.tween_property(self, "scale", Vector3(1.07, 0.93, 1.07), 0.10).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(self, "_finish_roll"))


func _finish_roll() -> void:
	rotation = Vector3(
		wrapf(rotation.x, -PI, PI),
		wrapf(rotation.y, -PI, PI),
		wrapf(rotation.z, -PI, PI)
	)
	# D4 best-practice: read the value from the FACE ON THE TABLE (bottom face),
	# because a tetrahedron doesn't "land flat with a face on top" like a cube.
	var pick := _get_bottom_pick()
	var value: int = pick["value"]
	var normal: Vector3 = pick["normal"]

	# Snap so the chosen face becomes the bottom (stable resting pose).
	var q := _rotation_from_to(normal, Vector3.DOWN)
	var snap_rot := q.get_euler()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", snap_rot, 0.16)
	tween.tween_callback(Callable(self, "_emit_roll").bind(value))


func _build_mesh() -> void:
	# Regular tetrahedron centered at origin.
	var v0 := Vector3(1, 1, 1)
	var v1 := Vector3(-1, -1, 1)
	var v2 := Vector3(-1, 1, -1)
	var v3 := Vector3(1, -1, -1)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_tri(st, v1, v2, v3)
	_add_tri(st, v0, v3, v2)
	_add_tri(st, v0, v1, v3)
	_add_tri(st, v0, v2, v1)

	st.generate_normals()
	var mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.95, 1.0)
	mat.roughness = 0.45
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mesh.surface_set_material(0, mat)

	body.mesh = mesh
	body.scale = Vector3.ONE * 0.62


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _build_numbers() -> void:
	# Remove previous labels if scene is reloaded.
	var labels_root: Node3D
	if body.has_node("Labels"):
		labels_root = body.get_node("Labels") as Node3D
		for c in labels_root.get_children():
			c.queue_free()
	else:
		labels_root = Node3D.new()
		labels_root.name = "Labels"
		body.add_child(labels_root)

	# Same vertices as mesh generation (scaled by Body in render).
	var v0 := Vector3(1, 1, 1)
	var v1 := Vector3(-1, -1, 1)
	var v2 := Vector3(-1, 1, -1)
	var v3 := Vector3(1, -1, -1)

	var faces := [
		{"value": 1, "a": v1, "b": v2, "c": v3},
		{"value": 2, "a": v0, "b": v3, "c": v2},
		{"value": 3, "a": v0, "b": v1, "c": v3},
		{"value": 4, "a": v0, "b": v2, "c": v1},
	]

	_face_normals.clear()

	for f in faces:
		var a: Vector3 = f["a"]
		var b: Vector3 = f["b"]
		var c: Vector3 = f["c"]
		var value: int = f["value"]

		var center := (a + b + c) / 3.0
		var normal := (b - a).cross(c - a).normalized()
		# Ensure outward normals (pointing away from origin).
		if normal.dot(center) < 0.0:
			normal = -normal
		_face_normals.append({"value": value, "normal": normal})

		# Create a face node whose local -Z points outward (so Label3D faces outward).
		var face_node := Node3D.new()
		face_node.name = "Face_%d" % value

		var z_axis := -normal
		var x_axis := Vector3.UP.cross(z_axis)
		if x_axis.length() < 0.001:
			x_axis = Vector3.RIGHT.cross(z_axis)
		x_axis = x_axis.normalized()
		var y_axis := z_axis.cross(x_axis).normalized()

		face_node.basis = Basis(x_axis, y_axis, z_axis)
		face_node.position = center + normal * 0.12
		labels_root.add_child(face_node)

		var label := Label3D.new()
		label.text = str(value)
		label.font_size = 110
		label.pixel_size = 0.009
		label.modulate = Color(0.1, 0.1, 0.1, 1.0)
		label.outline_modulate = Color(1, 1, 1, 1)
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.position = Vector3(0, 0, -0.02) # slightly outward along local -Z
		face_node.add_child(label)

func _get_bottom_pick() -> Dictionary:
	var best_value := 1
	var best_dot := INF
	var best_normal := Vector3.DOWN
	for f in _face_normals:
		var normal: Vector3 = f["normal"]
		var value: int = f["value"]
		# normals are in local space of this Node3D (Body has no extra rotation).
		var global_normal := global_transform.basis * normal
		var d := global_normal.dot(Vector3.UP) # lower means more DOWN
		if d < best_dot:
			best_dot = d
			best_value = value
			best_normal = normal
	return {"value": best_value, "normal": best_normal}


func _rotation_from_to(from_dir: Vector3, to_dir: Vector3) -> Quaternion:
	var f: Vector3 = from_dir.normalized()
	var t: Vector3 = to_dir.normalized()
	var dot: float = clampf(f.dot(t), -1.0, 1.0)

	if dot > 0.9999:
		return Quaternion()
	if dot < -0.9999:
		var axis: Vector3 = f.cross(Vector3.RIGHT)
		if axis.length() < 0.001:
			axis = f.cross(Vector3.FORWARD)
		return Quaternion(axis.normalized(), PI)

	var axis: Vector3 = f.cross(t)
	var angle: float = acos(dot)
	return Quaternion(axis.normalized(), angle)


func _emit_roll(value: int) -> void:
	is_rolling = false
	rolled.emit(value)
