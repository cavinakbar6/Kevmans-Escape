class_name BuildingObject
extends Node3D

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var object_name = scene_file_path.get_file().get_basename()

var size: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Tetap hitung size untuk keperluan lain jika dibutuhkan
	_update_size()

func _update_size() -> void:
	if not mesh:
		for child in get_children():
			if child is MeshInstance3D:
				mesh = child
				break

	# Proses kalkulasi ukuran
	if mesh and mesh.mesh:
		var r_aabb = mesh.mesh.get_aabb()
		size = r_aabb.size
	
		# Kalikan dengan scale lokal mesh agar ukurannya akurat jika mesh-nya di-scale di inspector
		size.x *= abs(mesh.scale.x)
		size.y *= abs(mesh.scale.y)
		size.z *= abs(mesh.scale.z)
	else:
		# Fallback jika struktur node sangat kompleks / tidak punya MeshInstance3D langsung
		push_warning("⚠️ " + str(object_name) + " tidak menemukan MeshInstance3D aktif!")
		size = Vector3(2.0, 2.0, 6.0) # Berikan nilai default (misal panjang Z = 6.0) agar game tidak macet

func get_length() -> float:
	_update_size()
	
	var length = size.x
	#print("{0} length: {1}".format([object_name, length]))
	return length
