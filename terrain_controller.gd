# terrain_controller.gd - LEGACY VERSION
# Original system with BuildingGenerator + Scenery (pre-MapBackground integration)
extends Node3D
class_name TerrainController
 
## Holds the catalog of loaded terrain block and object scenes
@export var TerrainBlocks: Array[PackedScene] = []
@export var TerrainObjects: Array[PackedScene] = []
@export var TerrainScenery: Array[PackedScene] = []  # ✅ LEGACY: Scenery scenes array
 
## The set of terrain blocks and active obstacles in the viewport
var terrain_belt: Array[Node3D] = []
var active_obstacles: Array[Node3D] = []
var active_scenery: Array[Node3D] = []  # ✅ LEGACY: Active scenery tracking
 
## Flag to check if the game has ended
var game_over: bool = false
 
# =============================================================
# FITUR AKSELERASI
# =============================================================
@export var initial_velocity: float = 30.0
@export var max_velocity: float = 40.0
@export var acceleration: float = 0.75
var terrain_velocity: float = 0.0
 
# === PENGATURAN DARI SKRIP KEDUA ===
@export var object_spawn_chance: float = 0.25
@export var num_terrain_blocks = 10

signal game_over_signal 

# =============================================================
# PENGATURAN KEMUNCULAN RINTANGAN DINAMIS
# =============================================================
var spawn_timer: float = 0.0
var spawn_interval: float = 2.0
var elapsed_time: float = 0.0
const MAX_GAME_TIME: float = 600.0
const MIN_SPAWN_CHANCE: float = 0.5
const MAX_SPAWN_CHANCE: float = 1.0
var allow_spawn: bool = false

# =============================================================
# PENGATURAN SCENERY (LEGACY - FIXED SETTER)
# =============================================================
@export var scenery_spawn_chance: float = 1.0
@export var scenery_min_distance: float = 500.0
@export var scenery_max_distance: float = 1000.0
@export var scenery_side_offset: float = 9.0
@export var scenery_x_max_distance: float = 50.0
@export var scenery_multiplier: float = 100.0

# ✅ Variabel internal dengan setter function
var _scenery_always_active: bool = false : set = _on_scenery_active_changed

# Export dummy agar bisa dilihat di Inspector (opsional)
@export var scenery_always_active_inspector: bool:
	set(value): _scenery_always_active = value
	get: return _scenery_always_active

signal scenery_active_changed(is_active: bool)

# ✅ Setter function (WAJIB: satu parameter, nama sesuai deklarasi)
func _on_scenery_active_changed(value: bool) -> void:
	_scenery_always_active = value
	scenery_active_changed.emit(value)
	_update_scenery_logic(value)

func _update_scenery_logic(is_active: bool) -> void:
	if is_active:
		_resume_scenery_spawning()
	else:
		_pause_scenery_spawning()

func _pause_scenery_spawning() -> void:
	print("🌲 Scenery spawning: PAUSED")

func _resume_scenery_spawning() -> void:
	print("🌲 Scenery spawning: RESUMED")

# =============================================================
# BUILDING GENERATOR REFERENCE (LEGACY)
# =============================================================
@export var building_generator: BuildingGenerator  # ✅ LEGACY: Reference ke BuildingGenerator

# Cache spawn_chance
var _spawn_chance_cache: Dictionary = {}

# =============================================================
# LIFECYCLE
# =============================================================
func _ready() -> void:
	game_over = false
	terrain_velocity = initial_velocity
	
	_load_terrain_scenes("res://terrain_objects", TerrainObjects)
	_load_scenery_scenes("res://terrain_scenery", TerrainScenery)  # ✅ LEGACY: Load scenery scenes
	print("TerrainObjects size:", TerrainObjects.size())
	print("TerrainScenery size:", TerrainScenery.size())
	
	if building_generator:  # ✅ LEGACY: Load buildings via BuildingGenerator
		building_generator.init_load()
	
	_cache_spawn_chances()
	_init_blocks(num_terrain_blocks)

func _physics_process(delta: float) -> void:
	if game_over:
		return
	
	if not allow_spawn:
		if building_generator:  # ✅ LEGACY: Update buildings even when spawn disabled
			building_generator.update_buildings(delta, 0.0)
		return
	
	# LOGIKA AKSELERASI
	if terrain_velocity < max_velocity:
		terrain_velocity += acceleration * delta
	terrain_velocity = clamp(terrain_velocity, 0, max_velocity)
	
	elapsed_time += delta
	var progress = clamp(elapsed_time / MAX_GAME_TIME, 0.1, 1.0)
	object_spawn_chance = lerp(MIN_SPAWN_CHANCE, MAX_SPAWN_CHANCE, progress)
	
	_progress_terrain(delta)
	_progress_obstacles(delta)
	_progress_scenery(delta)  # ✅ LEGACY: Update scenery movement
	
	if building_generator:  # ✅ LEGACY: Update buildings with terrain velocity
		building_generator.update_buildings(delta, terrain_velocity)
	
	if Input.is_action_just_pressed("toggle_map_mode"):
		building_generator.toggle_mode()

func enable_spawning() -> void:
	allow_spawn = true

func _trigger_game_over() -> void:
	if game_over: return
	game_over = true
	terrain_velocity = 0.0

	var audio = get_node_or_null("/root/World/Audio")
	if audio and audio.has_method("stop_all_engine_sounds"):
		audio.stop_all_engine_sounds()

	emit_signal("game_over_signal") 

	var player = get_node_or_null("/root/World/Player")
	if player and not player.game_is_over:
		player.show_game_over_ui()
 
# ======================================================================
# FUNGSI LOGIKA
# ======================================================================
 
func _progress_obstacles(delta: float) -> void:
	for obstacle in active_obstacles:
		if not is_instance_valid(obstacle): continue
		obstacle.position.z += terrain_velocity * delta
		if obstacle.position.z > 30.0:
			obstacle.queue_free()
			continue
	active_obstacles = active_obstacles.filter(is_instance_valid)

# ✅ LEGACY: Progress scenery movement
func _progress_scenery(delta: float) -> void:
	for tree in active_scenery:
		if not is_instance_valid(tree): continue
		tree.position.z += terrain_velocity * delta
		if tree.position.z > 30.0:
			tree.queue_free()
	active_scenery = active_scenery.filter(is_instance_valid)

func _pick_random_block() -> PackedScene:
	return TerrainBlocks.pick_random()

func _cache_spawn_chances() -> void:
	for obj_scene in TerrainObjects:
		var obj = obj_scene.instantiate()
		_spawn_chance_cache[obj_scene] = obj.spawn_chance
		obj.queue_free()

func _pick_random_object() -> PackedScene:
	var candidates: Array = []
	for obj_scene in TerrainObjects:
		var chance = _spawn_chance_cache.get(obj_scene, 0.5)
		if randf() < chance:
			candidates.append(obj_scene)
	if candidates.is_empty(): return null
	return candidates.pick_random()

# ======================================================================
# INIT BLOCKS
# ======================================================================
func _init_blocks(number_of_blocks: int) -> void:
	for block_index in range(number_of_blocks):
		var block = _pick_random_block().instantiate()
		if block_index == 0:
			block.position.z = 0
		else:
			_append_to_far_edge(terrain_belt[block_index - 1], block)
		add_child(block)
		terrain_belt.append(block)
		
		if allow_spawn and randf() < object_spawn_chance:
			_spawn_object_on_block(block)
		
		# ✅ LEGACY: Spawn scenery on block
		for i in range(scenery_multiplier):
			if _scenery_always_active and randf() < scenery_spawn_chance:
				_spawn_scenery(block)
		
		# ✅ LEGACY: Spawn buildings via BuildingGenerator
		if building_generator and not block.has_meta("has_building"):
			building_generator.spawn_buildings_on_block(block)
			block.set_meta("has_building", true)

# ======================================================================
# PROGRESS TERRAIN
# ======================================================================
func _progress_terrain(delta: float) -> void:
	for block in terrain_belt:
		block.position.z += terrain_velocity * delta
 
	if terrain_belt.is_empty(): return
 
	if terrain_belt[0].position.z >= get_block_length(terrain_belt[0]):
		var last_terrain = terrain_belt[-1]
		var first_terrain = terrain_belt.pop_front()
 
		var block = _pick_random_block().instantiate()
		_append_to_far_edge(last_terrain, block)
		add_child(block)
		terrain_belt.append(block)
		first_terrain.queue_free()
		
		if allow_spawn and randf() < object_spawn_chance:
			_spawn_object_on_block(block)
		
		# ✅ LEGACY: Spawn scenery on new block
		for i in range(scenery_multiplier):
			if _scenery_always_active and randf() < scenery_spawn_chance:
				_spawn_scenery(block)
				
		# ✅ LEGACY: Spawn buildings on new block
		if building_generator and not block.has_meta("has_building"):
			building_generator.spawn_buildings_on_block(block)
			block.set_meta("has_building", true)

# ======================================================================
# UTILITY FUNCTIONS
# ======================================================================
func get_block_length(block: Node3D) -> float:
	var mesh_instance := block.get_node_or_null("MeshInstance3D")
	if mesh_instance == null:
		mesh_instance = block.find_child("*", true, false) as MeshInstance3D
		if mesh_instance == null:
			push_error("No MeshInstance3D found in block: " + str(block.name))
			return 0.0
	var aabb = mesh_instance.mesh.get_aabb()
	return aabb.size.z * mesh_instance.scale.z

func _append_to_far_edge(target_block: Node3D, appending_block: Node3D) -> void:
	var target_len = get_block_length(target_block)
	appending_block.position.z = target_block.position.z - target_len

func _spawn_object_on_block(block: Node3D) -> void:
	var obj_scene = _pick_random_object()
	if obj_scene == null: return
 
	var obj = obj_scene.instantiate()
	var mesh_instance: MeshInstance3D = block.get_node_or_null("MeshInstance3D")
	if mesh_instance == null:
		mesh_instance = block.find_child("*", true, false) as MeshInstance3D
		if mesh_instance == null:
			push_error("No MeshInstance3D found in block: " + str(block.name))
			return
 
	var aabb_block = mesh_instance.mesh.get_aabb()
	var width = aabb_block.size.x * mesh_instance.scale.x
	var length = aabb_block.size.z * mesh_instance.scale.z
 
	var spawn_x_range: Vector2 = obj.spawn_x_range
	var half_width = width / 2.0
	var min_x = lerp(-half_width, half_width, (spawn_x_range.x + 1.0) / 2.0)
	var max_x = lerp(-half_width, half_width, (spawn_x_range.y + 1.0) / 2.0)
 
	obj.position = block.position
	obj.position.x += randf_range(min_x, max_x)
	obj.position.z -= length / 2.0
 
	add_child(obj)
	active_obstacles.append(obj)

# ✅ LEGACY: Spawn scenery function (original implementation)
func _spawn_scenery(block: Node3D) -> void:
	if TerrainScenery.is_empty(): return
	var scene = TerrainScenery.pick_random()
	var tree = scene.instantiate()

	var center_x = block.position.x
	var side = 1 if randf() > 0.5 else -1
	var x_offset = (scenery_side_offset + randf_range(0.0, scenery_x_max_distance)) * side
	
	var block_length = get_block_length(block)
	if block_length == 0.0: block_length = 100.0
		
	var z_offset = -randf_range(0.0, block_length)

	tree.position = Vector3(center_x + x_offset, 0.0, block.position.z + z_offset)

	add_child(tree)
	active_scenery.append(tree)

# ✅ LEGACY: Load terrain scenes
func _load_terrain_scenes(target_path: String, target_array: Array) -> void:
	var dir = DirAccess.open(target_path)
	if dir == null:
		push_error("Could not open directory: " + target_path)
		return
	for scene_path in dir.get_files():
		if scene_path.ends_with(".tscn"):
			target_array.append(load(target_path + "/" + scene_path))

# ✅ LEGACY: Load scenery scenes
func _load_scenery_scenes(target_path: String, target_array: Array) -> void:
	var dir = DirAccess.open(target_path)
	if dir == null:
		push_error("Could not open scenery directory: " + target_path)
		return
	for scene_path in dir.get_files():
		if scene_path.ends_with(".tscn"):
			target_array.append(load(target_path + "/" + scene_path))
