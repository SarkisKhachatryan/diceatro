### Potential improvements

### Physics-based dice (more realistic)

Right now rolls are Tween-driven and “present” the chosen face to the camera. If you want physical realism, switch dice to `RigidBody3D` and determine the result once the die settles.

Reference projects:
- `https://pawsgineer.itch.io/godot-3d-dice-roller-template`
- `https://vokimon.itch.io/godot-dice-roller`

### Standard D10 (trapezohedron)

If you need tabletop D10 geometry, use:
- imported mesh (Blender) or
- procedural trapezohedron generation (10 kite faces)

### Face mapping standards

If you want “opposite faces sum to N+1” (common dice convention), add explicit face label mapping:
- store per-face normal + value mapping, not “face index order”.

### Performance / caching

Cache generated meshes and edge meshes:
- compute once per dice type and reuse
- avoid re-running `MeshDataTool` for every instance

### UI/UX

- Add “Stop”/“Cancel” for Stat simulation
- Add copy/export of histogram to clipboard
- Add seed control for reproducibility


