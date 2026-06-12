class_name ObstacleObject
extends Node3D

# 1. GUNAKAN get_node_or_null AGAR TIDAK CRASH KALAU NODENYA NGGAK ADA
@onready var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var collision: CollisionShape3D = get_node_or_null("StaticBody3D/CollisionShape3D")
@onready var headlight: Area3D = get_node_or_null("Headlight")

@export var damage: float = 60.0
@export var spawn_chance: float = 0.5
@export var spawn_x_range: Vector2 = Vector2(-1, 1)

@export var counter_flow_speed: float = 0.0
var object_width: float = 0.0

@export var trigger_distance: float = 15.0 
@export var horn_distance: float = 60.0

var has_horned: bool = false
var player: Node3D
var has_passed: bool = false
var day_night: Node = null
var is_counter_flow: bool = false

@onready var object_name = scene_file_path.get_file().get_basename()
@onready var spawn_message = object_name + " spawned"
@onready var incoming_damage_message = "damage coming from " + object_name

func _ready() -> void:
	add_to_group("ObstacleObjects")
	player = get_node_or_null("/root/World/Player")
	day_night = get_node_or_null("/root/World/DirectionalLight3D")

	# 2. CARI MESH ALTERNATIF KALAU NAMANYA BUKAN "MeshInstance3D"
	if mesh == null:
		mesh = find_child("*", true, false) as MeshInstance3D

	if mesh and collision:
		var aabb = mesh.get_aabb()
		var size = aabb.size
		# Kalikan dengan skala agar akurat
		object_width = size.x * abs(mesh.scale.x) 
		var bottom = aabb.position
		
		var shape = BoxShape3D.new()
		shape.size = size

	collision.shape = shape
	collision.position = Vector3(
		bottom.x + size.x / 2.0,
		bottom.y + size.y / 2.0,
		bottom.z + size.z / 2.0
	)
	
	#print(spawn_message)

func _process(_delta: float) -> void:
	if player:
		var object_left = global_position.x - (object_width / 2.0)
		var object_right = global_position.x + (object_width / 2.0)
		
		var player_width = 2.0 
		var player_left = player.global_position.x - (player_width / 2.0)
		var player_right = player.global_position.x + (player_width / 2.0)
		
		var is_overlapping_x = object_left < player_right and object_right > player_left
		
		# 3. CEK EKSISTENSI KLAKSON SEBELUM DIBUNYIKAN
		if not has_horned and is_overlapping_x and global_position.z > (player.global_position.z - horn_distance):
			has_horned = true
			var current_time = Time.get_ticks_msec() / 1000.0
			
			if current_time - player.last_horn_sound_time > 1.0:
				var horn = get_node_or_null("HornSound")
				if horn:
					horn.pitch_scale = randf_range(0.9, 1.1)
					horn.play()
					player.last_horn_sound_time = current_time
	
		# 4. CEK EKSISTENSI SUARA LEWAT (PASS SOUND)
		if not has_passed and global_position.z > (player.global_position.z - trigger_distance):
			has_passed = true
			var current_time = Time.get_ticks_msec() / 1000.0
			
			if current_time - player.last_pass_sound_time > 0.6:
				var pass_sound = get_node_or_null("PassSound")
				if pass_sound:
					pass_sound.pitch_scale = randf_range(0.85, 1.15) 
					pass_sound.play()
					player.last_pass_sound_time = current_time
	
	# 5. CEK LAMPU DEPAN (TIDAK SEMUA RINTANGAN PUNYA LAMPU)
	if day_night and headlight:
		if day_night.has_method("is_daytime"):
			headlight.visible = not day_night.is_daytime()

func _physics_process(delta: float) -> void:
	if is_counter_flow:
		global_position.z -= delta * counter_flow_speed

func disable_sounds() -> void:
	var horn = get_node_or_null("HornSound")
	if horn and horn.playing:
		horn.stop()
		
	var pass_sound = get_node_or_null("PassSound")
	if pass_sound and pass_sound.has_method("stop") and pass_sound.playing:
		pass_sound.stop()

func get_damage() -> float:
	return damage

func get_counter_flow_bool() -> bool:
	if counter_flow_speed: return true
	else: return false

func set_backside_texture() -> void:
	front_texture.visible = false
	back_texture.visible = true
