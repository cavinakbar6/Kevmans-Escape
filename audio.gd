extends Node3D

# === REFERENSI KE SEMUA PEMUTAR AUDIO & TIMER ===
@onready var engine_sound: AudioStreamPlayer3D = $EngineSound
@onready var gear_shift_sfx: AudioStreamPlayer3D = $GearShiftSFX
@onready var shift_timer: Timer = $ShiftTimer
@onready var tire_screech_sfx: AudioStreamPlayer3D = $TireScreechSFX
@onready var game_over_music: AudioStreamPlayer = $GameOverMusic  # 🎵 Tambahan

@export var screech_min_speed: float = 30.0
@export var engine_ducking_db: float = -12.0 

# === PENGATURAN GIGI / STAGE ===
var gears = [
	{"threshold": 40.0, "min_pitch": 0.8, "max_pitch": 1.8}, # Gigi 1
	{"threshold": 50.0, "min_pitch": 1.2, "max_pitch": 2.0}, # Gigi 2
	{"threshold": 70.0, "min_pitch": 1.5, "max_pitch": 2.1}, # Gigi 3
	{"threshold": 120.0,"min_pitch": 1.8, "max_pitch": 2.5}, # Gigi 4
	{"threshold": 150.0,"min_pitch": 2.2, "max_pitch": 2.9}  # Gigi 5
]
var current_gear_index: int = 0
var is_shifting: bool = false
@export var idle_pitch: float = 0.6


func _ready() -> void:
	add_to_group("audio_players")
	shift_timer.timeout.connect(_on_shift_timer_timeout)
	
	engine_sound.bus = "SFX"
	gear_shift_sfx.bus = "SFX"
	tire_screech_sfx.bus = "SFX"
	game_over_music.bus = "Music"
	

# =============================================================
# UPDATE AUDIO SAAT GAME BERJALAN
# =============================================================
func update_audio(current_speed: float, input_x: float, delta: float, is_game_over: bool):
	if is_game_over:
		stop_all_engine_sounds()
		return

	var is_screeching = _update_tire_screech(current_speed, input_x, delta)
	_update_engine_pitch(current_speed, delta, is_screeching)


# =============================================================
# HENTIKAN SEMUA SUARA MESIN & EFEK
# =============================================================
func stop_all_engine_sounds() -> void:
	if engine_sound.playing:
		engine_sound.stop()
	if gear_shift_sfx.playing:
		gear_shift_sfx.stop()
	if tire_screech_sfx.playing:
		tire_screech_sfx.stop()
	# Setelah semua berhenti, mainkan lagu Game Over
	play_game_over_music()


# =============================================================
# MAINKAN MUSIK GAME OVER
# =============================================================
func play_game_over_music() -> void:
	if not game_over_music.playing:
		game_over_music.play()


# =============================================================
# LOGIKA MESIN & SHIFTING
# =============================================================
func _update_engine_pitch(speed: float, delta: float, is_screeching: bool):
	if current_gear_index < gears.size() - 1 and not is_shifting:
		if speed >= gears[current_gear_index].threshold:
			is_shifting = true
			gear_shift_sfx.stop()
			gear_shift_sfx.play()
			shift_timer.start()
			
	var target_engine_volume = 0.0
	if is_screeching:
		target_engine_volume = engine_ducking_db

	if is_shifting:
		engine_sound.volume_db = move_toward(engine_sound.volume_db, -40, 80 * delta)
	else:
		engine_sound.volume_db = move_toward(engine_sound.volume_db, target_engine_volume, 40 * delta)
		
		var gear_data = gears[current_gear_index]
		var start_speed = 0.0
		if current_gear_index > 0:
			start_speed = gears[current_gear_index - 1].threshold
		var new_pitch = remap(
			speed, start_speed, gear_data.threshold, 
			gear_data.min_pitch, gear_data.max_pitch
		)
		engine_sound.pitch_scale = clamp(new_pitch, gear_data.min_pitch, gear_data.max_pitch)


func _on_shift_timer_timeout():
	if current_gear_index < gears.size() - 1:
		current_gear_index += 1
	is_shifting = false


func _update_tire_screech(current_speed: float, input_x: float, delta: float) -> bool:
	var fade_speed = 80.0 
	
	if abs(input_x) > 0.6 and current_speed >= screech_min_speed:
		tire_screech_sfx.volume_db = move_toward(tire_screech_sfx.volume_db, -25.0, fade_speed * delta)
		return true
	else:
		tire_screech_sfx.volume_db = move_toward(tire_screech_sfx.volume_db, -80, fade_speed * delta)
		return false
