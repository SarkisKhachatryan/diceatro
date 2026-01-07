### Project structure

This is a Godot 4.5 project. Key folders:

- `scenes/`
  - `MainMenu.tscn`: entry scene (startup)
  - `Main.tscn`: roll simulation scene (animated 3D dice)
  - `Simulation.tscn`: stat simulation scene (fast RNG rolls + histogram)
  - `ManyRollSimulation.tscn`: multi-dice roll scene (up to 5 animated dice in a SubViewport)
  - `Dice.tscn`: D6 cube with `Label3D` faces
  - `D4.tscn`, `D8.tscn`, `D10.tscn`, `D12.tscn`, `D20.tscn`: generated-mesh dice scenes (mesh created in script)

- `scripts/`
  - `MainMenu.gd`: scene navigation from menu
  - `Main.gd`: roll simulation controller
  - `Simulation.gd`: stat simulation controller
  - `ManyRollSimulation.gd`: multi-dice roll controller
  - Dice scripts:
    - `Dice.gd` (D6)
    - `D4.gd`, `D8.gd`, `D10.gd`, `D12.gd`, `D20.gd`

- `tests/`
  - `run_tests.gd`: headless test runner for geometry/orientation expectations

Other:
- `project.godot`: project settings (startup scene, file logging)


