extends Node3D

signal rolled(value: int)

const FACE_ROTATIONS := {
	1: Vector3(0.0, 0.0, 0.0),
	2: Vector3(deg_to_rad(90.0), 0.0, 0.0),
	3: Vector3(0.0, 0.0, deg_to_rad(90.0)),
	4: Vector3(0.0, 0.0, deg_to_rad(-90.0)),
	5: Vector3(deg_to_rad(-90.0), 0.0, 0.0),
	6: Vector3(deg_to_rad(180.0), 0.0, 0.0),
}

const FACE_DEFS := [
	{"path": NodePath("FaceUp_1"), "value": 1, "normal": Vector3.UP, "up": Vector3.FORWARD},
	{"path": NodePath("FaceDown_6"), "value": 6, "normal": Vector3.DOWN, "up": Vector3.FORWARD},
	{"path": NodePath("FaceFront_2"), "value": 2, "normal": Vector3.FORWARD, "up": Vector3.UP},
	{"path": NodePath("FaceBack_5"), "value": 5, "normal": Vector3.BACK, "up": Vector3.UP},
	{"path": NodePath("FaceRight_3"), "value": 3, "normal": Vector3.RIGHT, "up": Vector3.UP},
	{"path": NodePath("FaceLeft_4"), "value": 4, "normal": Vector3.LEFT, "up": Vector3.UP},
]

@export var roll_duration := 0.9
@export var snap_duration := 0.14
@export var min_spins := 2
@export var max_spins := 4
@export var count_face_user_sees := true

var is_rolling := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	rotation = FACE_ROTATIONS[1]
	_configure_face_labels()


func roll() -> void:
	if is_rolling:
		return

	# Keep labels configured (in case scene is reloaded/hot-changed).
	_configure_face_labels()

	var value: int = _rng.randi_range(1, 6)

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

	var target_rot := rotation + spins + wobble

	is_rolling = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# Big spin.
	tween.tween_property(self, "rotation", target_rot, roll_duration)

	# Small "impact" squish at the end.
	tween.tween_property(self, "scale", Vector3(1.08, 0.92, 1.08), 0.10).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)

	tween.tween_callback(Callable(self, "_finish_roll").bind(value))


func _finish_roll(value: int) -> void:
	# Normalize rotation to avoid it growing without bound after many rolls.
	rotation = Vector3(
		wrapf(rotation.x, -PI, PI),
		wrapf(rotation.y, -PI, PI),
		wrapf(rotation.z, -PI, PI)
	)

	# Snap to a stable orientation. If requested, orient the rolled face toward the camera
	# (so score matches the face the user sees).
	var snap_rot: Vector3
	if count_face_user_sees:
		snap_rot = _get_rotation_presenting_value_to_camera(value)
	else:
		snap_rot = FACE_ROTATIONS[value]
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", snap_rot, snap_duration)
	tween.tween_callback(Callable(self, "_emit_roll").bind(value))


func _get_top_value() -> int:
	var best_value := 1
	var best_dot := -INF
	for f in FACE_DEFS:
		var normal: Vector3 = f["normal"]
		var value: int = f["value"]
		var global_normal := global_transform.basis * normal
		var d := global_normal.dot(Vector3.UP)
		if d > best_dot:
			best_dot = d
			best_value = value
	return best_value


func _disable_label_billboarding() -> void:
	pass


func _configure_face_labels() -> void:
	# D6 labels are authored in `scenes/Dice.tscn` with correct position/rotation.
	# We only enforce render settings here (no transform changes).
	for f in FACE_DEFS:
		var label := get_node_or_null(f["path"]) as Label3D
		if label == null:
			continue
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.no_depth_test = false
		label.double_sided = false
		label.shaded = false


func _get_rotation_presenting_value_to_camera(value: int) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return FACE_ROTATIONS[value]

	var desired_dir: Vector3 = (cam.global_position - global_position).normalized()

	# Find face definition for the given value.
	var face_normal := Vector3.UP
	var face_up := Vector3.UP
	for f in FACE_DEFS:
		var v: int = f["value"]
		if v == value:
			face_normal = f["normal"]
			face_up = f["up"]
			break

	var target_basis := _compute_target_basis(desired_dir, face_normal, face_up)
	return target_basis.get_euler()


func _compute_target_basis(desired_dir: Vector3, face_normal: Vector3, face_up: Vector3) -> Basis:
	# Build a basis where the chosen face's outward normal points toward desired_dir,
	# while keeping the digit upright using a projected-up vector.
	var dir := desired_dir.normalized()
	var z_world := -dir

	var desired_up := Vector3.UP - dir * Vector3.UP.dot(dir)
	if desired_up.length() < 0.001:
		desired_up = Vector3.FORWARD - dir * Vector3.FORWARD.dot(dir)
	desired_up = desired_up.normalized()

	var x_world := desired_up.cross(z_world).normalized()
	var y_world := z_world.cross(x_world).normalized()
	var world_basis := Basis(x_world, y_world, z_world)

	# Local face basis: we want local -Z to be outward.
	var z_local := -face_normal.normalized()
	var y_local := face_up - z_local * face_up.dot(z_local)
	if y_local.length() < 0.001:
		y_local = Vector3.UP - z_local * Vector3.UP.dot(z_local)
	y_local = y_local.normalized()
	var x_local := y_local.cross(z_local).normalized()
	var local_basis := Basis(x_local, y_local, z_local)

	return world_basis * local_basis.inverse()


func _emit_roll(value: int) -> void:
	is_rolling = false
	rolled.emit(value)
