### Cursor context (project cheatsheet)

This file is meant to quickly orient an AI coding assistant (Cursor) or a new contributor.

### Key entry points

- **Startup scene**: `scenes/MainMenu.tscn` (set in `project.godot`)
- **Roll simulation**: `scenes/Main.tscn` + `scripts/Main.gd`
- **Stat simulation**: `scenes/Simulation.tscn` + `scripts/Simulation.gd`
- **Many roll simulation**: `scenes/ManyRollSimulation.tscn` + `scripts/ManyRollSimulation.gd`

### Dice interface

All dice scenes provide:
- `func roll() -> void`
- `signal rolled(value: int)`

Dice scripts live in `scripts/` (D4/D6/D8/D10/D12/D20).

### Conventions / gotchas

- **Explicit typing**: this project can treat warnings as errors; avoid Variant inference in GDScript.
- **Edges/outline**:
  - `Body/Edges` exists for all dice (black wire edges)
  - `Body/Outline` exists but is usually `outline_enabled = false`
- **D10 is a decahedron** (pentagonal bipyramid), not a standard tabletop D10.

### Tests

Run headless tests:

```powershell
& "C:\path\to\Godot.exe" --headless --script "res://tests/run_tests.gd" --verbose
```

### Navigation

Navigation is scene-based via `get_tree().change_scene_to_file(...)`.


