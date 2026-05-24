extends Node3D
@onready var red_light: OmniLight3D = $Sprite3D/RedLight
@onready var blue_light: OmniLight3D = $Sprite3D/BlueLight

var police_unit_data = null # Akan diisi oleh Manager
var player: Node3D
var lane_width: float = 2.0 # Sesuaikan dengan jarak antar jalur di jalananmu
@onready var siren_audio = $SirenAudio
@onready var screech_audio = $RemAudio
@export var siren_sounds: Array[AudioStream] = []
var last_state: int = -1
func _ready() -> void:
	# Cari player
	player = get_node_or_null("/root/World/Player")
	
	# Sembunyikan di awal
	visible = false

func set_unit_data(unit_data) -> void:
	police_unit_data = unit_data

func _process(delta: float) -> void:
	if not player or not police_unit_data:
		hide()
		return
	# State 6 = COOLDOWN (Lagi istirahat setelah nabrak/miss)
	# State 7 = INACTIVE (Belum aktif)
	if police_unit_data.state == 6 or police_unit_data.state == 7:
		hide() # Hilangkan mobil dari jalanan 3D
		if red_light and blue_light:
			red_light.visible = false
			blue_light.visible = false
		if siren_audio.playing:
			siren_audio.stop()
		
		return
	show()
	
	if not siren_audio.playing:
		if siren_sounds.size() > 0:
			siren_audio.stream = siren_sounds.pick_random()
		siren_audio.play()
		
	if police_unit_data.state != last_state:
		if police_unit_data.state == 3:
			# Kita acak pitch-nya sedikit biar suaranya nggak monoton
			screech_audio.pitch_scale = randf_range(0.8, 1.2)
			screech_audio.play()
		last_state = police_unit_data.state
		
	# 1. ATUR POSISI X (JALUR KIRI/TENGAH/KANAN)
	var target_x = police_unit_data.lane * lane_width 
	global_position.x = lerp(global_position.x, target_x, 5.0 * delta)
	
	# 2. ATUR POSISI Z (JARAK DARI PEMAIN DARI BELAKANG)
	var z_offset = 30.0 # Jarak dasar (jauh di belakang)
	
	# Mapping state enum ke angka (berdasarkan police_chase_manager.gd)
	match police_unit_data.state:
		7, 0, 1: # INACTIVE, TRAILING, LOCK_ON (Membuntuti)
			z_offset = 15.0 - (police_unit_data.scale_factor * 10.0) 
		2: # CHARGING (Menyeruduk maju)
			z_offset = lerp(15.0, 0.0, police_unit_data.charge_progress)
		3: # PASSING (Melampaui/Miss maju ke depan)
			z_offset = lerp(0.0, -20.0, police_unit_data.pass_progress)
		4, 5: # STALLED (Mogok di depan), RETREATING (Mundur lagi)
			z_offset = lerp(-20.0, 30.0, police_unit_data.retreat_progress)
			
	global_position.z = player.global_position.z + z_offset
	
	if red_light and blue_light:
		var time = Time.get_ticks_msec() / 1000.0
		# Sirine berkedip bergantian cepat saat CHARGING (state 2)
		var flash_speed = 10.0 if police_unit_data.state == 2 else 5.0
		var is_red = sin(time * flash_speed) > 0
		red_light.visible = is_red
		blue_light.visible = not is_red
