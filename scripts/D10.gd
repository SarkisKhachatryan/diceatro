extends Node3D

signal rolled(value: int)

@export var roll_duration := 0.9
@export var lift_height := 0.45
@export var settle_duration := 0.18
@export var min_spins := 2
@export var max_spins := 4

@export var mirror_numbers := true
@export var body_scale := 0.90
@export var label_font_size := 96
@export var label_pixel_size := 0.0085
@export var face_label_outset := 0.03 # tiny offset above the face plane (printed look)
@export var label_local_outset := 0.012 # small extra offset to avoid z-fighting

@export var outline_enabled := false

var is_rolling := false
var _rng := RandomNumberGenerator.new()
var _face_normals: Array = []
var _target_value: int = 1
var _rest_pos: Vector3 = Vector3.ZERO

@onready var body: MeshInstance3D = $Body
@onready var outline: MeshInstance3D = $Body/Outline
@onready var edges: MeshInstance3D = $Body/Edges


func _ready() -> void:
	_rng.randomize()
	_build_mesh()
	_configure_outline()
	_configure_edges()
	_build_numbers()
	rotation = Vector3.ZERO
	_rest_pos = position


func roll() -> void:
	if is_rolling:
		return

	_target_value = _rng.randi_range(1, 10)

	var spins := Vector3(
		_rng.randi_range(min_spins, max_spins),
		_rng.randi_range(min_spins, max_spins),
		_rng.randi_range(min_spins, max_spins)
	) * TAU
	var wobble := Vector3(
		_rng.randf_range(-0.6, 0.6),
		_rng.randf_range(-0.6, 0.6),
		_rng.randf_range(-0.6, 0.6)
	)

	is_rolling = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", _rest_pos + Vector3(0, lift_height, 0), 0.18)
	tween.tween_property(self, "rotation", rotation + spins + wobble, roll_duration)
	tween.set_parallel(false)
	tween.tween_property(self, "scale", Vector3(1.07, 0.93, 1.07), 0.10).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(self, "_finish_roll"))


func _finish_roll() -> void:
	rotation = Vector3(
		wrapf(rotation.x, -PI, PI),
		wrapf(rotation.y, -PI, PI),
		wrapf(rotation.z, -PI, PI)
	)

	var cam := get_viewport().get_camera_3d()
	var desired_dir: Vector3 = Vector3.FORWARD
	if cam != null:
		desired_dir = (cam.global_position - global_position).normalized()

	var face := _get_face_for_value(_target_value)
	var target_basis := _compute_target_basis(desired_dir, face["normal"], face["up"])
	var snap_rot := target_basis.get_euler()
	var safe_pos := _compute_safe_position(target_basis)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", snap_rot, settle_duration)
	tween.tween_property(self, "position", safe_pos, settle_duration)
	tween.tween_callback(Callable(self, "_emit_roll").bind(_target_value))


func _emit_roll(value: int) -> void:
	is_rolling = false
	rolled.emit(value)


func _build_mesh() -> void:
	# Pentagonal bipyramid (a decahedron with 10 triangular faces).
	# Note: A "standard" d10 is a trapezohedron, but this is a true decahedron.
	var h: float = 1.0
	var r: float = 0.95
	var top := Vector3(0, h, 0)
	var bot := Vector3(0, -h, 0)

	var ring: Array[Vector3] = []
	for i in range(5):
		var a := TAU * float(i) / 5.0
		ring.append(Vector3(r * cos(a), 0.0, r * sin(a)))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Top 5 faces
	for i in range(5):
		var a := ring[i]
		var b := ring[(i + 1) % 5]
		_add_tri(st, top, a, b)

	# Bottom 5 faces
	for i in range(5):
		var a := ring[(i + 1) % 5]
		var b := ring[i]
		_add_tri(st, bot, a, b)

	st.generate_normals()
	var mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.95, 1.0)
	mat.roughness = 0.45
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mesh.surface_set_material(0, mat)

	body.mesh = mesh
	body.scale = Vector3.ONE * body_scale

	if outline != null:
		outline.mesh = mesh
	if edges != null:
		edges.mesh = null


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Ensure outward winding (important for correct culling/outline).
	var center: Vector3 = (a + b + c) / 3.0
	var n: Vector3 = (b - a).cross(c - a)
	if n.dot(center) < 0.0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)


func _configure_outline() -> void:
	if outline == null:
		return
	outline.visible = outline_enabled
	if not outline_enabled:
		return
	outline.scale = Vector3.ONE * 1.05
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.04, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.material_override = mat


func _configure_edges() -> void:
	if body == null or edges == null:
		return
	if body.mesh == null:
		return

	var mdt := MeshDataTool.new()
	var mesh := body.mesh as Mesh
	var err := mdt.create_from_surface(mesh, 0)
	if err != OK:
		return

	var edge_set := {}
	for f_i in range(mdt.get_face_count()):
		var a := mdt.get_face_vertex(f_i, 0)
		var b := mdt.get_face_vertex(f_i, 1)
		var c := mdt.get_face_vertex(f_i, 2)
		_edge_add(edge_set, a, b)
		_edge_add(edge_set, b, c)
		_edge_add(edge_set, c, a)

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in edge_set.keys():
		var pair: Array = k.split(":")
		var i0 := int(pair[0])
		var i1 := int(pair[1])
		im.surface_add_vertex(mdt.get_vertex(i0))
		im.surface_add_vertex(mdt.get_vertex(i1))
	im.surface_end()

	edges.mesh = im
	edges.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.04, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = false
	edges.material_override = mat


func _edge_add(edge_set: Dictionary, i0: int, i1: int) -> void:
	var a := mini(i0, i1)
	var b := maxi(i0, i1)
	var key := "%d:%d" % [a, b]
	edge_set[key] = true


func _build_numbers() -> void:
	var labels_root: Node3D
	if body.has_node("Labels"):
		labels_root = body.get_node("Labels") as Node3D
		for c in labels_root.get_children():
			c.queue_free()
	else:
		labels_root = Node3D.new()
		labels_root.name = "Labels"
		body.add_child(labels_root)

	_face_normals.clear()

	var mesh: Mesh = body.mesh
	if mesh == null:
		return

	var mdt: MeshDataTool = MeshDataTool.new()
	var err: int = mdt.create_from_surface(mesh, 0)
	if err != OK:
		return

	# Assign values 1..10 to faces in their surface order.
	var face_count: int = mini(10, mdt.get_face_count())
	for face_i: int in range(face_count):
		var value: int = face_i + 1

		var ia: int = mdt.get_face_vertex(face_i, 0)
		var ib: int = mdt.get_face_vertex(face_i, 1)
		var ic: int = mdt.get_face_vertex(face_i, 2)
		var a: Vector3 = mdt.get_vertex(ia)
		var b: Vector3 = mdt.get_vertex(ib)
		var c: Vector3 = mdt.get_vertex(ic)

		var center: Vector3 = (a + b + c) / 3.0
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		if normal.dot(center) < 0.0:
			normal = -normal

		var face_node := Node3D.new()
		face_node.name = "Face_%d" % value
		face_node.position = center + normal * face_label_outset
		labels_root.add_child(face_node)

		# Robust orientation: face the node outward.
		var world_basis: Basis = body.global_transform.basis.orthonormalized()
		var world_normal: Vector3 = (world_basis * normal).normalized()
		var world_up: Vector3 = Vector3.UP - world_normal * Vector3.UP.dot(world_normal)
		if world_up.length() < 0.001:
			world_up = Vector3.RIGHT - world_normal * Vector3.RIGHT.dot(world_normal)
		world_up = world_up.normalized()
		face_node.look_at(face_node.global_position + world_normal, world_up)

		var label := Label3D.new()
		label.text = str(value)
		label.font_size = label_font_size
		label.pixel_size = label_pixel_size
		label.modulate = Color(0.1, 0.1, 0.1, 1.0)
		label.outline_modulate = Color(1, 1, 1, 1)
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.shaded = false
		if mirror_numbers:
			label.scale = Vector3(-1, 1, 1)
		label.position = Vector3(0, 0, -label_local_outset)
		face_node.add_child(label)

		var up_dir: Vector3 = face_node.basis.y.normalized()
		_face_normals.append({"value": value, "normal": normal, "up": up_dir})


func _get_face_for_value(value: int) -> Dictionary:
	for f in _face_normals:
		if int(f["value"]) == value:
			return {"normal": f["normal"], "up": f["up"]}
	return {"normal": Vector3.UP, "up": Vector3.UP}


func _compute_target_basis(desired_dir: Vector3, face_normal: Vector3, face_up: Vector3) -> Basis:
	var dir := desired_dir.normalized()
	var z_world := -dir

	var desired_up := Vector3.UP - dir * Vector3.UP.dot(dir)
	if desired_up.length() < 0.001:
		desired_up = Vector3.FORWARD - dir * Vector3.FORWARD.dot(dir)
	desired_up = desired_up.normalized()

	var x_world := desired_up.cross(z_world).normalized()
	var y_world := z_world.cross(x_world).normalized()
	var world_basis := Basis(x_world, y_world, z_world)

	# Local: we want local -Z to be outward.
	var z_local := -face_normal.normalized()
	var y_local := face_up - z_local * face_up.dot(z_local)
	if y_local.length() < 0.001:
		y_local = Vector3.UP - z_local * Vector3.UP.dot(z_local)
	y_local = y_local.normalized()
	var x_local := y_local.cross(z_local).normalized()
	var local_basis := Basis(x_local, y_local, z_local)

	return world_basis * local_basis.inverse()


func _compute_safe_position(target_basis: Basis) -> Vector3:
	# Lift so the lowest vertex is above floor y=0.
	var h: float = 1.0
	var r: float = 0.95
	var top: Vector3 = Vector3(0, h, 0)
	var bot: Vector3 = Vector3(0, -h, 0)
	var verts: Array[Vector3] = [top, bot]
	for i in range(5):
		var a := TAU * float(i) / 5.0
		verts.append(Vector3(r * cos(a), 0.0, r * sin(a)))

	var s: float = body.scale.x
	var min_y: float = INF
	for v: Vector3 in verts:
		var y: float = (target_basis * (v * s)).y
		min_y = min(min_y, y)

	var clearance: float = 0.02
	var pos: Vector3 = _rest_pos
	var needed: float = -min_y + clearance
	if needed > 0.0:
		pos.y += needed
	return pos


