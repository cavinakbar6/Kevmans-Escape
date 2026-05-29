extends Camera3D

@onready var dashboard_layer: CanvasLayer = get_node("/root/World/DashboardLayer")

@export var shake_decay: float = 5.0
var shake_strength: float = 0.0
var default_pos: Vector3

func _ready() -> void:
	# Simpan posisi asli kamera agar tidak rusak
	default_pos = position

func _process(delta: float) -> void:
	if shake_strength > 0.0:
		dashboard_layer.on_camera_shake(shake_strength)
		# Kurangi kekuatan secara perlahan
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		
		# Goyangkan posisi secara acak (Kiri-Kanan, Atas-Bawah)
		position.x = default_pos.x + randf_range(-shake_strength, shake_strength)
		position.y = default_pos.y + randf_range(-shake_strength, shake_strength)
	
	else:
		# Kembalikan ke posisi awal
		position = default_pos
		dashboard_layer.on_camera_shake(0.0)

# Fungsi penerima sinyal dari mobil
func add_shake(amount: float) -> void:
	shake_strength = amount
	
