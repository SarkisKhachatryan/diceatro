extends Control

@onready var back_button: Button = $Margin/VBox/BackButton
@onready var dice_type: OptionButton = $Margin/VBox/Controls/DiceType
@onready var runs: OptionButton = $Margin/VBox/Controls/Runs
@onready var run_button: Button = $Margin/VBox/Controls/RunButton
@onready var progress: ProgressBar = $Margin/VBox/Progress
@onready var status_label: Label = $Margin/VBox/Status
@onready var results: RichTextLabel = $Margin/VBox/Results

var _is_running := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	back_button.pressed.connect(_go_back)
	run_button.pressed.connect(_on_run_pressed)

	_rng.randomize()
	_setup_options()
	_reset_ui()


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

	runs.clear()
	runs.add_item("100", 100)
	runs.add_item("1000", 1000)
	runs.add_item("5000", 5000)
	runs.add_item("10000", 10000)
	runs.selected = 1 # 1000 default


func _reset_ui() -> void:
	progress.value = 0.0
	status_label.text = "Choose dice + runs, then click Run."
	results.text = ""
	run_button.disabled = false
	dice_type.disabled = false
	runs.disabled = false


func _on_run_pressed() -> void:
	if _is_running:
		return
	_is_running = true

	run_button.disabled = true
	dice_type.disabled = true
	runs.disabled = true
	results.text = ""

	var sides: int = dice_type.get_selected_id()
	var n: int = runs.get_selected_id()

	await _run_simulation(sides, n)

	_is_running = false
	run_button.disabled = false
	dice_type.disabled = false
	runs.disabled = false


func _run_simulation(sides: int, n: int) -> void:
	status_label.text = "Running %d rolls of D%d..." % [n, sides]
	progress.value = 0.0

	var counts: Array[int] = []
	counts.resize(sides + 1)
	for i in range(counts.size()):
		counts[i] = 0

	var batch := 2000
	var done := 0

	while done < n:
		var to_do := mini(batch, n - done)
		for i in range(to_do):
			var v: int = _rng.randi_range(1, sides)
			counts[v] += 1
		done += to_do
		progress.value = float(done) / float(n)
		status_label.text = "Running... %d / %d" % [done, n]
		await get_tree().process_frame

	_show_results(sides, n, counts)


func _show_results(sides: int, n: int, counts: Array[int]) -> void:
	var expected: float = float(n) / float(sides)

	results.text = ""
	results.append_text("[b]Results[/b]\n")
	results.append_text("Dice: D%d\n" % sides)
	results.append_text("Runs: %d\n" % n)
	results.append_text("Expected per face: %.2f\n\n" % expected)

	for face in range(1, sides + 1):
		var c: int = counts[face]
		var pct: float = 100.0 * float(c) / float(n)
		results.append_text("%2d: %6d (%.2f%%)\n" % [face, c, pct])

	status_label.text = "Done."
	progress.value = 1.0


