extends Node3D

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $StaticBody3D/CollisionShape3D
@onready var hitbox: Area3D = $Area3D
@onready var hitbox_shape: CollisionShape3D = $Area3D/CollisionShape3D

@export var damage: float = 50.0

@export var spawn_chance: float = 0.5
@export var spawn_x_range: Vector2 = Vector2(-1, 1)

func _ready() -> void:
	add_to_group("audio_players")
	add_to_group("ObstacleObjects")
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
	$SpawnSound.play()

func disable_sounds() -> void:
	if $SpawnSound.playing:
		$SpawnSound.stop()

func get_damage() -> float:
	return damage
