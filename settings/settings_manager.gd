extends Node

var config := ConfigFile.new()
var save_path := "user://settings.cfg"

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var is_fullscreen: bool = false

@onready var master_bus = AudioServer.get_bus_index("Master")
var sfx_bus
var music_bus

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	load_settings()

func _setup_audio_buses():
	sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus == -1:
		AudioServer.add_bus()
		sfx_bus = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_bus, "SFX")
		
	music_bus = AudioServer.get_bus_index("Music")
	if music_bus == -1:
		AudioServer.add_bus()
		music_bus = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_bus, "Music")

func apply_audio_volumes():
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(master_volume))
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume))
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume))

func apply_fullscreen():
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func save_settings() -> void:
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("display", "fullscreen", is_fullscreen)
	config.save(save_path)
	
	apply_audio_volumes()
	apply_fullscreen()

func load_settings() -> void:
	if config.load(save_path) == OK:
		master_volume = config.get_value("audio", "master", 1.0)
		sfx_volume = config.get_value("audio", "sfx", 1.0)
		music_volume = config.get_value("audio", "music", 1.0)
		is_fullscreen = config.get_value("display", "fullscreen", false)
	
	apply_audio_volumes()
	apply_fullscreen()
