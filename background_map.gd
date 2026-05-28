# background_map.gd - FINAL STABLE VERSION
extends Node

@export var BUILDING_ACTIVE_DURATION: float = 3.0  # Kembalikan ke 30 detik
@export var SCENERY_ACTIVE_DURATION: float = 3.0    # Kembalikan ke 10 detik

var _timer: float = 0.0
var _is_building_phase: bool = true
var terrain_controller: Node = null
var building_generator: Node = null

func _ready() -> void:
	# 🔥 PENTING: Tetap update walau game pause (main menu, game over, dll)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	print("🗺️ [BackgroundMap] _ready() | Scene: ", get_tree().current_scene.name)
	
	_find_target_nodes()
	
	if terrain_controller == null or building_generator == null:
		push_error("⚠️ BackgroundMap: Target nodes NOT found!")
		print("   TC: ", terrain_controller, " | BG: ", building_generator)
		return
	
	print("✅ Target nodes found | Starting timer...")
	_apply_current_state()

func _process(delta: float) -> void:
	if terrain_controller == null or building_generator == null:
		return
	
	_timer += delta
	var cycle = BUILDING_ACTIVE_DURATION + SCENERY_ACTIVE_DURATION
	
	# Debug print tiap detik (opsional, bisa dihapus nanti)
	if int(_timer * 10) % 10 == 0 and delta > 0:
		print("⏱️ Timer: %.1fs | Phase: %s" % [_timer, "BUILDING" if _is_building_phase else "SCENERY"])
	
	if _timer >= cycle:
		_timer = 0.0
		_is_building_phase = true
		_apply_current_state()
		print("🔄 CYCLE RESET → BUILDING phase")
		return
		
	if _is_building_phase and _timer >= BUILDING_ACTIVE_DURATION:
		_is_building_phase = false
		_apply_current_state()
		print("🌲 SWITCH → SCENERY phase (%.1fs)" % SCENERY_ACTIVE_DURATION)

func _apply_current_state() -> void:
	if _is_building_phase:
		# BUILDING ON, SCENERY OFF
		_set_prop(building_generator, "_building_always_active", true)
		_set_prop(terrain_controller, "_scenery_always_active", false)
		print("🏢 Phase: BUILDING")
	else:
		# SCENERY ON, BUILDING OFF
		_set_prop(building_generator, "_building_always_active", false)
		_set_prop(terrain_controller, "_scenery_always_active", true)
		print("🌲 Phase: SCENERY")

func _set_prop(target: Node, prop: String, val: bool) -> void:
	if is_instance_valid(target):
		target.set(prop, val)

func _find_target_nodes() -> void:
	# Path absolut (sesuaikan dengan struktur scene Anda)
	terrain_controller = get_node_or_null("/root/World/TerrainController")
	building_generator = get_node_or_null("/root/World/BuildingGenerator")
	
	# Fallback via group
	if not terrain_controller:
		var tc = get_tree().get_nodes_in_group("terrain_controllers")
		if tc.size() > 0: terrain_controller = tc[0]
	if not building_generator:
		var bg = get_tree().get_nodes_in_group("building_generators")
		if bg.size() > 0: building_generator = bg[0]
