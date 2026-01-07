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


func _assert_eq_str(a: String, b: String, msg: String) -> void:
	_assertions += 1
	if a != b:
		_fail('%s (expected "%s", got "%s")' % [msg, b, a])


func _assert_gt(a: float, b: float, msg: String) -> void:
	_assertions += 1
	if not (a > b):
		_fail("%s (expected > %f, got %f)" % [msg, b, a])

func _assert_near(a: float, b: float, eps: float, msg: String) -> void:
	_assertions += 1
	if abs(a - b) > eps:
		_fail("%s (expected %f±%f, got %f)" % [msg, b, eps, a])


func _run_all() -> void:
	# Ensure a viewport exists.
	await process_frame

	await _test_d6_camera_facing_value()
	await _test_d4_target_basis_points_face_to_camera()
	await _test_d4_safe_position_above_floor()
	await _test_d8_target_basis_points_face_to_camera()
	await _test_d8_safe_position_above_floor()
	await _test_surface_label_offsets()
	await _test_d10_target_basis_points_face_to_camera()
	await _test_d10_safe_position_above_floor()
	await _test_d12_target_basis_points_face_to_camera()
	await _test_d12_safe_position_above_floor()
	await _test_d20_target_basis_points_face_to_camera()
	await _test_d20_safe_position_above_floor()
	await _test_main_camera_defaults()
	await _test_d20_defaults()
	await _test_game_pattern_detection()

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


func _test_surface_label_offsets() -> void:
	# D6 labels are authored in the scene. Ensure they're close to the cube surface.
	var dice_scene: PackedScene = load("res://scenes/Dice.tscn")
	var dice := dice_scene.instantiate()
	root.add_child(dice)
	await process_frame

	var nodes := [
		dice.get_node("FaceUp_1"),
		dice.get_node("FaceDown_6"),
		dice.get_node("FaceFront_2"),
		dice.get_node("FaceBack_5"),
		dice.get_node("FaceRight_3"),
		dice.get_node("FaceLeft_4"),
	]

	for n in nodes:
		var l := n as Label3D
		_assert_true(l != null, "D6 label node should exist")
		var dist := l.position.length()
		_assert_near(dist, 0.501, 0.01, "D6 label should be very close to surface")

	dice.queue_free()
	dice = null
	dice_scene = null
	await process_frame
	await process_frame

	# D4/D8 use exported offsets. Verify defaults are the "printed" ones.
	var d4_scene: PackedScene = load("res://scenes/D4.tscn")
	var d4 := d4_scene.instantiate()
	root.add_child(d4)
	await process_frame
	_assert_near(float(d4.face_label_outset), 0.03, 0.0001, "D4 face_label_outset default")
	_assert_near(float(d4.label_local_outset), 0.012, 0.0001, "D4 label_local_outset default")
	d4.queue_free()
	d4 = null
	d4_scene = null
	await process_frame
	await process_frame

	var d8_scene: PackedScene = load("res://scenes/D8.tscn")
	var d8 := d8_scene.instantiate()
	root.add_child(d8)
	await process_frame
	_assert_near(float(d8.face_label_outset), 0.03, 0.0001, "D8 face_label_outset default")
	_assert_near(float(d8.label_local_outset), 0.012, 0.0001, "D8 label_local_outset default")
	d8.queue_free()
	d8 = null
	d8_scene = null
	await process_frame
	await process_frame

	var d10_scene: PackedScene = load("res://scenes/D10.tscn")
	var d10 := d10_scene.instantiate()
	root.add_child(d10)
	await process_frame
	_assert_near(float(d10.face_label_outset), 0.03, 0.0001, "D10 face_label_outset default")
	_assert_near(float(d10.label_local_outset), 0.012, 0.0001, "D10 label_local_outset default")
	d10.queue_free()
	d10 = null
	d10_scene = null
	await process_frame
	await process_frame

	var d12_scene: PackedScene = load("res://scenes/D12.tscn")
	var d12 := d12_scene.instantiate()
	root.add_child(d12)
	await process_frame
	_assert_near(float(d12.face_label_outset), 0.03, 0.0001, "D12 face_label_outset default")
	_assert_near(float(d12.label_local_outset), 0.012, 0.0001, "D12 label_local_outset default")
	d12.queue_free()
	d12 = null
	d12_scene = null
	await process_frame
	await process_frame

	var d20_scene: PackedScene = load("res://scenes/D20.tscn")
	var d20 := d20_scene.instantiate()
	root.add_child(d20)
	await process_frame
	_assert_near(float(d20.face_label_outset), 0.03, 0.0001, "D20 face_label_outset default")
	_assert_near(float(d20.label_local_outset), 0.012, 0.0001, "D20 label_local_outset default")
	d20.queue_free()
	d20 = null
	d20_scene = null
	await process_frame
	await process_frame


func _test_d10_target_basis_points_face_to_camera() -> void:
	var cam := _setup_camera()
	var d10_scene: PackedScene = load("res://scenes/D10.tscn")
	var d10 := d10_scene.instantiate()
	root.add_child(d10)
	await process_frame

	d10.global_position = Vector3.ZERO
	var desired_dir: Vector3 = (cam.global_position - d10.global_position).normalized()

	for value in range(1, 11):
		var face: Dictionary = d10._get_face_for_value(value)
		var face_normal: Vector3 = face["normal"]
		var face_up: Vector3 = face["up"]
		var basis: Basis = d10._compute_target_basis(desired_dir, face_normal, face_up)
		var world_n: Vector3 = (basis * face_normal).normalized()
		var dot: float = world_n.dot(desired_dir)
		_assert_gt(dot, 0.92, "D10 face %d should point toward camera" % value)

	d10.queue_free()
	cam.queue_free()
	d10 = null
	cam = null
	d10_scene = null
	await process_frame
	await process_frame


func _test_d10_safe_position_above_floor() -> void:
	var cam := _setup_camera()
	var d10_scene: PackedScene = load("res://scenes/D10.tscn")
	var d10 := d10_scene.instantiate()
	root.add_child(d10)
	await process_frame

	d10.global_position = Vector3.ZERO
	var desired_dir: Vector3 = (cam.global_position - d10.global_position).normalized()
	var face: Dictionary = d10._get_face_for_value(1)
	var basis: Basis = d10._compute_target_basis(desired_dir, face["normal"], face["up"])
	var pos: Vector3 = d10._compute_safe_position(basis)
	_assert_gt(pos.y, -0.0001, "D10 safe position should not go below floor")

	d10.queue_free()
	cam.queue_free()
	d10 = null
	cam = null
	d10_scene = null
	await process_frame
	await process_frame


func _test_d12_target_basis_points_face_to_camera() -> void:
	var cam := _setup_camera()
	var d12_scene: PackedScene = load("res://scenes/D12.tscn")
	var d12 := d12_scene.instantiate()
	root.add_child(d12)
	await process_frame

	d12.global_position = Vector3.ZERO
	var desired_dir: Vector3 = (cam.global_position - d12.global_position).normalized()

	for value in range(1, 13):
		var face: Dictionary = d12._get_face_for_value(value)
		var face_normal: Vector3 = face["normal"]
		var face_up: Vector3 = face["up"]
		var basis: Basis = d12._compute_target_basis(desired_dir, face_normal, face_up)
		var world_n: Vector3 = (basis * face_normal).normalized()
		var dot: float = world_n.dot(desired_dir)
		_assert_gt(dot, 0.92, "D12 face %d should point toward camera" % value)

	d12.queue_free()
	cam.queue_free()
	d12 = null
	cam = null
	d12_scene = null
	await process_frame
	await process_frame


func _test_d12_safe_position_above_floor() -> void:
	var cam := _setup_camera()
	var d12_scene: PackedScene = load("res://scenes/D12.tscn")
	var d12 := d12_scene.instantiate()
	root.add_child(d12)
	await process_frame

	d12.global_position = Vector3.ZERO
	var desired_dir: Vector3 = (cam.global_position - d12.global_position).normalized()
	var face: Dictionary = d12._get_face_for_value(1)
	var basis: Basis = d12._compute_target_basis(desired_dir, face["normal"], face["up"])
	var pos: Vector3 = d12._compute_safe_position(basis)
	_assert_gt(pos.y, -0.0001, "D12 safe position should not go below floor")

	d12.queue_free()
	cam.queue_free()
	d12 = null
	cam = null
	d12_scene = null
	await process_frame
	await process_frame


func _test_d20_target_basis_points_face_to_camera() -> void:
	var cam := _setup_camera()
	var d20_scene: PackedScene = load("res://scenes/D20.tscn")
	var d20 := d20_scene.instantiate()
	root.add_child(d20)
	await process_frame

	d20.global_position = Vector3.ZERO
	var desired_dir: Vector3 = (cam.global_position - d20.global_position).normalized()

	for value in range(1, 21):
		var face: Dictionary = d20._get_face_for_value(value)
		var face_normal: Vector3 = face["normal"]
		var face_up: Vector3 = face["up"]
		var basis: Basis = d20._compute_target_basis(desired_dir, face_normal, face_up)
		var world_n: Vector3 = (basis * face_normal).normalized()
		var dot: float = world_n.dot(desired_dir)
		_assert_gt(dot, 0.92, "D20 face %d should point toward camera" % value)

	d20.queue_free()
	cam.queue_free()
	d20 = null
	cam = null
	d20_scene = null
	await process_frame
	await process_frame


func _test_d20_safe_position_above_floor() -> void:
	var cam := _setup_camera()
	var d20_scene: PackedScene = load("res://scenes/D20.tscn")
	var d20 := d20_scene.instantiate()
	root.add_child(d20)
	await process_frame

	d20.global_position = Vector3.ZERO
	var desired_dir: Vector3 = (cam.global_position - d20.global_position).normalized()
	var face: Dictionary = d20._get_face_for_value(1)
	var basis: Basis = d20._compute_target_basis(desired_dir, face["normal"], face["up"])
	var pos: Vector3 = d20._compute_safe_position(basis)
	_assert_gt(pos.y, -0.0001, "D20 safe position should not go below floor")

	d20.queue_free()
	cam.queue_free()
	d20 = null
	cam = null
	d20_scene = null
	await process_frame
	await process_frame


func _test_main_camera_defaults() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var cam := main.get_node_or_null("Camera3D") as Camera3D
	_assert_true(cam != null, "Main.tscn should have Camera3D")
	if cam != null:
		_assert_near(cam.position.x, 0.0, 0.0001, "Camera x position")
		_assert_near(cam.position.y, 3.0, 0.001, "Camera y position")
		_assert_near(cam.position.z, 6.4, 0.001, "Camera z position")
		_assert_near(cam.rotation.x, -0.46, 0.01, "Camera tilt")

	main.queue_free()
	main = null
	main_scene = null
	await process_frame
	await process_frame


func _test_d20_defaults() -> void:
	var d20_scene: PackedScene = load("res://scenes/D20.tscn")
	var d20 := d20_scene.instantiate()
	root.add_child(d20)
	await process_frame

	_assert_near(float(d20.body_scale), 0.68, 0.0001, "D20 body_scale default")

	d20.queue_free()
	d20 = null
	d20_scene = null
	await process_frame
	await process_frame


func _test_game_pattern_detection() -> void:
	# Pattern detection is pure logic (no scene tree required).
	var game_script: Script = load("res://scripts/Game.gd")
	var game_obj: Object = game_script.new()
	var describe := func(rolls: Array[int]) -> String:
		return String(game_obj.call("_describe_patterns", rolls))

	# 5 dice patterns
	var five_kind: Array[int] = [2, 2, 2, 2, 2]
	_assert_eq_str(describe.call(five_kind), "Five of a kind", "Detect five of a kind")

	var four_kind: Array[int] = [3, 3, 3, 3, 5]
	_assert_eq_str(describe.call(four_kind), "Four of a kind", "Detect four of a kind")

	var full_house: Array[int] = [4, 4, 4, 2, 2]
	_assert_eq_str(describe.call(full_house), "Full house", "Detect full house")

	var three_kind: Array[int] = [1, 1, 1, 3, 5]
	_assert_eq_str(describe.call(three_kind), "Three of a kind", "Detect three of a kind")

	var two_pair: Array[int] = [6, 6, 2, 2, 5]
	_assert_eq_str(describe.call(two_pair), "Two pair", "Detect two pair")

	var pair: Array[int] = [4, 4, 1, 3, 6]
	_assert_eq_str(describe.call(pair), "Pair", "Detect pair")

	# Straights (new rules): 3/4/5-length
	var large_straight: Array[int] = [2, 3, 4, 5, 6]
	_assert_eq_str(describe.call(large_straight), "Large straight", "Detect large straight (len 5)")

	var straight: Array[int] = [1, 2, 3, 4, 6]
	_assert_eq_str(describe.call(straight), "Straight", "Detect straight (len 4)")

	var small_straight: Array[int] = [1, 2, 3, 6, 6]
	_assert_eq_str(describe.call(small_straight), "Small straight", "Detect small straight (len 3)")

	# Parity patterns (tested on 3 dice so they can win precedence).
	var all_even: Array[int] = [2, 4, 6]
	_assert_eq_str(describe.call(all_even), "All even", "Detect all even")

	var all_odd: Array[int] = [1, 3, 5]
	_assert_eq_str(describe.call(all_odd), "All odd", "Detect all odd")

	# High die (use 2 dice to avoid 3-run / duplicates precedence).
	var high_die: Array[int] = [1, 6]
	_assert_eq_str(describe.call(high_die), "High die", "Detect high die")

	# Exhaustive sweep (D6): validate classification for 1..5 dice across all permutations.
	var label_counts: Dictionary = {}
	for n: int in range(1, 6):
		var prefix: Array[int] = []
		_walk_rolls_and_assert(n, prefix, describe, label_counts)

	# Coverage sanity: each label should appear at least once across the sweep.
	var expected_labels: Array[String] = [
		"High die",
		"Pair",
		"Two pair",
		"Three of a kind",
		"Full house",
		"Four of a kind",
		"Five of a kind",
		"Small straight",
		"Straight",
		"Large straight",
		"All even",
		"All odd",
	]
	for lbl: String in expected_labels:
		_assert_true(label_counts.has(lbl), "Pattern label should appear in exhaustive sweep: %s" % lbl)

	# Avoid leak warnings at exit.
	game_obj.free()
	game_obj = null
	game_script = null


func _walk_rolls_and_assert(n: int, prefix: Array[int], describe: Callable, label_counts: Dictionary) -> void:
	if prefix.size() == n:
		var rolls: Array[int] = prefix.duplicate()
		var got: String = String(describe.call(rolls))
		var exp: String = _expected_game_pattern(rolls)
		_assert_eq_str(got, exp, "Pattern mismatch for rolls=%s" % [rolls])
		label_counts[got] = int(label_counts.get(got, 0)) + 1
		return

	for v: int in range(1, 7):
		prefix.append(v)
		_walk_rolls_and_assert(n, prefix, describe, label_counts)
		prefix.pop_back()


func _expected_game_pattern(rolls: Array[int]) -> String:
	if rolls.is_empty():
		return "High die"

	var n: int = rolls.size()

	# Frequency (ignores order).
	var freq: Dictionary = {}
	for v: int in rolls:
		freq[v] = int(freq.get(v, 0)) + 1

	var num_unique: int = freq.size()
	var max_count: int = 0
	var pair_count: int = 0
	for k in freq.keys():
		var c: int = int(freq[k])
		max_count = maxi(max_count, c)
		if c == 2:
			pair_count += 1

	# Unique sorted (for straights).
	var unique_sorted: Array[int] = []
	for k in freq.keys():
		unique_sorted.append(int(k))
	unique_sorted.sort()

	# Kind-based patterns (only meaningful for 5 dice in our current ruleset).
	if n == 5 and num_unique == 1:
		return "Five of a kind"
	if n == 5 and num_unique == 2 and max_count == 4:
		return "Four of a kind"
	if n == 5 and num_unique == 2 and max_count == 3:
		return "Full house"

	# Straights (new rules): 3/4/5-length run.
	if _expected_has_run(unique_sorted, 5):
		return "Large straight"
	if _expected_has_run(unique_sorted, 4):
		return "Straight"
	if _expected_has_run(unique_sorted, 3):
		return "Small straight"

	# Remaining kind-based patterns (5 dice).
	if n == 5 and max_count == 3:
		return "Three of a kind"
	if n == 5 and pair_count == 2:
		return "Two pair"
	if n == 5 and pair_count == 1:
		return "Pair"

	# Parity patterns (only if nothing higher matched).
	var all_even: bool = true
	var all_odd: bool = true
	for v: int in rolls:
		if (v % 2) == 0:
			all_odd = false
		else:
			all_even = false
	if all_even:
		return "All even"
	if all_odd:
		return "All odd"

	return "High die"


func _expected_has_run(unique_sorted: Array[int], run_len: int) -> bool:
	if run_len <= 1:
		return true
	if unique_sorted.size() < run_len:
		return false
	for i: int in range(0, unique_sorted.size() - (run_len - 1)):
		if unique_sorted[i + (run_len - 1)] - unique_sorted[i] == (run_len - 1):
			return true
	return false
