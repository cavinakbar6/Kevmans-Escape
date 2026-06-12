extends Control

@onready var intro_container = $IntroContainer
@onready var image_display = $IntroContainer/ImageDisplay
@onready var black_overlay = $BlackOverlay
@onready var audio_player = $IntroAudio
@onready var disclaimer_overlay = $IntroContainer/DisclaimerOverlay
@onready var delay_label = $IntroContainer/DisclaimerOverlay/VBox/DelayLabel

# Kombinasi gambar (tanpa sound)
var intro_data = [
	"res://INTRO/workinprogress.png",
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
	intro_container.visible = true
	black_overlay.visible = true
	black_overlay.modulate = Color(1, 1, 1, 1)
	can_skip = true
	_play_intro()

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
			
			if data == "res://INTRO/workinprogress.png":
				disclaimer_overlay.visible = true
			else:
				disclaimer_overlay.visible = false
			
			# Fade In image + Fade Out black overlay
			image_display.modulate.a = 1.0
			var tw_in = create_tween()
			tw_in.tween_property(black_overlay, "modulate:a", 0.0, 0.5)
			await tw_in.finished
			
			if not intro_playing: break
			
			# Jika ini gambar disclaimer, hitung mundur 5 detik
			if data == "res://INTRO/workinprogress.png":
				for sec in range(5, 0, -1):
					if not intro_playing: break
					delay_label.text = "Continuing in " + str(sec) + "..."
					await get_tree().create_timer(1.0).timeout
			else:
				# Tampilkan gambar selama durasi intro biasa (3 detik)
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
