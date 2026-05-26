extends CanvasLayer

@onready var color_rect = $ColorRect
@onready var resume_btn = $ColorRect/VBoxContainer/ResumeButton
@onready var settings_btn = $ColorRect/VBoxContainer/SettingsButton
@onready var restart_btn = $ColorRect/VBoxContainer/RestartButton
@onready var menu_btn = $ColorRect/VBoxContainer/MenuButton
@onready var settings_ui = $SettingsUI

func _ready() -> void:
	color_rect.visible = false
	settings_ui.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	resume_btn.pressed.connect(_on_resume_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	settings_ui.back_pressed.connect(_on_settings_back)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var player = get_node_or_null("/root/World/Player")
		if player and player.is_game_started and not player.game_is_over:
			toggle_pause()

func toggle_pause() -> void:
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	color_rect.visible = new_pause_state
	settings_ui.visible = false

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_settings_pressed() -> void:
	color_rect.visible = false
	settings_ui.visible = true

func _on_settings_back() -> void:
	settings_ui.visible = false
	color_rect.visible = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	var player = get_node_or_null("/root/World/Player")
	if player:
		player._on_restart_game()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	var player = get_node_or_null("/root/World/Player")
	if player:
		player._on_main_menu_button_pressed()
