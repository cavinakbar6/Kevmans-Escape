extends Node3D

@export var spawn_chance: float = 0.60
@export var spawn_x_range: Vector2 = Vector2(-1, 1)

@export var heal: float = 25

@onready var mesh = $MeshInstance3D
var time_passed: float = 0.0

func _ready() -> void:
	add_to_group("HealObjects")

func _process(delta: float) -> void:
	if is_instance_valid(mesh):
		time_passed += delta
		mesh.rotate_y(3.0 * delta)
		mesh.position.y = 0.8 + sin(time_passed * 5.0) * 0.25

func get_heal() -> float:
	return heal
