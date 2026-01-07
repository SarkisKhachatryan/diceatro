extends SceneTree

# Minimal headless test runner (no addons).
# Run (example):
#   godot --headless --script res://tests/run_tests.gd

var _failures: int = 0
var _assertions: int = 0


func _initialize() -> void:
	# Defer so the SceneTree is fully initialized.
	call_deferred("_run_all")


func _fail(msg: String) -> void:
	_failures += 1
	push_error(msg)


func _assert_true(cond: bool, msg: String) -> void:
	_assertions += 1
	if not cond:
		_fail(msg)


func _assert_eq_int(a: int, b: int, msg: String) -> void:
	_assertions += 1
	if a != b:
		_fail("%s (expected %d, got %d)" % [msg, b, a])


func _assert_gt(a: float, b: float, msg: String) -> void:
	_assertions += 1
	if not (a > b):
		_fail("%s (expected > %f, got %f)" % [msg, b, a])


func _run_all() -> void:
	# Ensure a viewport exists.
	await process_frame

	await _test_d6_camera_facing_value()
	await _test_d4_target_basis_points_face_to_camera()
	await _test_d4_safe_position_above_floor()
	await _test_d8_target_basis_points_face_to_camera()
	await _test_d8_safe_position_above_floor()

	var summary := "Tests: %d assertions, %d failures" % [_assertions, _failures]
	if _failures == 0:
		print(summary)
		# Give queued frees a couple frames to complete to avoid leak warnings at exit.
		await process_frame
		await process_frame
		quit(0)
	else:
		printerr(summary)
		await process_frame
		await process_frame
		quit(1)


func _setup_camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.name = "TestCamera"
	cam.position = Vector3(0, 2.2, 4.2)
	root.add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	return cam


func _test_d6_camera_facing_value() -> void:
	var cam := _setup_camera()
	var dice_scene: PackedScene = load("res://scenes/Dice.tscn")
	var dice := dice_scene.instantiate()
	root.add_child(dice)

	# Make sure camera-facing mode is enabled (default true).
	dice.count_face_user_sees = true

	# Put dice at origin for stable vectors.
	dice.global_position = Vector3.ZERO

	for value in range(1, 7):
		var rot: Vector3 = dice._get_rotation_presenting_value_to_camera(value)
		dice.rotation = rot

		var desired_dir: Vector3 = (cam.global_position - dice.global_position).normalized()
		var best_value: int = -1
		var best_dot: float = -INF
		for f in dice.FACE_DEFS:
			var v: int = f["value"]
			var n: Vector3 = f["normal"]
			var world_n: Vector3 = (dice.global_transform.basis * n).normalized()
			var d: float = world_n.dot(desired_dir)
			if d > best_dot:
				best_dot = d
				best_value = v

		_assert_eq_int(best_value, value, "D6 should present face %d toward camera" % value)
		_assert_gt(best_dot, 0.92, "D6 presented face should strongly face camera")

	dice.queue_free()
	cam.queue_free()
	dice = null
	cam = null
	dice_scene = null
	await process_frame
	await process_frame


func _test_d4_target_basis_points_face_to_camera() -> void:
	var cam := _setup_camera()
	var d4_scene: PackedScene = load("res://scenes/D4.tscn")
	var d4 := d4_scene.instantiate()
	root.add_child(d4)

	# Ensure ready ran so labels exist.
	await process_frame

	d4.global_position = Vector3.ZERO
	var desired_dir: Vector3 = (cam.global_position - d4.global_position).normalized()

	for value in range(1, 5):
		var face: Dictionary = d4._get_face_for_value(value)
		var face_normal: Vector3 = face["normal"]
		var face_up: Vector3 = face["up"]
		var basis: Basis = d4._compute_target_basis(desired_dir, face_normal, face_up)
		var world_n: Vector3 = (basis * face_normal).normalized()
		var dot: float = world_n.dot(desired_dir)
		_assert_gt(dot, 0.92, "D4 face %d should point toward camera" % value)

	d4.queue_free()
	cam.queue_free()
	d4 = null
	cam = null
	d4_scene = null
	await process_frame
	await process_frame


func _test_d4_safe_position_above_floor() -> void:
	var cam := _setup_camera()
	var d4_scene: PackedScene = load("res://scenes/D4.tscn")
	var d4 := d4_scene.instantiate()
	root.add_child(d4)
	await process_frame

	d4.global_position = Vector3.ZERO
	var desired_dir: Vector3 = (cam.global_position - d4.global_position).normalized()
	var face: Dictionary = d4._get_face_for_value(1)
	var basis: Basis = d4._compute_target_basis(desired_dir, face["normal"], face["up"])
	var pos: Vector3 = d4._compute_safe_position(basis)

	_assert_gt(pos.y, -0.0001, "D4 safe position should not go below floor")

	d4.queue_free()
	cam.queue_free()
	d4 = null
	cam = null
	d4_scene = null
	await process_frame
	await process_frame


func _test_d8_target_basis_points_face_to_camera() -> void:
	var cam := _setup_camera()
	var d8_scene: PackedScene = load("res://scenes/D8.tscn")
	var d8 := d8_scene.instantiate()
	root.add_child(d8)
	await process_frame

	d8.global_position = Vector3.ZERO
	var desired_dir: Vector3 = (cam.global_position - d8.global_position).normalized()

	for value in range(1, 9):
		var face: Dictionary = d8._get_face_for_value(value)
		var face_normal: Vector3 = face["normal"]
		var face_up: Vector3 = face["up"]
		var basis: Basis = d8._compute_target_basis(desired_dir, face_normal, face_up)
		var world_n: Vector3 = (basis * face_normal).normalized()
		var dot: float = world_n.dot(desired_dir)
		_assert_gt(dot, 0.92, "D8 face %d should point toward camera" % value)

	d8.queue_free()
	cam.queue_free()
	d8 = null
	cam = null
	d8_scene = null
	await process_frame
	await process_frame


func _test_d8_safe_position_above_floor() -> void:
	var cam := _setup_camera()
	var d8_scene: PackedScene = load("res://scenes/D8.tscn")
	var d8 := d8_scene.instantiate()
	root.add_child(d8)
	await process_frame

	d8.global_position = Vector3.ZERO
	var desired_dir: Vector3 = (cam.global_position - d8.global_position).normalized()
	var face: Dictionary = d8._get_face_for_value(1)
	var basis: Basis = d8._compute_target_basis(desired_dir, face["normal"], face["up"])
	var pos: Vector3 = d8._compute_safe_position(basis)
	_assert_gt(pos.y, -0.0001, "D8 safe position should not go below floor")

	d8.queue_free()
	cam.queue_free()
	d8 = null
	cam = null
	d8_scene = null
	await process_frame
	await process_frame
