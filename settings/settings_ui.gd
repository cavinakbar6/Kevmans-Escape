extends Control

signal back_pressed

@onready var master_slider = $Panel/VBoxContainer/MasterSlider
@onready var sfx_slider = $Panel/VBoxContainer/SFXSlider
@onready var music_slider = $Panel/VBoxContainer/MusicSlider
@onready var fullscreen_check = $Panel/VBoxContainer/FullscreenCheck
@onready var back_button = $Panel/VBoxContainer/BackButton

func _ready() -> void:
	master_slider.value = Settings.master_volume
	sfx_slider.value = Settings.sfx_volume
	music_slider.value = Settings.music_volume
	fullscreen_check.button_pressed = Settings.is_fullscreen
	
	master_slider.value_changed.connect(_on_master_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	music_slider.value_changed.connect(_on_music_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(_on_back_pressed)

func _on_master_changed(value: float) -> void:
	Settings.master_volume = value
	Settings.apply_audio_volumes()

func _on_sfx_changed(value: float) -> void:
	Settings.sfx_volume = value
	Settings.apply_audio_volumes()

func _on_music_changed(value: float) -> void:
	Settings.music_volume = value
	Settings.apply_audio_volumes()

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	Settings.is_fullscreen = button_pressed
	Settings.apply_fullscreen()

func _on_back_pressed() -> void:
	Settings.save_settings()
	back_pressed.emit()
