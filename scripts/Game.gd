extends Control

@onready var back_button: Button = $Margin/VBox/BackButton
@onready var dice_type: OptionButton = $Margin/VBox/Controls/DiceType
@onready var dice_count: OptionButton = $Margin/VBox/Controls/DiceCount
@onready var roll_button: Button = $Margin/VBox/Controls/RollButton
@onready var viewport: SubViewport = $Margin/VBox/ViewportContainer/Viewport
@onready var dice_root: Node3D = $Margin/VBox/ViewportContainer/Viewport/World/DiceRoot
@onready var floor: MeshInstance3D = $Margin/VBox/ViewportContainer/Viewport/World/Floor
@onready var pattern_label: Label = $Margin/VBox/PatternLabel
@onready var summary: Label = $Margin/VBox/BottomRow/Summary
@onready var die_1: Label = $Margin/VBox/BottomRow/RollsRowCenter/RollsRow/Die1
@onready var die_2: Label = $Margin/VBox/BottomRow/RollsRowCenter/RollsRow/Die2
@onready var die_3: Label = $Margin/VBox/BottomRow/RollsRowCenter/RollsRow/Die3
@onready var die_4: Label = $Margin/VBox/BottomRow/RollsRowCenter/RollsRow/Die4
@onready var die_5: Label = $Margin/VBox/BottomRow/RollsRowCenter/RollsRow/Die5

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _is_rolling: bool = false
var _dice_nodes: Array[Node] = []
var _die_labels: Array[Label] = []

const D4_SCENE: PackedScene = preload("res://scenes/D4.tscn")
const D6_SCENE: PackedScene = preload("res://scenes/Dice.tscn")
const D8_SCENE: PackedScene = preload("res://scenes/D8.tscn")
const D10_SCENE: PackedScene = preload("res://scenes/D10.tscn")
const D12_SCENE: PackedScene = preload("res://scenes/D12.tscn")
const D20_SCENE: PackedScene = preload("res://scenes/D20.tscn")


func _ready() -> void:
	_rng.randomize()
	back_button.pressed.connect(_go_back)
	roll_button.pressed.connect(_roll_many)
	_setup_options()
	_setup_floor()
	_die_labels = [die_1, die_2, die_3, die_4, die_5]
	_reset_ui()
	_respawn_dice()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _setup_options() -> void:
	dice_type.clear()
	dice_type.add_item("D4", 4)
	dice_type.add_item("D6", 6)
	dice_type.add_item("D8", 8)
	dice_type.add_item("D10", 10)
	dice_type.add_item("D12", 12)
	dice_type.add_item("D20", 20)
	dice_type.selected = 1 # D6 default

	dice_count.clear()
	for i in range(1, 6):
		dice_count.add_item(str(i), i)
	dice_count.selected = 0

	dice_type.item_selected.connect(func(_i: int) -> void:
		_respawn_dice()
		_reset_ui()
	)
	dice_count.item_selected.connect(func(_i: int) -> void:
		_respawn_dice()
		_reset_ui()
	)


func _reset_ui() -> void:
	summary.text = "Total: -"
	pattern_label.text = "Pattern: -"
	for i: int in range(_die_labels.size()):
		_die_labels[i].text = "Die %d: -" % (i + 1)
		_die_labels[i].visible = false


func _setup_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.13, 0.15, 1)
	mat.roughness = 1.0
	mat.metallic = 0.0
	floor.material_override = mat


func _roll_many() -> void:
	if _is_rolling:
		return
	_is_rolling = true
	roll_button.disabled = true
	dice_type.disabled = true
	dice_count.disabled = true

	var sides: int = dice_type.get_selected_id()
	var count: int = dice_count.get_selected_id()

	# Ensure dice exist and match current selection.
	_respawn_dice()

	var rolls: Array[int] = []
	rolls.resize(count)
	for i in range(count):
		rolls[i] = 0

	# Kick off rolls (visual).
	for die in _dice_nodes:
		if die.has_method("roll"):
			die.call("roll")

	# Collect results via signals (animation-driven).
	for i in range(count):
		var die := _dice_nodes[i]
		var v: int = await _await_die_roll(die)
		rolls[i] = v

	var total := 0
	for v in rolls:
		total += int(v)

	summary.text = "Total: %d" % total
	pattern_label.text = "Pattern: %s" % _describe_patterns(rolls)
	for i: int in range(_die_labels.size()):
		if i < count:
			_die_labels[i].text = "Die %d: %d" % [i + 1, rolls[i]]
			_die_labels[i].visible = true
		else:
			_die_labels[i].visible = false

	_is_rolling = false
	roll_button.disabled = false
	dice_type.disabled = false
	dice_count.disabled = false


func _await_die_roll(die: Node) -> int:
	# Await a single rolled(value) signal from the die.
	# If the die doesn't have it for some reason, fall back to RNG.
	if die.has_signal("rolled"):
		var v: int = int(await die.rolled)
		return v
	var sides: int = dice_type.get_selected_id()
	return _rng.randi_range(1, sides)


func _respawn_dice() -> void:
	# Recreate dice visuals when selection changes.
	for child in dice_root.get_children():
		child.queue_free()
	_dice_nodes.clear()

	var sides: int = dice_type.get_selected_id()
	var count: int = dice_count.get_selected_id()
	var scene: PackedScene = _scene_for_sides(sides)

	var spacing := 1.6
	if sides >= 12:
		spacing = 1.8

	var start_x := -spacing * float(count - 1) * 0.5
	for i in range(count):
		var die: Node3D = scene.instantiate()
		die.position = Vector3(start_x + float(i) * spacing, 0.9, 0)
		dice_root.add_child(die)
		_dice_nodes.append(die)


func _scene_for_sides(sides: int) -> PackedScene:
	match sides:
		4: return D4_SCENE
		6: return D6_SCENE
		8: return D8_SCENE
		10: return D10_SCENE
		12: return D12_SCENE
		20: return D20_SCENE
		_: return D6_SCENE


func _describe_patterns(rolls: Array[int]) -> String:
	if rolls.is_empty():
		return "High die"

	var freq: Dictionary = _build_freq(rolls) # int -> int
	var counts_desc: Array[int] = _sorted_counts_desc(freq)

	var unique_sorted: Array[int] = _sorted_unique(rolls)
	return _classify_best(counts_desc, unique_sorted, rolls)


func _build_freq(rolls: Array[int]) -> Dictionary:
	var d: Dictionary = {}
	for v: int in rolls:
		d[v] = int(d.get(v, 0)) + 1
	return d


func _sorted_counts_desc(freq: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for k in freq.keys():
		out.append(int(freq[k]))
	out.sort()
	out.reverse()
	return out


func _sorted_unique(rolls: Array[int]) -> Array[int]:
	var seen: Dictionary = {}
	for v: int in rolls:
		seen[v] = true
	var out: Array[int] = []
	for k in seen.keys():
		out.append(int(k))
	out.sort()
	return out


func _classify_best(counts_desc: Array[int], unique_sorted: Array[int], rolls: Array[int]) -> String:
	# Return exactly ONE best match (no combining).
	# Precedence order is top-to-bottom.

	# Kind-based patterns.
	if counts_desc.size() == 1 and counts_desc[0] == 5:
		return "Five of a kind"
	if counts_desc.size() == 2 and counts_desc[0] == 4 and counts_desc[1] == 1:
		return "Four of a kind"
	if counts_desc.size() == 2 and counts_desc[0] == 3 and counts_desc[1] == 2:
		return "Full house"

	# Straight patterns (based on unique values).
	if _has_run(unique_sorted, 5):
		return "Large straight"
	if _has_run(unique_sorted, 4):
		return "Straight"
	if _has_run(unique_sorted, 3):
		return "Small straight"

	# Remaining kind-based patterns.
	if counts_desc.size() == 3 and counts_desc[0] == 3 and counts_desc[1] == 1 and counts_desc[2] == 1:
		return "Three of a kind"
	if counts_desc.size() == 3 and counts_desc[0] == 2 and counts_desc[1] == 2 and counts_desc[2] == 1:
		return "Two pair"
	if counts_desc.size() == 4 and counts_desc[0] == 2:
		return "Pair"

	# Parity patterns (only when nothing higher matched).
	if _all_even(rolls):
		return "All even"
	if _all_odd(rolls):
		return "All odd"

	return "High die"


func _has_run(unique_sorted: Array[int], run_len: int) -> bool:
	# Any consecutive run of length run_len among the unique values.
	if run_len <= 1:
		return true
	if unique_sorted.size() < run_len:
		return false
	for i: int in range(0, unique_sorted.size() - (run_len - 1)):
		if unique_sorted[i + (run_len - 1)] - unique_sorted[i] == (run_len - 1):
			return true
	return false


func _all_even(rolls: Array[int]) -> bool:
	for v: int in rolls:
		if (v % 2) != 0:
			return false
	return true


func _all_odd(rolls: Array[int]) -> bool:
	for v: int in rolls:
		if (v % 2) == 0:
			return false
	return true


