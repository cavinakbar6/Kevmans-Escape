extends CanvasLayer

# Tracker Bar nodes
@onready var star_container = $MarginContainer/VBoxContainer/StarsHBox
@onready var tracker_container = $TrackerContainer
@onready var police_icon = $TrackerContainer/PoliceIcon
@onready var sirene_red = $TrackerContainer/PoliceIcon/SireneRed
@onready var sirene_blue = $TrackerContainer/PoliceIcon/SireneBlue

# Vignette overlay
@onready var vignette = $VignetteOverlay

# Emergency strip
@onready var emergency_strip = $EmergencyStrip
@onready var strip_border = $EmergencyStrip/StripBorderTop
@onready var scroll_label = $EmergencyStrip/ScrollLabel

# Heartbeat overlay
@onready var heartbeat_overlay = $HeartbeatOverlay

# Radio chatter
@onready var radio_label = $RadioChatter

# BUSTED overlay
@onready var busted_overlay = $BustedOverlay
@onready var busted_text = $BustedText
@onready var busted_subtext = $BustedSubtext
@onready var busted_buttons = $BustedButtons
@onready var retry_button = $BustedButtons/RetryButton
@onready var main_menu_button = $BustedButtons/MainMenuButton

var max_stars = 6
var current_stars = 0
var time_passed = 0.0
var target_police_x = 10.0
var scroll_offset = 0.0
var is_busted = false

# Camera shake
var shake_intensity = 0.0
var camera_ref: Camera3D = null

# Radio chatter system
var radio_timer = 0.0
var radio_display_timer = 0.0
var radio_messages = [
	"UNIT 4: VISUAL CONFIRMED ON SUSPECT",
	"DISPATCH: ALL UNITS CONVERGE",
	"UNIT 7: SUSPECT HEADING NORTH",
	"UNIT 2: REQUESTING BACKUP",
	"DISPATCH: SPIKE STRIPS AUTHORIZED",
	"UNIT 9: IN PURSUIT - HIGH SPEED",
	"UNIT 3: ROADBLOCK SET UP AHEAD",
	"DISPATCH: HELICOPTER EN ROUTE",
	"UNIT 5: SUSPECT IS NOT STOPPING",
	"UNIT 1: ENGAGING PURSUIT TACTICS",
	"DISPATCH: CODE 3 - ALL AVAILABLE UNITS",
	"UNIT 8: LOST VISUAL - LAST SEEN WESTBOUND",
]

var broadcast_text = "<<< POLICE PURSUIT IN PROGRESS >>> ALL UNITS RESPOND <<< SUSPECT VEHICLE SPOTTED >>> DO NOT RESIST          "

func _ready() -> void:
	# Load police icon texture
	var tex_pixel = load("res://asset/polisi_depan.png")
	if tex_pixel:
		police_icon.texture = tex_pixel
	
	emergency_strip.visible = false
	tracker_container.visible = false
	heartbeat_overlay.visible = false
	radio_label.visible = false
	busted_overlay.visible = false
	busted_text.visible = false
	busted_subtext.visible = false
	busted_buttons.visible = false
	
	# Connect button signals
	retry_button.pressed.connect(_on_retry_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	# Find the main camera for screen shake
	var parent = get_parent()
	if parent:
		camera_ref = parent.get_node_or_null("Camera3D")
	
	update_stars(0)

func _process(delta: float) -> void:
	# Saat BUSTED, jalankan efek khusus
	if is_busted:
		time_passed += delta
		# Layar berkedip merah intens
		var flash = abs(sin(time_passed * 15.0))
		busted_overlay.color = Color(0.7, 0, 0, 0.3 + flash * 0.4)
		
		# Text "BUSTED" berkedip merah-putih
		var text_flash = sin(time_passed * 10.0) > 0
		if text_flash:
			busted_text.modulate = Color(1, 0.1, 0.1, 1)
		else:
			busted_text.modulate = Color(1, 1, 1, 1)
		
		# Camera shake gila
		if camera_ref and is_instance_valid(camera_ref):
			camera_ref.h_offset = sin(time_passed * 50.0) * 0.015
			camera_ref.v_offset = cos(time_passed * 40.0) * 0.01
		
		# Vignette max merah
		var vignette_mat = vignette.material as ShaderMaterial
		if vignette_mat:
			vignette_mat.set_shader_parameter("pulse", 1.0)
			vignette_mat.set_shader_parameter("intensity", 0.8)
			vignette_mat.set_shader_parameter("edge_softness", 0.2)
		return
	
	if current_stars > 0:
		tracker_container.visible = true
		emergency_strip.visible = true
		time_passed += delta
		
		# === SIRINE FLASH SPEED ===
		var flash_speed = 5.0 + (current_stars * 2.0)
		var is_red = sin(time_passed * flash_speed) > 0
		
		# --- Tracker Bar Atas ---
		sirene_red.visible = is_red
		sirene_blue.visible = not is_red
		
		var wobble = sin(time_passed * 20.0) * (current_stars * 1.5)
		var current_x = police_icon.position.x
		police_icon.position.x = lerp(current_x, target_police_x + wobble, 5.0 * delta)
		police_icon.position.y = -30.0 + cos(time_passed * 15.0) * (current_stars * 1.5)
		
		# --- Vignette Red/Blue Edge Glow ---
		var target_intensity = current_stars / 6.0 * 0.65
		var vignette_mat = vignette.material as ShaderMaterial
		if vignette_mat:
			var pulse_val = sin(time_passed * flash_speed)
			vignette_mat.set_shader_parameter("pulse", pulse_val)
			var cur_intensity = vignette_mat.get_shader_parameter("intensity")
			vignette_mat.set_shader_parameter("intensity", lerp(cur_intensity, target_intensity, 3.0 * delta))
			var softness = 0.5 - (current_stars * 0.04)
			vignette_mat.set_shader_parameter("edge_softness", softness)
		
		# --- Emergency Broadcast Strip ---
		scroll_offset += delta * (80.0 + current_stars * 20.0)
		if scroll_offset > broadcast_text.length() * 11.0:
			scroll_offset = 0.0
		var repeat_text = broadcast_text + broadcast_text
		var char_offset = int(scroll_offset / 11.0)
		var visible_text = repeat_text.substr(char_offset, 80)
		scroll_label.text = visible_text
		
		if is_red:
			strip_border.color = Color(1.0, 0.1, 0.1, 1.0)
		else:
			strip_border.color = Color(0.1, 0.3, 1.0, 1.0)
		
		# === SCREEN SHAKE (Kamera Goyang) ===
		if camera_ref and is_instance_valid(camera_ref):
			var shake_amount = current_stars * 0.003
			camera_ref.h_offset = sin(time_passed * 35.0) * shake_amount
			camera_ref.v_offset = cos(time_passed * 28.0) * shake_amount * 0.5
		
		# === HEARTBEAT PULSE (Layar berdenyut gelap) ===
		heartbeat_overlay.visible = true
		# Detak jantung: 2 denyut cepat lalu jeda (lub-dub ... lub-dub)
		var heart_rate = 1.5 + (current_stars * 0.5) # Makin cepat seiring bintang
		var beat_cycle = fmod(time_passed * heart_rate, 1.0)
		var beat_alpha = 0.0
		if beat_cycle < 0.1:
			beat_alpha = sin(beat_cycle / 0.1 * PI) * 0.15
		elif beat_cycle > 0.15 and beat_cycle < 0.25:
			beat_alpha = sin((beat_cycle - 0.15) / 0.1 * PI) * 0.1
		heartbeat_overlay.modulate = Color(0, 0, 0, beat_alpha * current_stars / 3.0)
		
		# === POLICE RADIO CHATTER ===
		radio_timer += delta
		var radio_interval = 4.0 - (current_stars * 0.4) # Makin sering seiring bintang
		radio_interval = max(radio_interval, 1.5)
		
		if radio_timer >= radio_interval:
			radio_timer = 0.0
			radio_display_timer = 3.0
			var msg = radio_messages[randi() % radio_messages.size()]
			radio_label.text = "[RADIO] " + msg
			radio_label.visible = true
			radio_label.modulate = Color(0.3, 1.0, 0.3, 1.0) # Hijau terminal
		
		if radio_display_timer > 0:
			radio_display_timer -= delta
			# Fade out di detik terakhir
			if radio_display_timer < 1.0:
				radio_label.modulate.a = radio_display_timer
			if radio_display_timer <= 0:
				radio_label.visible = false
	else:
		tracker_container.visible = false
		emergency_strip.visible = false
		heartbeat_overlay.visible = false
		radio_label.visible = false
		
		# Reset camera shake
		if camera_ref and is_instance_valid(camera_ref):
			camera_ref.h_offset = lerp(camera_ref.h_offset, 0.0, 5.0 * delta)
			camera_ref.v_offset = lerp(camera_ref.v_offset, 0.0, 5.0 * delta)
		
		# Fade out vignette
		var vignette_mat = vignette.material as ShaderMaterial
		if vignette_mat:
			var cur_intensity = vignette_mat.get_shader_parameter("intensity")
			vignette_mat.set_shader_parameter("intensity", lerp(cur_intensity, 0.0, 5.0 * delta))

func update_stars(count: int) -> void:
	current_stars = count
	
	for i in range(star_container.get_child_count()):
		var star_label = star_container.get_child(i)
		if i < current_stars:
			star_label.modulate = Color(1.0, 0.8, 0.0, 1.0)
		else:
			star_label.modulate = Color(0.2, 0.2, 0.2, 0.5)
			
	if current_stars == 0:
		target_police_x = 10.0
		police_icon.position.x = 10.0
	else:
		target_police_x = 10.0 + (current_stars * 78.33)

func play_busted() -> void:
	is_busted = true
	
	# Sembunyikan UI normal
	emergency_strip.visible = false
	radio_label.visible = false
	
	# Tampilkan overlay merah
	busted_overlay.visible = true
	busted_overlay.color = Color(0.7, 0, 0, 0)
	
	# Animasi overlay fade in
	var tween_bg = create_tween()
	tween_bg.tween_property(busted_overlay, "color", Color(0.7, 0, 0, 0.6), 0.5)
	
	# Animasi teks "BUSTED" zoom in dari kecil ke besar
	busted_text.visible = true
	busted_text.scale = Vector2(0.1, 0.1)
	busted_text.modulate = Color(1, 0.1, 0.1, 0)
	busted_text.pivot_offset = busted_text.size / 2.0
	
	var tween_text = create_tween()
	tween_text.set_parallel(true)
	tween_text.tween_property(busted_text, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_text.tween_property(busted_text, "modulate", Color(1, 0.1, 0.1, 1), 0.3)
	
	# Subtext fade in setelah delay
	busted_subtext.visible = true
	busted_subtext.modulate = Color(1, 1, 1, 0)
	var tween_sub = create_tween()
	tween_sub.tween_interval(0.8)
	tween_sub.tween_property(busted_subtext, "modulate", Color(1, 1, 1, 1), 0.5)
	
	# Tombol muncul setelah 1.5 detik
	busted_buttons.visible = true
	busted_buttons.modulate = Color(1, 1, 1, 0)
	var tween_btn = create_tween()
	tween_btn.tween_interval(1.5)
	tween_btn.tween_property(busted_buttons, "modulate", Color(1, 1, 1, 1), 0.5)

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://world.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")
