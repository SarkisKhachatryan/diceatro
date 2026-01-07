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

var is_rolling := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_disable_label_billboarding()
	rotation = FACE_ROTATIONS[1]


func roll() -> void:
	if is_rolling:
		return

	_disable_label_billboarding()

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

	tween.tween_callback(Callable(self, "_finish_roll"))


func _finish_roll() -> void:
	# Normalize rotation to avoid it growing without bound after many rolls.
	rotation = Vector3(
		wrapf(rotation.x, -PI, PI),
		wrapf(rotation.y, -PI, PI),
		wrapf(rotation.z, -PI, PI)
	)
	var value := _get_top_value()

	# Snap to a stable "face-flat" orientation so it's never left balancing on an edge.
	var snap_rot: Vector3 = FACE_ROTATIONS[value]
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
	# Ensure numbers are "printed" on the faces (not always facing the camera).
	for f in FACE_DEFS:
		var label := get_node_or_null(f["path"]) as Label3D
		if label == null:
			continue
		# Label3D uses the same billboard modes as BaseMaterial3D.
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.no_depth_test = false
		label.double_sided = false


func _emit_roll(value: int) -> void:
	is_rolling = false
	rolled.emit(value)


