extends Node3D

const D6_SCENE: PackedScene = preload("res://scenes/Dice.tscn")
const D4_SCENE: PackedScene = preload("res://scenes/D4.tscn")
const D8_SCENE: PackedScene = preload("res://scenes/D8.tscn")

@onready var dice_holder: Node3D = $DiceHolder
@onready var dice_type: OptionButton = $CanvasLayer/UI/HUD/VBox/DiceType
@onready var roll_button: Button = $CanvasLayer/UI/HUD/VBox/RollButton
@onready var score_label: Label = $CanvasLayer/UI/HUD/VBox/ScoreLabel

var dice: Node


func _ready() -> void:
	score_label.text = "Score: -"

	dice_type.clear()
	dice_type.add_item("D6", 6)
	dice_type.add_item("D4", 4)
	dice_type.add_item("D8", 8)
	dice_type.selected = 0
	dice_type.item_selected.connect(_on_dice_type_selected)

	roll_button.pressed.connect(_on_roll_pressed)

	# Use the existing child if present (from the scene), otherwise spawn default.
	if dice_holder.get_child_count() > 0:
		dice = dice_holder.get_child(0)
	else:
		_spawn_dice(6)

	dice.rolled.connect(_on_dice_rolled)


func _on_roll_pressed() -> void:
	roll_button.disabled = true
	dice.roll()


func _on_dice_rolled(value: int) -> void:
	score_label.text = "Score: %d" % value
	roll_button.disabled = false


func _on_dice_type_selected(_index: int) -> void:
	var sides := dice_type.get_selected_id()
	roll_button.disabled = true
	score_label.text = "Score: -"
	_spawn_dice(sides)
	roll_button.disabled = false


func _spawn_dice(sides: int) -> void:
	for child in dice_holder.get_children():
		child.queue_free()

	# D4/D8 are taller, so lift them a bit to avoid clipping into the floor.
	var y := 0.5
	if sides == 4:
		y = 0.9
	elif sides == 8:
		y = 1.0
	dice_holder.position = Vector3(0, y, 0)

	var scene: PackedScene = D6_SCENE
	if sides == 4:
		scene = D4_SCENE
	elif sides == 8:
		scene = D8_SCENE
	dice = scene.instantiate()
	dice_holder.add_child(dice)
	dice.rolled.connect(_on_dice_rolled)


