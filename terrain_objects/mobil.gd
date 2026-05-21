extends Node3D

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $StaticBody3D/CollisionShape3D
@onready var hitbox: Area3D = $Area3D
@onready var hitbox_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var headlight: Area3D = $Headlight

@export var damage: float = 50.0
@export var spawn_chance: float = 0.5
@export var horn_distance: float = 60.0
@export var trigger_distance: float = 15.0 

var player: Node3D
var has_passed: bool = false
var has_horned: bool = false
var day_night: Node = null

@export var horn_sounds: Array[AudioStream] = []
@export var spawn_x_range: Vector2 = Vector2(-1, 1)

func _ready() -> void:
	add_to_group("ObstacleObjects")
	player = get_node_or_null("/root/World/Player")
	day_night = get_node_or_null("/root/World/DirectionalLight3D")
	var aabb = mesh.get_aabb()
	var size = aabb.size
	var bottom = aabb.position

	# ✅ Collider fisik (StaticBody3D)
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = Vector3(
		bottom.x + size.x / 2.0,
		bottom.y + size.y / 2.0,
		bottom.z + size.z / 2.0
	)

	# ✅ Area trigger (Area3D untuk tabrakan)
	var area_shape = BoxShape3D.new()
	area_shape.size = size
	hitbox_shape.shape = area_shape
	hitbox.position = collision.position
	$SpawnSound.bus = "SFX"

func disable_sounds() -> void:
	if $SpawnSound.playing:
		$SpawnSound.stop()

func get_damage() -> float:
	return damage

func _process(_delta: float) -> void:
	if day_night:
		if day_night.is_daytime():
			headlight.visible = false
		else:
			headlight.visible = true
		
	if player:
		if not has_horned and global_position.z > (player.global_position.z - horn_distance):
			has_horned = true
			var current_time = Time.get_ticks_msec() / 1000.0
			
			if current_time - player.last_horn_sound_time > 1.0:
				if horn_sounds.size() > 0:
					$SpawnSound.stream = horn_sounds.pick_random()
				$SpawnSound.pitch_scale = randf_range(0.9, 1.1)
				$SpawnSound.play()
				player.last_horn_sound_time = current_time
				
		if not has_passed and global_position.z > (player.global_position.z - trigger_distance):
			has_passed = true
			var current_time = Time.get_ticks_msec() / 1000.0
			
			if current_time - player.last_pass_sound_time > 0.8:
				$PassSound.pitch_scale = randf_range(0.85, 1.15) 
				$PassSound.play()
				player.last_pass_sound_time = current_time
