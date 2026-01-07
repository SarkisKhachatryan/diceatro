extends Node3D

signal rolled(value: int)

const FACE_DEFS := [
	{"path": NodePath("FaceUp_1"), "value": 1, "normal": Vector3.UP, "up": Vector3.FORWARD},
	{"path": NodePath("FaceDown_6"), "value": 6, "normal": Vector3.DOWN, "up": Vector3.FORWARD},
	{"path": NodePath("FaceFront_2"), "value": 2, "normal": Vector3.FORWARD, "up": Vector3.UP},
	{"path": NodePath("FaceBack_5"), "value": 5, "normal": Vector3.BACK, "up": Vector3.UP},
	{"path": NodePath("FaceRight_3"), "value": 3, "normal": Vector3.RIGHT, "up": Vector3.UP},
	{"path": NodePath("FaceLeft_4"), "value": 4, "normal": Vector3.LEFT, "up": Vector3.UP},
]

@export var roll_duration := 0.9
@export var min_spins := 2
@export var max_spins := 4

var is_rolling := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_setup_face_labels()


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
	is_rolling = false
	var value := _get_top_value()
	rolled.emit(value)


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


func _setup_face_labels() -> void:
	# Force labels to sit flush on the cube faces and be upright (no mirrored/sideways planes).
	for f in FACE_DEFS:
		var label := get_node_or_null(f["path"]) as Label3D
		if label == null:
			continue

		var normal: Vector3 = f["normal"]
		var up_hint: Vector3 = f["up"]
		var value: int = f["value"]

		label.text = str(value)
		label.position = normal * 0.53
		label.basis = Basis.IDENTITY

		var g_normal := global_transform.basis * normal
		var g_up := global_transform.basis * up_hint
		if abs(g_up.normalized().dot(g_normal.normalized())) > 0.98:
			g_up = global_transform.basis * Vector3.RIGHT

		label.look_at(label.global_position + g_normal, g_up)
		# Nudge outward a bit to avoid z-fighting with the cube.
		label.translate_object_local(Vector3(0, 0, -0.02))


