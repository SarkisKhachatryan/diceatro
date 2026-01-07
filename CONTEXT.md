### Single entry point: project context

Use this file as the **one entry point** for understanding and working on the repo (humans + Cursor/AI).

---

### 0) How to use this in new Cursor/AI sessions

- In a new chat/window, you can paste **`CONTEXT.md`** first.
- The model should then decide what additional files to read (linked docs under `docs/`, scenes, scripts) based on the task.

Documentation workflow for changes:
- Update `CONTEXT.md` first (what changed + where).
- If needed, update deeper docs in `docs/` (structure, testing, known issues).
- Keep `CONTEXT.md` short, but make it a reliable navigation map.

---

### 1) What this project is

**Diceatro** is a Godot 4.5 project with:
- **Main menu** (scene navigation)
- **Roll simulation** (animated 3D dice, one at a time)
- **Stat simulation** (fast RNG simulation, histogram on screen)
- **Many roll simulation** (roll 1–5 dice with animations, show total sum)

Startup scene: `scenes/MainMenu.tscn` (configured in `project.godot`).

---

### 2) “Where do I change X?”

- **Menu buttons / navigation**: `scenes/MainMenu.tscn`, `scripts/MainMenu.gd`
- **Roll simulation screen**: `scenes/Main.tscn`, `scripts/Main.gd`
- **Stat simulation screen**: `scenes/Simulation.tscn`, `scripts/Simulation.gd`
- **Many roll simulation screen**: `scenes/ManyRollSimulation.tscn`, `scripts/ManyRollSimulation.gd`

---

### 3) Dice contract (critical)

All dice scenes/scripts must implement:
- `func roll() -> void`
- `signal rolled(value: int)`

Dice are used by:
- `scripts/Main.gd` (single roll)
- `scripts/ManyRollSimulation.gd` (multi-roll animations + awaits `rolled`)

---

### 4) Dice implementations (where each die lives)

- **D4**: `scenes/D4.tscn` + `scripts/D4.gd` (tetrahedron)
- **D6**: `scenes/Dice.tscn` + `scripts/Dice.gd` (cube)
- **D8**: `scenes/D8.tscn` + `scripts/D8.gd` (octahedron)
- **D10**: `scenes/D10.tscn` + `scripts/D10.gd`
  - Note: this is a **pentagonal bipyramid (true decahedron)**, not the standard tabletop D10 trapezohedron.
- **D12**: `scenes/D12.tscn` + `scripts/D12.gd` (dodecahedron, generated as dual of icosahedron)
- **D20**: `scenes/D20.tscn` + `scripts/D20.gd` (regular icosahedron)

---

### 5) Visual conventions

Each dice scene has:
- `Body` (`MeshInstance3D`)
- `Body/Edges` (`MeshInstance3D`) — black wireframe edges (**expected to exist**)
- `Body/Outline` (`MeshInstance3D`) — optional; controlled by `outline_enabled` (defaults `false`)

Numbers are “printed” by keeping them close to the surface using:
- `face_label_outset`
- `label_local_outset`

Many dice default to `mirror_numbers = true` due to `Label3D` orientation on angled faces.

---

### 6) Testing (headless)

Test runner: `tests/run_tests.gd`

What it covers (high-level):
- Face-presentation math
- Safe positioning above floor
- Default label-outset constants
- Main camera framing defaults

How to run (PowerShell example):

```powershell
& "C:\path\to\Godot_v4.5.1-stable_win64.exe" --headless --script "res://tests/run_tests.gd" --verbose
```

More details: `docs/TESTING.md`

---

### 7) Known issues / limitations

See: `docs/KNOWN_ISSUES.md`

---

### 8) Improvements roadmap

See: `docs/IMPROVEMENTS.md`

---

### 9) Full documentation set

- Repo overview: `README.md`
- Structure map: `docs/PROJECT_STRUCTURE.md`
- Dice details: `docs/DICE_IMPLEMENTATION.md`
- Testing: `docs/TESTING.md`
- Known issues: `docs/KNOWN_ISSUES.md`
- Improvements: `docs/IMPROVEMENTS.md`
- Cursor cheatsheet: `CURSOR_CONTEXT.md`


