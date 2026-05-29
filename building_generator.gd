extends Node3D
class_name BuildingGenerator

# =========================================================
# 📁 PATHS
# =========================================================
var building_path = "res://terrain_buildings"
var nature_path = "res://terrain_nature"
var plot_path = "res://terrain_plot"
var plot_template_path: String = "res://terrain_plot/empty_plot.tscn"

# =========================================================
# 🎨 SCENE ARRAYS
# =========================================================
@export var building_scenes: Array[PackedScene] = []
var nature_components: Array[PackedScene] = []

# =========================================================
# ⚙️ SPAWN SETTINGS
# =========================================================
@export var side_offset: float = 2.0
@export var min_spacing: float = 0.0
@export var max_spacing: float = 0.0
@export var nature_density: int = 12
@export var nature_min_scale: float = 0.8
@export var nature_max_scale: float = 1.4
@export var nature_scatter_margin: float = 0.6

# =========================================================
# ⏱️ MODE TIMER SETTINGS
# =========================================================
@export var building_mode_duration: float = 3.0  # Detik
@export var nature_mode_duration: float = 3.0    # Detik
@export var auto_cycle_modes: bool = true         # Aktifkan auto-toggle timer

var _mode_timer: float = 0.0
var _mode_timer_running: bool = false

# =========================================================
# 🏗️ ACTIVE BUILDINGS TRACKING
# =========================================================
var active_buildings: Array[Node3D] = []

# =========================================================
# ✅ BUILDING ALWAYS ACTIVE
# =========================================================
var _building_always_active: bool = true : set = _on_building_active_changed

@export var building_always_active_inspector: bool:
	set(value): _building_always_active = value
	get: return _building_always_active

signal building_active_changed(is_active: bool)
signal mode_changed(is_building: bool, time_remaining: float)  # ✅ Signal baru untuk UI

func _on_building_active_changed(value: bool) -> void:
	_building_always_active = value
	building_active_changed.emit(value)
	_update_building_logic(value)

func _update_building_logic(is_active: bool) -> void:
	if is_active:
		_resume_building_spawning()
	else:
		_pause_building_spawning()

func _pause_building_spawning() -> void:
	print("🏢 Building spawning: PAUSED")
	_stop_mode_timer()

func _resume_building_spawning() -> void:
	print("🏢 Building spawning: RESUMED")
	if auto_cycle_modes and not _mode_timer_running:
		_start_mode_timer()

# =========================================================
# 🔥 GLOBAL TRACK
# =========================================================
var global_left_z: float = INF
var global_right_z: float = INF

# =========================================================
# 🔄 MODE TOGGLE
# =========================================================
var type_building: bool = false : set = _on_type_building_changed
var type_nature: bool = true : set = _on_type_nature_changed

func _on_type_building_changed(value: bool) -> void:
	type_building = value
	if value:
		type_nature = false
		#_update_active_scenes()
		_reset_mode_timer(building_mode_duration)

func _on_type_nature_changed(value: bool) -> void:
	type_nature = value
	if value:
		type_building = false
		#_update_active_scenes()
		_reset_mode_timer(nature_mode_duration)

func _update_active_scenes() -> void:
	if type_building:
		print("🏢 Mode: BUILDING (%.1fs)" % building_mode_duration)
	elif type_nature:
		print("🌿 Mode: NATURE (%.1fs)" % nature_mode_duration)
	else:
		print("⚠️ Mode: NONE")

# =========================================================
# 🎮 MODE HELPERS
# =========================================================
func set_mode_building() -> void:
	type_building = true
	type_nature = false

func set_mode_nature() -> void:
	type_building = false
	type_nature = true

func toggle_mode() -> void:
	if type_building:
		set_mode_nature()
	else:
		set_mode_building()

# =========================================================
# ⏱️ MODE TIMER FUNCTIONS
# =========================================================
func _start_mode_timer() -> void:
	_mode_timer_running = true
	_reset_mode_timer(building_mode_duration if type_building else nature_mode_duration)

func _stop_mode_timer() -> void:
	_mode_timer_running = false
	_mode_timer = 0.0

func _reset_mode_timer(duration: float) -> void:
	_mode_timer = duration
	mode_changed.emit(type_building, _mode_timer)  # Emit signal untuk UI

func _update_mode_timer(delta: float) -> void:
	if not _mode_timer_running or not auto_cycle_modes:
		return
	
	_mode_timer -= delta
	mode_changed.emit(type_building, _mode_timer)  # Update UI setiap frame
	
	if _mode_timer <= 0.0:
		# ✅ Timer habis, toggle mode
		if type_building:
			print("⏱️ Building mode ended → Switching to Nature")
			set_mode_nature()
		else:
			print("⏱️ Nature mode ended → Switching to Building")
			set_mode_building()
		# Timer sudah di-reset otomatis via setter type_building/type_nature

# ✅ Public: Get remaining time for UI
func get_mode_time_remaining() -> float:
	return max(0.0, _mode_timer)

func get_current_mode_name() -> String:
	return "BUILDING" if type_building else "NATURE" if type_nature else "NONE"

# =========================================================
# 🏗️ MAIN SPAWN FUNCTION
# =========================================================
func spawn_buildings_on_block(block: Node3D) -> void:
	if not _building_always_active: 
		return
	
	var block_length = get_block_length(block)
	var width = 20.0
	var start_z = block.position.z
	var end_z = block.position.z - block_length
	
	if global_left_z == INF: 
		global_left_z = start_z
	if global_right_z == INF: 
		global_right_z = start_z
	
	while global_left_z > end_z:
		global_left_z = spawn_one(-1, width, global_left_z, type_nature)

	while global_right_z > end_z:
		global_right_z = spawn_one(1, width, global_right_z, type_nature)

# =========================================================
# 🧱 SPAWN ONE INSTANCE
# =========================================================
func spawn_one(side: int, width: float, current_z: float, is_nature: bool) -> float:
	var len: float = 6.0
	var instance: Node3D = null
	
	if is_nature:
		instance = spawn_nature_plot()
		if not instance:
			return current_z
		len = get_node_length(instance)
	else:
		if building_scenes.is_empty():
			return current_z
		var scene = building_scenes.pick_random()
		instance = scene.instantiate() as Node3D
		if not instance:
			return current_z
		if instance.has_method("get_length"):
			len = instance.get_length()
		elif instance.get("length") != null:
			len = instance.length

	var spacing = randf_range(min_spacing, max_spacing)
	var z = current_z - spacing - (len / 2.0)
	var next_z = current_z - spacing - len
	
	# 🔄 HANDLE X BERDASARKAN MODE
	var x: float
	if is_nature:
		x = side * 26.5  # Side offset plot nature
	else:
		x = side * (width / 2.0 + side_offset)

	instance.position = Vector3(x, 0, z)

	# 🔄 ROTATION LOGIC
	if not is_nature:
		instance.rotation_degrees.y = 90 if side == -1 else -90
	# Nature: rotation_degrees.y = 0 (sudah di-set di generate_nature_components)

	add_child(instance)
	active_buildings.append(instance)

	return next_z

# =========================================================
# 🌿 SPAWN NATURE PLOT
# =========================================================
func spawn_nature_plot() -> Node3D:
	var plot_scene = load(plot_template_path) as PackedScene
	if not plot_scene:
		push_error("Failed to load plot template: " + plot_template_path)
		return null
	
	var plot_instance = plot_scene.instantiate() as Node3D
	if not plot_instance:
		return null
	
	generate_nature_components(plot_instance)
	
	return plot_instance

# =========================================================
# 🌲 GENERATE NATURE COMPONENTS (X-Z SCATTER + FACE -Z)
# =========================================================
func generate_nature_components(plot_instance: Node3D) -> void:
	if nature_components.is_empty():
		push_warning("nature_components is empty! Call load_nature_components() first.")
		return
	
	var plot_size_x: float = 0.0
	var plot_size_z: float = 0.0
	
	var mesh_node: MeshInstance3D = null
	for child in plot_instance.get_children():
		if child is MeshInstance3D:
			mesh_node = child
			break
	if mesh_node == null:
		mesh_node = plot_instance.find_child("*", true, false) as MeshInstance3D
		
	if mesh_node and mesh_node.mesh:
		var aabb = mesh_node.mesh.get_aabb()
		plot_size_x = aabb.size.x * abs(mesh_node.scale.x)
		plot_size_z = aabb.size.z * abs(mesh_node.scale.z)
	
	var half_x = plot_size_x / 2.0
	var half_z = plot_size_z / 2.0
	var margin = nature_scatter_margin
	
	var placed_positions: Array[Vector2] = []
	var count = randi_range(nature_density - 4, nature_density + 4)
	
	for i in count:
		var nature_scene = nature_components.pick_random()
		var nature_obj = nature_scene.instantiate() as Node3D
		if not nature_obj:
			continue
		
		var rand_x = randf_range(-half_x + margin, half_x - margin)
		var rand_z = randf_range(-half_z + margin, half_z - margin)
		
		var too_close = false
		for pos in placed_positions:
			if pos.distance_to(Vector2(rand_x, rand_z)) < 1.0:
				too_close = true
				break
		if too_close:
			continue
		
		nature_obj.position = Vector3(rand_x, 0.0, rand_z)
		placed_positions.append(Vector2(rand_x, rand_z))
		
		# 🌿 ROTATION: FACE -Z DIRECTION
		nature_obj.rotation_degrees.y = 0
		
		var scale_factor = randf_range(nature_min_scale, nature_max_scale)
		nature_obj.scale = Vector3.ONE * scale_factor
		
		plot_instance.add_child(nature_obj)

# =========================================================
# 📏 HELPERS
# =========================================================
func get_block_length(block: Node3D) -> float:
	var mesh := block.find_child("*", true, false) as MeshInstance3D
	if mesh and mesh.mesh:
		return mesh.mesh.get_aabb().size.z * mesh.scale.z
	return 50.0

func get_node_length(node: Node3D) -> float:
	var mesh := node.find_child("*", true, false) as MeshInstance3D
	if mesh and mesh.mesh:
		return mesh.mesh.get_aabb().size.z * abs(mesh.scale.z)
	return 10.0

# =========================================================
# 🔄 UPDATE BUILDINGS + TIMER
# =========================================================
func update_buildings(delta: float, speed: float) -> void:
	# ✅ Update mode timer dulu
	_update_mode_timer(delta)
	
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
	
	active_buildings = active_buildings.filter(func(item): return is_instance_valid(item))

# =========================================================
# 📂 LOADERS
# =========================================================
func load_buildings() -> void:
	var dir = DirAccess.open(building_path)
	if dir == null:
		push_error("Cannot open building folder: " + building_path)
		return
	
	for file in dir.get_files():
		if file.ends_with(".tscn"):
			var scene = load(building_path + "/" + file) as PackedScene
			if scene:
				building_scenes.append(scene)
	print("🏢 Loaded %d building scenes" % building_scenes.size())

func load_nature_components() -> void:
	var dir = DirAccess.open(nature_path)
	if dir == null:
		push_error("Cannot open nature folder: " + nature_path)
		return
	
	nature_components.clear()
	for file in dir.get_files():
		if file.ends_with(".tscn"):
			var scene = load(nature_path + "/" + file) as PackedScene
			if scene:
				nature_components.append(scene)
	print("🌿 Loaded %d nature components" % nature_components.size())

# =========================================================
# 🎯 INIT
# =========================================================
func _ready() -> void:
	print("🏗️ BuildingGenerator ready!")
	if auto_cycle_modes:
		_start_mode_timer()

func init_load() -> void:
	load_buildings()
	load_nature_components()
