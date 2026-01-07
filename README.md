### Diceatro (Godot 4.5)

Diceatro is a small Godot project that provides:
- **Roll simulation** (animated 3D dice you can roll interactively)
- **Stat simulation** (run N rolls and show per-face distribution)
- **Many roll simulation** (roll up to 5 dice at once with animation and show total sum)

The app starts in a **Main Menu** and navigates between pages using `change_scene_to_file`.

### Quick start

- **Open in Godot**: open `project.godot` with Godot 4.5.x.
- Press **Play** → you’ll start at `MainMenu.tscn`.

### Pages / Scenes

- **Main menu**: `scenes/MainMenu.tscn`
  - Roll simulation → `scenes/Main.tscn`
  - Stat simulation → `scenes/Simulation.tscn`
  - Many roll simulation → `scenes/ManyRollSimulation.tscn`

- **Roll simulation**: `scenes/Main.tscn`
  - Choose dice type and roll a single die.
  - **Back** returns to main menu.

- **Stat simulation**: `scenes/Simulation.tscn`
  - Choose dice and run count (100/1000/5000/10000).
  - Prints per-face counts + percentages on screen.
  - **Back** returns to main menu.

- **Many roll simulation**: `scenes/ManyRollSimulation.tscn`
  - Choose dice and count (1–5).
  - Rolls multiple dice with animations in a 3D preview and shows per-die results + total sum.
  - **Back** returns to main menu.

### Dice types

- D4: `scripts/D4.gd` (tetrahedron)
- D6: `scripts/Dice.gd` + `scenes/Dice.tscn` (cube)
- D8: `scripts/D8.gd` (octahedron)
- D10: `scripts/D10.gd` (**pentagonal bipyramid / true decahedron**, not the “standard” trapezohedron)
- D12: `scripts/D12.gd` (dodecahedron, generated as dual of an icosahedron)
- D20: `scripts/D20.gd` (regular icosahedron)

All dice expose the same interface:
- `func roll() -> void`
- `signal rolled(value: int)`

### Headless tests

We ship a minimal headless test runner at `tests/run_tests.gd`.

Example (PowerShell):

```powershell
& "C:\path\to\Godot_v4.5.1-stable_win64.exe" --headless --script "res://tests/run_tests.gd" --verbose
```

More details: `docs/TESTING.md`.

### Logging

This project uses Godot file logging (enabled in `project.godot`). The log file is stored under Godot’s app user data folder (not in the repo). See `docs/TESTING.md` for location notes.

### Docs / context

See:
- `docs/PROJECT_STRUCTURE.md`
- `docs/DICE_IMPLEMENTATION.md`
- `docs/KNOWN_ISSUES.md`
- `docs/IMPROVEMENTS.md`
- `CURSOR_CONTEXT.md`


