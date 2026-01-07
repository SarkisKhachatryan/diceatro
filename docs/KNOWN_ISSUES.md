### Known issues / limitations

### Dice model fidelity

- **D10 shape**: `scripts/D10.gd` is a **pentagonal bipyramid** (true decahedron), not the “standard” tabletop D10 (pentagonal trapezohedron). If you need a standard D10, you’ll want a different mesh generation approach or an imported model.

### Face numbering conventions

For generated meshes (especially D10/D12/D20), the numeric mapping **1..N** is assigned in a deterministic, but not tabletop-standard, order.
If you need “standard” opposite-face sums or canonical numbering, add an explicit face ordering map.

### Rendering quirks

- `Label3D` on angled faces can appear mirrored depending on face orientation; many dice default to `mirror_numbers = true`.
- The filled shell outline (`Body/Outline`) is **disabled by default** via `outline_enabled = false` because depending on face winding/culling it can overdraw faces. Edge lines (`Body/Edges`) are the reliable “corner highlight”.

### Performance

- `Body/Edges` is generated at runtime using `MeshDataTool` → acceptable for small meshes but not “free”.
  - If you add many dice simultaneously, consider caching edge meshes per dice type.


