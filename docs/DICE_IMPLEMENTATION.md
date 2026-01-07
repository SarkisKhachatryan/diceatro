### Dice implementation overview

All dice scripts expose:
- **`func roll() -> void`**: triggers a roll animation
- **`signal rolled(value: int)`**: emitted when the roll is complete

The roll simulation screen (`scenes/Main.tscn` + `scripts/Main.gd`) expects those two things.

### Animation model (deterministic “presentation”)

These dice are *not physics-based*. The roll is:
- lift up a bit
- rotate with random spins + wobble (Tween)
- settle into a deterministic rotation so the chosen face is presented toward the camera
- emit `rolled(value)`

This keeps results readable and avoids ambiguous “edge resting” states.

### “Presented face” vs “top face”

For D6 (`scripts/Dice.gd`) we support presenting the rolled face toward the camera:
- `@export var count_face_user_sees := true`

Most other dice always present the chosen face toward the camera (for readability).

### Mesh generation

- **D6**: `scenes/Dice.tscn` uses a cube mesh and places `Label3D` nodes on each face.
- **D4/D8/D10/D12/D20**: generated procedurally via `SurfaceTool`:
  - D4: tetrahedron
  - D8: octahedron
  - D10: pentagonal bipyramid (true decahedron)
  - D12: dodecahedron generated as dual of an icosahedron
  - D20: icosahedron

### Labels (“printed” numbers)

For generated dice, each face gets a `Face_<n>` node and a `Label3D` child.
We keep numbers very close to the surface (but not z-fighting) using:
- `face_label_outset`: tiny outward offset from the face plane
- `label_local_outset`: tiny additional offset along the label’s local -Z

Many dice also default to `mirror_numbers = true` because `Label3D` face orientation on angled faces can read “inside-out” otherwise.

### Edge highlighting

Each dice scene contains:
- `Body/Edges` (required)
- `Body/Outline` (optional shell outline; default off via `outline_enabled`)

Edges are built from the mesh and rendered using an `ImmediateMesh` with black lines.

### “Warning treated as error” note

This repo is configured so certain warnings can fail parsing in the editor/runtime.
Best practice here: **explicit types** when working with arrays/dictionaries and helper functions like `min()`/`max()`.


