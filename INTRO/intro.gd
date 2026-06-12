extends Control

@onready var skip_dialog = $SkipDialog
@onready var intro_container = $IntroContainer
@onready var image_display = $IntroContainer/ImageDisplay
@onready var black_overlay = $BlackOverlay
@onready var audio_player = $IntroAudio

# Kombinasi gambar (tanpa sound)
var intro_data = [
	"res://INTRO/Gambar 1.png",
	"res://INTRO/Gambar 2.png",
	"res://INTRO/Gambar 3.png",
	"res://INTRO/Gambar 4.png",
	"res://INTRO/Gambar 5.jpeg",
	"res://INTRO/Gambar 6.png",
	"res://INTRO/Gambar 7.png",
	"res://INTRO/Gambar 8.png",
	"res://INTRO/Gambar 9.png"
]

var intro_playing = false
var can_skip = false

func _ready() -> void:
	intro_container.visible = false
	black_overlay.visible = true
	black_overlay.modulate = Color(1, 1, 1, 0)
	skip_dialog.visible = true

func _on_watch_intro_pressed() -> void:
	skip_dialog.visible = false
	
	# Fade to black sebelum mulai intro
	var tw = create_tween()
	tw.tween_property(black_overlay, "modulate:a", 1.0, 0.5)
	await tw.finished
	
	intro_container.visible = true
	can_skip = true
	_play_intro()

func _on_skip_intro_pressed() -> void:
	_start_game()

func _input(event: InputEvent) -> void:
	if can_skip and event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			can_skip = false
			_start_game()

func _play_intro() -> void:
	intro_playing = true
	
	for data in intro_data:
		if not intro_playing:
			break
		
		var tex = load(data)
		if tex:
			image_display.texture = tex
			
			# Fade In image + Fade Out black overlay
			image_display.modulate.a = 1.0
			var tw_in = create_tween()
			tw_in.tween_property(black_overlay, "modulate:a", 0.0, 0.5)
			await tw_in.finished
			
			if not intro_playing: break
			
			# Tampilkan gambar selama durasi intro (3 detik)
			await get_tree().create_timer(3.0).timeout
			
			if not intro_playing: break
			
			# Fade out to black overlay
			var tw_out = create_tween()
			tw_out.tween_property(black_overlay, "modulate:a", 1.0, 0.5)
			await tw_out.finished
	
	if intro_playing:
		_start_game()

func _start_game() -> void:
	intro_playing = false
	can_skip = false
	get_tree().change_scene_to_file("res://world.tscn")
