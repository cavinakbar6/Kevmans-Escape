extends CanvasLayer

@onready var title_label = $Panel/VBox/TitleLabel
@onready var desc_label = $Panel/VBox/DescLabel

func _ready() -> void:
	visible = false

func show_tutorial(title: String, desc: String) -> void:
	title_label.text = title
	desc_label.text = desc
	visible = true
	get_tree().paused = true

func _on_ok_button_pressed() -> void:
	visible = false
	get_tree().paused = false
