extends Node3D

signal rolled(value: int)

@export var roll_duration := 0.9
@export var lift_height := 0.35
@export var settle_duration := 0.18
@export var min_spins := 2
@export var max_spins := 4

var is_rolling := false
var _rng := RandomNumberGenerator.new()
var _face_normals: Array = []
var _target_value: int = 1
var _rest_pos: Vector3 = Vector3.ZERO

@onready var body: MeshInstance3D = $Body
@onready var _labels_root: Node3D = body.get_node_or_null("Labels") as Node3D


func _ready() -> void:
	_rng.randomize()
	_build_mesh()
	_build_numbers()
	rotation = Vector3.ZERO
	_rest_pos = position


func roll() -> void:
	if is_rolling:
		return

	_target_value = _rng.randi_range(1, 4)

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
	# Lift while spinning so it never intersects the floor.
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

	# Rotate so the chosen face points toward the camera (always readable).
	var face := _get_face_for_value(_target_value)
	var face_normal: Vector3 = face["normal"]
	var face_up: Vector3 = face["up"]
	var target_basis := _compute_target_basis(desired_dir, face_normal, face_up)
	var snap_rot := target_basis.get_euler()

	# Adjust vertical position so the tetrahedron never clips the floor after snapping.
	var safe_pos := _compute_safe_position(target_basis)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", snap_rot, settle_duration)
	tween.tween_property(self, "position", safe_pos, settle_duration)
	tween.tween_callback(Callable(self, "_emit_roll").bind(_target_value))


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

		# Push the text further out to avoid any clipping with the face.
		face_node.position = center + normal * 0.20
		labels_root.add_child(face_node)

		# Robust orientation: use look_at so we never end up with mirrored/left-handed transforms.
		var world_basis := body.global_transform.basis.orthonormalized()
		var world_normal: Vector3 = (world_basis * normal).normalized()
		var world_up := Vector3.UP - world_normal * Vector3.UP.dot(world_normal)
		if world_up.length() < 0.001:
			world_up = Vector3.RIGHT - world_normal * Vector3.RIGHT.dot(world_normal)
		world_up = world_up.normalized()
		face_node.look_at(face_node.global_position + world_normal, world_up)

		var label := Label3D.new()
		label.text = str(value)
		label.font_size = 110
		label.pixel_size = 0.009
		label.modulate = Color(0.1, 0.1, 0.1, 1.0)
		label.outline_modulate = Color(1, 1, 1, 1)
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		# Mirror the glyphs horizontally (requested for D4 faces).
		label.scale = Vector3(-1, 1, 1)
		label.position = Vector3(0, 0, -0.08) # slightly outward along local -Z
		face_node.add_child(label)

func _get_face_for_value(value: int) -> Dictionary:
	# Returns local-space face info: outward normal and "up" direction for the label on that face.
	if body == null:
		return {"normal": Vector3.UP, "up": Vector3.UP}

	var labels := body.get_node_or_null("Labels") as Node3D
	if labels == null:
		return {"normal": _get_normal_for_value_fallback(value), "up": Vector3.UP}

	var face_node := labels.get_node_or_null("Face_%d" % value) as Node3D
	if face_node == null:
		return {"normal": _get_normal_for_value_fallback(value), "up": Vector3.UP}

	# face_node local -Z points outward, so outward normal is (-basis.z).
	var outward: Vector3 = -face_node.basis.z.normalized()
	var up_dir: Vector3 = face_node.basis.y.normalized()
	return {"normal": outward, "up": up_dir}


func _get_normal_for_value_fallback(value: int) -> Vector3:
	for f in _face_normals:
		if int(f["value"]) == value:
			return f["normal"]
	return Vector3.UP


func _compute_target_basis(desired_dir: Vector3, face_normal: Vector3, face_up: Vector3) -> Basis:
	# Build a world-space basis where:
	# - chosen face points to camera (outward normal -> desired_dir)
	# - chosen face text is upright (face_up -> desired_up in the screen plane)
	#
	# Reminder: for Label3D, local -Z is "forward" (text faces -Z). Our face_node is built so -Z is outward.
	var z_world := -desired_dir.normalized()

	# Use camera-up-ish vector in the plane perpendicular to desired_dir to keep text upright.
	var desired_up := Vector3.UP - desired_dir * Vector3.UP.dot(desired_dir)
	if desired_up.length() < 0.001:
		desired_up = Vector3.RIGHT - desired_dir * Vector3.RIGHT.dot(desired_dir)
	desired_up = desired_up.normalized()

	var x_world := desired_up.cross(z_world).normalized()
	var y_world := z_world.cross(x_world).normalized()
	var world_basis := Basis(x_world, y_world, z_world)

	# Local basis for the face: x/y are in-plane, z points inward (because outward is -z).
	var z_local := -face_normal.normalized()
	var y_local := face_up - z_local * face_up.dot(z_local)
	if y_local.length() < 0.001:
		y_local = Vector3.UP - z_local * Vector3.UP.dot(z_local)
	y_local = y_local.normalized()
	var x_local := y_local.cross(z_local).normalized()
	var local_basis := Basis(x_local, y_local, z_local)

	return world_basis * local_basis.inverse()


func _compute_safe_position(target_basis: Basis) -> Vector3:
	# Ensure the tetrahedron is always above the floor (y=0) by lifting it so its lowest vertex is >= 0.
	# This keeps the visual clean even though we're not doing physics.
	var v0: Vector3 = Vector3(1, 1, 1)
	var v1: Vector3 = Vector3(-1, -1, 1)
	var v2: Vector3 = Vector3(-1, 1, -1)
	var v3: Vector3 = Vector3(1, -1, -1)

	var s: float = body.scale.x
	var verts: Array[Vector3] = [v0 * s, v1 * s, v2 * s, v3 * s]

	var min_y: float = INF
	for v: Vector3 in verts:
		var y: float = (target_basis * v).y
		min_y = min(min_y, y)

	var clearance: float = 0.02
	var pos: Vector3 = _rest_pos
	var needed: float = -min_y + clearance
	if needed > 0.0:
		pos.y += needed
	return pos


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
