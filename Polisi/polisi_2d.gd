extends Area3D

@onready var red_light: OmniLight3D = $Sprite3D/RedLight
@onready var blue_light: OmniLight3D = $Sprite3D/BlueLight
@export var tex_normal_back: Texture2D
@export var tex_heavy_back: Texture2D
@onready var sprite = $Sprite3D

var police_unit_data = null
var player: Node3D
var lane_width: float = 2.0

@onready var siren_audio = $SirenAudio
@onready var screech_audio = $RemAudio
@onready var mesin_audio = $MesinAudio
@export var siren_sounds: Array[AudioStream] = []

var last_state: int = -1
var crash_z_offset: float = -15.0 # Variabel untuk menyimpan titik tabrakan

func _ready() -> void:
	player = get_node_or_null("/root/World/Player")
	visible = false

func set_unit_data(unit_data) -> void:
	police_unit_data = unit_data
	if police_unit_data.type == 1:
		if tex_heavy_back:
			sprite.texture = tex_heavy_back
	else:
		if tex_normal_back:
			sprite.texture = tex_normal_back
			
func _process(delta: float) -> void:
	if not player or not police_unit_data:
		hide()
		return
		
	if police_unit_data.state == 6 or police_unit_data.state == 7:
		hide()
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
			screech_audio.pitch_scale = randf_range(0.8, 1.2)
			screech_audio.play()
			
			# Kalau cuma meleset (nggak nabrak), mulai dari -45.0
			crash_z_offset = -15.0 
			
		last_state = police_unit_data.state
		
	# ATUR POSISI X
	var target_x = police_unit_data.lane * lane_width 
	global_position.x = lerp(global_position.x, target_x, 5.0 * delta)
	
	# ATUR POSISI Z
	var z_offset = 30.0
	var target_pitch: float = 1.0
	
	match police_unit_data.state:
		7, 0, 1: 
			z_offset = 15.0 - (police_unit_data.scale_factor * 10.0) 
			target_pitch = 1.0 + (police_unit_data.scale_factor * 0.2)
		2: 
			z_offset = lerp(15.0, 0.0, police_unit_data.charge_progress)
			target_pitch = lerp(1.1, 1.6, police_unit_data.charge_progress)
		3: 
			# Diperjauh ke depan kabut (-45.0)
			z_offset = lerp(0.0, -15.0, police_unit_data.pass_progress)
			target_pitch = lerp(1.6, 0.6, police_unit_data.pass_progress)
		4: 
			crash_z_offset -= 15.0 * delta 
			z_offset = crash_z_offset
			target_pitch = 0.8
			
		5: 
			# RETREATING: Kalau sukses nabrak truk, baru mental mundur ke belakang
			z_offset = lerp(crash_z_offset, 35.0, police_unit_data.retreat_progress)
			target_pitch = 0.8
	if mesin_audio.playing:
		mesin_audio.pitch_scale = lerp(mesin_audio.pitch_scale, target_pitch, 10.0 * delta)
	global_position.z = player.global_position.z + z_offset
	
	if red_light and blue_light:
		var time = Time.get_ticks_msec() / 1000.0
		var flash_speed = 10.0 if police_unit_data.state == 2 else 5.0
		var is_red = sin(time * flash_speed) > 0
		red_light.visible = is_red
		blue_light.visible = not is_red

	# SISTEM ANTI-LOOPING TABRAKAN
	if police_unit_data.state == 5:
		if monitoring == true:
			set_deferred("monitoring", false)
	else:
		if monitoring == false:
			set_deferred("monitoring", true)

func _on_body_entered(body: Node3D) -> void:
	var induk = body.get_parent()
	var is_obstacle = false
	
	if body.is_in_group("obstacle") or body.is_in_group("rintangan") or body.is_in_group("ObstacleObjects"):
		is_obstacle = true
	elif induk and (induk.is_in_group("obstacle") or induk.is_in_group("rintangan") or induk.is_in_group("ObstacleObjects")):
		is_obstacle = true
		
	if is_obstacle:
		# Hanya bisa nabrak saat meleset(3) atau mogok di depan(4)
		if police_unit_data and (police_unit_data.state == 3 or police_unit_data.state == 4):
			if has_node("NabrakAudio") and $NabrakAudio.stream:
				$NabrakAudio.play()
			
			# CATAT LOKASI PERSIS SAAT DIA NABRAK!
			crash_z_offset = global_position.z - player.global_position.z
			
			police_unit_data.state = 5
			police_unit_data.retreat_progress = 0.0
