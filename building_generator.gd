extends Node3D
class_name BuildingGenerator

@export var building_scenes: Array[PackedScene] = []

@export var side_offset: float = 0.0
@export var min_spacing: float = 0.0
@export var max_spacing: float = 0.0

var active_buildings: Array[Node3D] = []
var building_always_active: bool = false

# GLOBAL TRACK (BIAR NYAMBUNG ANTAR BLOCK)
var global_left_z: float = INF
var global_right_z: float = INF

# =========================================================

func spawn_buildings_on_block(block: Node3D) -> void:
	if not building_always_active: return
	
	print("function called: spawn_buildings_on_block")
	if building_scenes.is_empty():
		print("building scene is empty")
		return

	var block_length = get_block_length(block)
	var width = 17.5

	var start_z = block.position.z
	var end_z = block.position.z - block_length
	print("start_z=",start_z)
	print("end_z=",end_z)

	# init sekali saja
	if global_left_z == INF:
		global_left_z = start_z
	if global_right_z == INF:
		global_right_z = start_z

	# ================= LEFT =================
	while global_left_z > end_z:
		global_left_z = spawn_one(-1, width, global_left_z)

	# ================= RIGHT =================
	while global_right_z > end_z:
		global_right_z = spawn_one(1, width, global_right_z)

# =========================================================

func spawn_one(side: int, width: float, current_z: float) -> float:
	var scene = building_scenes.pick_random()
	var building = scene.instantiate()

	# 🔥 ambil panjang dari tiap gedung (WAJIB ADA)
	var len: float = 6.0
	if building.has_method("get_length") and building.get("length") != null:
		len = building.get("length")

	var spacing = randf_range(min_spacing, max_spacing)

	var z = current_z - spacing - (len / 2.0)
	var next_z = current_z - spacing - len

	var x = side * (width / 2.0 + side_offset)

	building.position = Vector3(x, 0, z)

	# hadap jalan
	if side == -1:
		building.rotation_degrees.y = 90
	else:
		building.rotation_degrees.y = -90

	add_child(building)
	active_buildings.append(building)
	print("Building Position:",building.position.z)

	return next_z

# =========================================================

func get_block_length(block: Node3D) -> float:
	var mesh := block.find_child("", true, false) as MeshInstance3D
	if mesh and mesh.mesh:
		return mesh.mesh.get_aabb().size.z * mesh.scale.z
	return 50.0

# =========================================================

func update_buildings(delta: float, speed: float) -> void:
	# 🔥 TAMBAHAN: Geser juga titik global spawn biar gak ketinggalan!
	if global_left_z != INF:
		global_left_z += speed * delta
	if global_right_z != INF:
		global_right_z += speed * delta

	for b in active_buildings:
		if not is_instance_valid(b):
			continue
		
		b.position.z += speed * delta
		
		if b.position.z > 30.0:
			b.queue_free()
	
	active_buildings = active_buildings.filter(is_instance_valid)

# =========================================================

func load_buildings(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("Cannot open building folder: " + path)
		return
	
	for file in dir.get_files():
		if file.ends_with(".tscn"):
			building_scenes.append(load(path + "/" + file))
