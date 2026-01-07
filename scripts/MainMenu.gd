extends Control

@onready var roll_button: Button = $Center/VBox/RollButton
@onready var sim_button: Button = $Center/VBox/SimButton
@onready var many_roll_button: Button = $Center/VBox/ManyRollButton


func _ready() -> void:
	roll_button.pressed.connect(_go_roll)
	sim_button.pressed.connect(_go_sim)
	many_roll_button.pressed.connect(_go_many_roll)


func _go_roll() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _go_sim() -> void:
	get_tree().change_scene_to_file("res://scenes/Simulation.tscn")


func _go_many_roll() -> void:
	get_tree().change_scene_to_file("res://scenes/ManyRollSimulation.tscn")


