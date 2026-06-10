class_name ObstacleObject
extends Node3D

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $StaticBody3D/CollisionShape3D
@onready var headlight: Area3D = $Headlight

@export var damage: float = 60.0
@export var spawn_chance: float = 0.5
@export var spawn_x_range: Vector2 = Vector2(-1, 1)

var object_width: float = 2.0

@export var trigger_distance: float = 15.0 
@export var horn_distance: float = 60.0

var has_horned: bool = false
var player: Node3D
var has_passed: bool = false
var day_night: Node = null

@onready var object_name = scene_file_path.get_file().get_basename() #ambil nama objek dari scene
@onready var spawn_message = object_name + " spawned"
@onready var incoming_damage_message = "damage coming from " + object_name

func _ready() -> void:
	add_to_group("ObstacleObjects")
	player = get_node_or_null("/root/World/Player")
	day_night = get_node_or_null("/root/World/DirectionalLight3D")

	var aabb = mesh.get_aabb()
	var size = aabb.size
	object_width = size.x
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
		
		if not has_horned and is_overlapping_x and global_position.z > (player.global_position.z - horn_distance):
			has_horned = true
			var current_time = Time.get_ticks_msec() / 1000.0
			
			if current_time - player.last_horn_sound_time > 1.0:
				$HornSound.pitch_scale = randf_range(0.9, 1.1)
				$HornSound.play()
				player.last_horn_sound_time = current_time
	
		if not has_passed and global_position.z > (player.global_position.z - trigger_distance):
			has_passed = true
			var current_time = Time.get_ticks_msec() / 1000.0
			
			if current_time - player.last_pass_sound_time > 0.6:
				$PassSound.pitch_scale = randf_range(0.85, 1.15) 
				$PassSound.play()
				player.last_pass_sound_time = current_time
	
	if day_night:
		if day_night.is_daytime():
			headlight.visible = false
		else:
			headlight.visible = true

func disable_sounds() -> void:
	if $HornSound.playing:
		$HornSound.stop()
	if $PassSound.has_method("stop") and $PassSound.playing:
		$PassSound.stop()

func get_damage() -> float:
	#print(incoming_damage_message)
	return damage
