extends Control

@onready var settings_ui = $SettingsUI
@onready var high_score_label = $HighScoreLabel

func _ready() -> void:
	# Hubungkan sinyal button
	$PlayButton.pressed.connect(_on_play_pressed)
	$ExitButton.pressed.connect(_on_exit_pressed)
	$SettingsButton.pressed.connect(_on_settings_pressed)
	settings_ui.back_pressed.connect(_on_settings_back)
	
	# Tampilkan High Score
	_update_high_score_display()

func _update_high_score_display() -> void:
	if is_instance_valid(high_score_label):
		var hs = HighScoreManager.get_high_score()
		if hs > 0:
			high_score_label.text = "🏆 HIGH SCORE: %d" % hs
			high_score_label.visible = true
		else:
			high_score_label.text = ""
			high_score_label.visible = false

# Kalau tombol Play ditekan
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://world.tscn")

func _on_settings_pressed() -> void:
	settings_ui.visible = true

func _on_settings_back() -> void:
	settings_ui.visible = false

# Kalau tombol Exit ditekan
func _on_exit_pressed() -> void:
	get_tree().quit()
