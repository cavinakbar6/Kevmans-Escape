extends Node3D

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $StaticBody3D/CollisionShape3D
@onready var hitbox: Area3D = $Area3D
@onready var hitbox_shape: CollisionShape3D = $Area3D/CollisionShape3D

@onready var damage: float = 10.0

@export var spawn_chance: float = 0.5
@export var spawn_x_range: Vector2 = Vector2(-1, 1)

var player: Node3D
var has_played_sound: bool = false

@export var trigger_distance: float = 15.0 
@export var horn_distance: float = 60.0

func _ready() -> void:
	player = get_node_or_null("/root/World/Player")
	add_to_group("audio_players")
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
	add_to_group("ObstacleObjects")
	print("grandma spawned")
	
func _process(_delta: float) -> void:
	if player and not has_played_sound:
		# Jika posisi nenek sudah masuk ke batas jarak dengan player
		if global_position.z > (player.global_position.z - trigger_distance):
			has_played_sound = true # Kunci biar nggak bunyi berkali-kali di setiap frame
			
			$SpawnSound.pitch_scale = randf_range(0.9, 1.1) # Biar suaranya sedikit bervariasi
			$SpawnSound.play()
				
func disable_sounds() -> void:
	if $SpawnSound.playing:
		$SpawnSound.stop()
	if $PassSound.has_method("stop") and $PassSound.playing:
		$PassSound.stop()

func get_damage() -> float:
	return damage
