extends CharacterBody3D

# =============================================================
# KONSTANTA DAN VARIABEL UMUM
# =============================================================
const SPEED = 5.0           # kecepatan awal
const BATAS_JALAN_X = 4.0   # batas lebar jalan kiri/kanan

var score: int = 0
var game_is_over: bool = false
# High score sekarang disimpan secara persisten via HighScoreManager (autoload)

var is_game_started: bool = false    # Untuk layar "Mulai"

# =============================================================
# FITUR CAR HEALTH & MECHANICAL FAILURE
# =============================================================
var car_health: float = 100.0
const MAX_HEALTH: float = 100.0
var invulnerability_timer: float = 0.0
const I_FRAMES_DURATION: float = 0.1

# Variabel Efek Kerusakan (Belok Otomatis)
var damage_auto_turn_dir: int = 0
var damage_auto_turn_strength: float = 0.0
var damage_auto_turn_timer: float = 0.0
var damage_auto_turn_pause: float = 0.0
var damage_turn_active: bool = false
var damage_max_turn_speed: float = 0.5

# =============================================================
# REFERENSI NODE
# =============================================================
@export var terrain_controller: Node3D
var wanted_ui_instance: Node
@onready var engine_audio = $Audio

# Variabel untuk kamera
var using_debug_camera: bool = false
@onready var normal_camera: Camera3D = $Camera3D
@onready var debug_camera: Camera3D = $CameraDebug

# PASTIKAN PATH UI INI SESUAI DENGAN STRUKTUR SCENE ANDA:
@onready var score_label: Label = get_node("/root/World/MainUI/ScoreLabel")
@onready var game_over_ui: Control = get_node("/root/World/GameOverUI/ColorRect")
var final_score_label: Label
var high_score_label: Label

# [BARU] Referensi UI "Mulai" (PASTIKAN PATH INI BENAR)
@onready var start_ui: Control = get_node("/root/World/MainUI/StartUI")

# Referensi Node UI Health
@onready var health_bar: ProgressBar = get_node("/root/World/MainUI/HealthBar")
@onready var health_label: Label = get_node("/root/World/MainUI/HealthLabel")

@onready var car_mesh: MeshInstance3D = $MeshInstance3D

# Dashboard
@onready var dashboard: CanvasLayer = get_node("/root/World/DashboardLayer")

# Dashboard Elements
@onready var steer_center = get_node("/root/World/DashboardLayer/Main/Steer/Center")
@onready var steer_right  = get_node("/root/World/DashboardLayer/Main/Steer/Right")
@onready var steer_left   = get_node("/root/World/DashboardLayer/Main/Steer/Left")

# delay suara lewat
var last_pass_sound_time: float = 0.0
var last_horn_sound_time: float = 0.0
var last_heal_sound_time: float = 0.0
# =============================================================
# FUNGSI BAWAAN GODOT
# =============================================================

func _ready() -> void:
	await get_tree().process_frame
	
	# Inisialisasi awal
	score_label.text = "Score: %d" % score
	score_label.visible = true # Skor tetap terlihat (seperti di gambar Anda)
	
	final_score_label = get_node_or_null("/root/World/GameOverUI/ColorRect/FinalScoreLabel")
	high_score_label = get_node_or_null("/root/World/GameOverUI/ColorRect/VBoxContainer/HighScoreLabel")
	if final_score_label == null:
		push_warning("⚠️ FinalScoreLabel not found — check path!")
	if high_score_label == null:
		push_warning("⚠️ HighScoreLabel not found — check path!")
	
	if is_instance_valid(game_over_ui):
		game_over_ui.visible = false
	
	# [BARU] Tampilkan UI Mulai dan Jeda game
	if is_instance_valid(start_ui):
		start_ui.visible = true
	
	# Inisialisasi UI Health
	if is_instance_valid(health_bar):
		health_bar.max_value = MAX_HEALTH
		health_bar.value = MAX_HEALTH
		health_bar.visible = true
		
		# Setup Background Aesthetic
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		bg_style.corner_radius_top_left = 10
		bg_style.corner_radius_top_right = 10
		bg_style.corner_radius_bottom_left = 10
		bg_style.corner_radius_bottom_right = 10
		bg_style.border_width_left = 2
		bg_style.border_width_right = 2
		bg_style.border_width_top = 2
		bg_style.border_width_bottom = 2
		bg_style.border_color = Color(0.3, 0.3, 0.3)
		health_bar.add_theme_stylebox_override("background", bg_style)
		health_bar.show_percentage = false # Sembunyikan tulisan angka agar lebih modern
		
		_update_health_color()
	if is_instance_valid(health_label):
		health_label.visible = true
	
	# =============================================================
	# INISIALISASI WANTED UI (SPION & BINTANG)
	# =============================================================
	var wanted_scene = preload("res://wanted_ui.tscn")
	wanted_ui_instance = wanted_scene.instantiate()
	add_child(wanted_ui_instance)
	_update_wanted_ui()

	# Atur kamera utama
	normal_camera.current = true
	debug_camera.current = false
	
	# [BARU] Jeda game saat pertama kali dimulai
	#get_tree().paused = true
	
	await get_tree().process_frame
	
	if is_instance_valid(steer_center):
		steer_center.visible = true
		steer_left.visible = false
		steer_right.visible = false
	
	if terrain_controller:
		terrain_controller.connect("game_over_signal", Callable(self, "_on_game_over_signal"))
		
	# =============================================================
	# PASANG LAMPU SOROT (HEADLIGHTS) UNTUK MALAM HARI
	# =============================================================
	_setup_headlights()

func _setup_headlights() -> void:
	if not is_instance_valid(car_mesh): return
	
	# Lampu Kiri
	var left_light = SpotLight3D.new()
	left_light.position = Vector3(-0.6, 0.4, -1.2) # Disesuaikan dengan body mobil
	left_light.spot_range = 80.0
	left_light.spot_angle = 40.0
	left_light.light_energy = 5.0
	left_light.shadow_enabled = true
	left_light.light_color = Color(0.9, 0.95, 1.0) # Putih kebiruan (Xenon HD)
	
	# Lampu Kanan
	var right_light = SpotLight3D.new()
	right_light.position = Vector3(0.6, 0.4, -1.2)
	right_light.spot_range = 80.0
	right_light.spot_angle = 40.0
	right_light.light_energy = 5.0
	right_light.shadow_enabled = true
	right_light.light_color = Color(0.9, 0.95, 1.0)
	
	car_mesh.add_child(left_light)
	car_mesh.add_child(right_light)


func _on_game_over_signal() -> void:
	# Disable all object sounds in the world
	var objects = get_tree().get_nodes_in_group("ObstacleObjects")
	for obj in objects:
		if obj.has_method("disable_sounds"):
			obj.disable_sounds()


# [DIUBAH] MENANGANI SEMUA INPUT SAAT DI-PAUSE
func _input(event: InputEvent) -> void:
	
	# 1. Handle "Start Game" (Mulai)
	# Cek jika game BELUM dimulai dan tombol APA SAJA ditekan
	if not is_game_started and event.is_pressed():
		# Kita hanya perlu satu input (keyboard, mouse, atau gamepad)
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			start_game()
	
	# 2. Handle "Restart Game" (Game Over)
	# Cek jika game SUDAH berakhir
	elif game_is_over:
		if event is InputEventKey:
			# Pengecekan tombol 'R' di keyboard
			if event.keycode == KEY_R and event.is_pressed():
				_on_restart_game() # Panggil fungsi restart

func _physics_process(delta: float) -> void:
	# [DIUBAH] Hentikan semua proses fisika jika game berakhir ATAU BELUM dimulai
	if game_is_over or not is_game_started or get_tree().paused:
		return
		
	# Ambil input gerakan dari pemain
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var horizontal_movement = input_dir.x
	
	
	
	# =============================================================
	# TAMPILAN UI STEER BERDASARKAN ARAH GERAK
	# =============================================================
	if is_instance_valid(steer_center) and is_instance_valid(steer_left) and is_instance_valid(steer_right):
		if horizontal_movement > 0.1:
			steer_right.visible = true
			steer_left.visible = false
			steer_center.visible = false
		elif horizontal_movement < -0.1:
			steer_left.visible = true
			steer_right.visible = false
			steer_center.visible = false
		else:
			steer_center.visible = true
			steer_left.visible = false
			steer_right.visible = false
	
	# =============================================================
	# LOGIKA I-FRAMES
	# =============================================================
	if invulnerability_timer > 0:
		invulnerability_timer -= delta
		if is_instance_valid(car_mesh):
			# Efek kedap-kedip cepat (toggle visibility setiap 0.1 detik)
			car_mesh.visible = int(invulnerability_timer * 10) % 2 == 0
	else:
		if is_instance_valid(car_mesh):
			car_mesh.visible = true

	# =============================================================
	# LOGIKA KERUSAKAN MEKANIS (BELOK OTOMATIS)
	# =============================================================
	if car_health < MAX_HEALTH:
		_update_damage_auto_turn(delta)
		# Gabungkan input pemain dan belok otomatis (makin rusak makin kuat nariknya)
		horizontal_movement += damage_auto_turn_strength * damage_auto_turn_dir
		horizontal_movement = clamp(horizontal_movement, -1.8, 1.8)
		
		# UI steer ikut terpengaruh efek goyang/rusak
		if is_instance_valid(steer_center) and is_instance_valid(steer_left) and is_instance_valid(steer_right):
			if horizontal_movement > 0.1:
				steer_right.visible = true
				steer_left.visible = false
				steer_center.visible = false
			elif horizontal_movement < -0.1:
				steer_left.visible = true
				steer_right.visible = false
				steer_center.visible = false
			else:
				steer_center.visible = true
				steer_left.visible = false
				steer_right.visible = false

	
	# Hitung arah gerakan final
	var direction := (transform.basis * Vector3(horizontal_movement, 0, input_dir.y)).normalized()
	
	# Terapkan kecepatan ke velocity
	if direction:
		velocity.x = direction.x * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	# BATAS JALAN & AXIS LOCK (CLAMP)
	var new_pos = global_position
	new_pos.x = clamp(new_pos.x, -BATAS_JALAN_X, BATAS_JALAN_X)
	new_pos.y = 0.1 # Kunci agar tidak terbang / naik saat nabrak
	new_pos.z = 0.0 # Kunci agar tidak mundur karena tertabrak obstacle
	global_position = new_pos
	
	# Pengecekan Tabrakan Fisik (Fallback)
	var collision = get_last_slide_collision()
	if collision and not game_is_over:
		var collider = collision.get_collider()
		if collider and collider.get_parent():
			var obj = collider.get_parent()
			if obj.is_in_group("HealObjects"):
				receive_hit("heal", obj)
			elif obj.is_in_group("BribeObjects"):
				receive_hit("bribe", obj)
			elif obj.is_in_group("ObstacleObjects"):
				receive_hit("damage", obj)

	# Sistem Skor
	if terrain_controller:
		var distance_traveled = terrain_controller.terrain_velocity * delta
		var score_increment = int(distance_traveled * 5.0) 
		
		if score_increment > 0:
			add_score(score_increment)
	
	# Cek input untuk mengganti kamera
	if Input.is_action_just_pressed("toggle_camera"):
		toggle_camera()
		
	# Jembatan ke sistem audio
	if terrain_controller:
		var current_speed = terrain_controller.terrain_velocity
		var is_terrain_over = terrain_controller.game_over
		var input_x = input_dir.x
		engine_audio.update_audio(current_speed, input_x, delta, is_terrain_over)

# =============================================================
# FUNGSI UTILITY & LOGIKA GAME
# =============================================================

# [BARU] Fungsi untuk memulai game
func start_game() -> void:
	is_game_started = true       # Tandai bahwa game sudah dimulai
	#get_tree().paused = false    # Lanjutkan game
	
	terrain_controller.enable_spawning()
	
	# Sembunyikan UI "Mulai"
	if is_instance_valid(start_ui):
		start_ui.visible = false

# ... (fungsi add_score, toggle_camera, show_game_over_ui tidak berubah) ...

func add_score(points: int) -> void:
	score += points
	score_label.text = "Score:\n%d" % score

func toggle_camera() -> void:
	using_debug_camera = !using_debug_camera
	if using_debug_camera:
		debug_camera.current = false
		normal_camera.current = true
		dashboard.visible = true
		print("DEBUG CAMERA OFF")
	else:
		debug_camera.current = true
		normal_camera.current = false
		dashboard.visible = false
		print("DEBUG CAMERA ON")


func show_game_over_ui() -> void:
	if game_is_over:
		return
	game_is_over = true
	HighScoreManager.try_set_high_score(score)
		
	# Reset status kerusakan
	damage_auto_turn_dir = 0
	damage_auto_turn_strength = 0
	damage_turn_active = false
	invulnerability_timer = 0.0
	if is_instance_valid(car_mesh):
		car_mesh.visible = true
	
	if is_instance_valid(health_bar):
		health_bar.visible = false
	if is_instance_valid(health_label):
		health_label.visible = false
	score_label.visible = false
	
	if terrain_controller:
		terrain_controller._trigger_game_over()
	
	if not is_instance_valid(game_over_ui):
		get_tree().paused = true
		return
	
	# === DRAMATIC GAME OVER ANIMATION ===
	game_over_ui.visible = true
	game_over_ui.color = Color(0, 0, 0, 0)
	
	# Sembunyikan semua anak dulu
	for child in game_over_ui.get_children():
		child.modulate = Color(1, 1, 1, 0)
	
	# Phase 1: Layar gelap fade in
	var tween_bg = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_bg.tween_property(game_over_ui, "color", Color(0, 0, 0, 0.85), 0.8).set_trans(Tween.TRANS_CUBIC)
	
	# Phase 2: Gambar Game Over zoom in
	var game_over_img = game_over_ui.get_node_or_null("GameOver")
	if game_over_img:
		game_over_img.scale = Vector2(0.1, 0.1)
		game_over_img.pivot_offset = game_over_img.size / 2.0
		var tw1 = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw1.tween_interval(0.3)
		tw1.tween_property(game_over_img, "modulate", Color(1, 1, 1, 1), 0.3)
		var tw2 = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw2.tween_interval(0.3)
		tw2.tween_property(game_over_img, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Phase 3: Skor fade in
	if is_instance_valid(final_score_label):
		final_score_label.text = "Final Score: %d" % score
		var tw3 = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw3.tween_interval(1.0)
		tw3.tween_property(final_score_label, "modulate", Color(1, 1, 1, 1), 0.5)
	
	if is_instance_valid(high_score_label):
		high_score_label.text = "Highest Score: %d" % HighScoreManager.get_high_score()
	
	# Phase 4: Tombol fade in
	var restart_btn = game_over_ui.get_node_or_null("RestartButton")
	if restart_btn:
		var tw4 = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw4.tween_interval(1.5)
		tw4.tween_property(restart_btn, "modulate", Color(1, 1, 1, 1), 0.5)
	
	var menu_btn = game_over_ui.get_node_or_null("MenuButton")
	if menu_btn:
		var tw5 = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw5.tween_interval(1.7)
		tw5.tween_property(menu_btn, "modulate", Color(1, 1, 1, 1), 0.5)
	
	# Pause langsung - tween tetap jalan karena TWEEN_PAUSE_PROCESS
	get_tree().paused = true

func _update_health_color() -> void:
	if not is_instance_valid(health_bar): return
	
	var style_box = StyleBoxFlat.new()
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	style_box.border_width_left = 3
	style_box.border_width_right = 3
	style_box.border_width_top = 3
	style_box.border_width_bottom = 3
	style_box.shadow_size = 4
	style_box.shadow_color = Color(0, 0, 0, 0.5)
	
	if car_health > 60:
		style_box.bg_color = Color(0.15, 0.85, 0.25) # Neon Hijau
		style_box.border_color = Color(0.5, 1.0, 0.5)
	elif car_health > 30:
		style_box.bg_color = Color(0.9, 0.75, 0.1) # Neon Kuning
		style_box.border_color = Color(1.0, 0.9, 0.5)
	else:
		style_box.bg_color = Color(0.85, 0.1, 0.15) # Neon Merah
		style_box.border_color = Color(1.0, 0.4, 0.4)
		
	health_bar.add_theme_stylebox_override("fill", style_box)

# =============================================================
# LOGIKA BEL0K OTOMATIS SAAT RUSAK (SEVERITY BASE)
# =============================================================
func _update_damage_auto_turn(delta: float) -> void:
	# Hitung tingkat kerusakan (0.0 aman, 1.0 sangat rusak)
	var severity = clamp((MAX_HEALTH - car_health) / MAX_HEALTH, 0.0, 1.0)
	
	if severity <= 0.0:
		return # Tidak rusak = aman
		
	# Kecepatan stir ditarik dan batas bantingannya meningkat sesuai severity
	damage_max_turn_speed = max(1.0, severity * 5.0)
	var max_strength = clamp(severity * 0.8, 0.1, 0.8)

	# Jika masih jeda antar tarikan stir
	if damage_auto_turn_pause > 0.0:
		damage_auto_turn_pause -= delta
		return
	
	# Jika tidak sedang ditarik, mulai sesi ditarik baru
	if not damage_turn_active:
		damage_turn_active = true
		damage_auto_turn_dir = -1 if randf() < 0.5 else 1  # Banting ke kiri atau kanan
		damage_auto_turn_timer = randf_range(1.0, 5.0) + (severity * 1.5)  # Makin rusak, ditariknya makin lama
		damage_auto_turn_strength = 0.0  # mulai ditarik perlahan
		return
	
	# Kalau stir sedang asyik ditarik otomatis:
	if damage_turn_active:
		damage_auto_turn_timer -= delta
		
		# Tambah kekuatan tarikan secara eksponensial sesuai severity
		damage_auto_turn_strength = min(damage_auto_turn_strength + delta * damage_max_turn_speed * 0.2, max_strength)
		
		# Jika sudah habis waktunya ditarik -> kembalikan ke stabil sejenak
		if damage_auto_turn_timer <= 0:
			damage_turn_active = false
			damage_auto_turn_dir = 0
			damage_auto_turn_strength = 0.0
			# Jeda sebelum ditarik lagi. Semakin rusak, jedanya semakin cepat!
			damage_auto_turn_pause = randf_range(0.5, 3.0) / max(0.5, severity * 2)

# =============================================================
# FUNGSI RESTART & MAIN MENU
# =============================================================
# ... (Fungsi-fungsi ini tidak berubah) ...

func _on_restart_game() -> void:
	game_is_over = false
	get_tree().paused = false

	# Hentikan semua audio aktif secara manual
	for player in get_tree().get_nodes_in_group("audio_players"):
		if player is AudioStreamPlayer3D or player is AudioStreamPlayer:
			player.stop()

	get_tree().change_scene_to_file("res://world.tscn")

func _on_restart_button_pressed() -> void:
	_on_restart_game()

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")

@export var MAX_WANTED_STARS: int = 6
var wanted_stars: int = 0

func receive_hit(type: String, obj: Node3D) -> void:
	if game_is_over:
		return
	
	if type == "heal":
		var heal_amount = 0.0
		if obj.has_method("get_heal"):
			heal_amount = obj.get_heal()
		elif "heal" in obj:
			heal_amount = obj.damage
		car_health += heal_amount
		
		if is_instance_valid(health_bar):
			var tween = get_tree().create_tween()
			tween.tween_property(health_bar, "value", car_health, 0.3).set_trans(Tween.TRANS_CUBIC)
		_update_health_color()
		obj.queue_free()
		
		# --- TAMBAHAN KODE: SUARA HEAL DENGAN COOLDOWN ---
		var current_time = Time.get_ticks_msec() / 1000.0
		
		if current_time - last_heal_sound_time > 0.2:
			$Audio/HealSound.pitch_scale = randf_range(0.9, 1.1)
			$Audio/HealSound.play()
			last_heal_sound_time = current_time
		
	elif type == "bribe":
		wanted_stars = max(wanted_stars - 1, 0)
		_update_wanted_ui()
		obj.queue_free()
	
	elif type == "damage" and invulnerability_timer <= 0.0:
		var damage_amount = 0.0
		if obj.has_method("get_damage"):
			damage_amount = obj.get_damage()
		elif "damage" in obj:
			damage_amount = obj.damage
		car_health -= damage_amount
		
		# Nambah Bintang Pas Nabrak!
		wanted_stars += 1
		_update_wanted_ui()
		
		# ========================================================
		# MEMANGGIL EFEK GETAR DI SCRIPT KAMERA SAAT NABRAK
		# ========================================================
		if is_instance_valid(normal_camera):
			if normal_camera.has_method("add_shake"):
				normal_camera.add_shake(1.0) # Angka 1.0 adalah kekuatan getarannya
		# ========================================================
			$Audio/CrashSound.pitch_scale = randf_range(0.85, 1.15) 
			$Audio/CrashSound.play()
			
		if is_instance_valid(health_bar):
			var tween = get_tree().create_tween()
			tween.tween_property(health_bar, "value", car_health, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_update_health_color()
			
		if car_health <= 0.0:
			show_game_over_ui()
			if terrain_controller:
				terrain_controller._trigger_game_over()
		elif wanted_stars >= MAX_WANTED_STARS:
			# BUSTED! Trigger dramatic animation
			game_is_over = true
			HighScoreManager.try_set_high_score(score)
			if is_instance_valid(wanted_ui_instance) and wanted_ui_instance.has_method("play_busted"):
				wanted_ui_instance.play_busted()
			if terrain_controller:
				terrain_controller._trigger_game_over()
		else:
			invulnerability_timer = I_FRAMES_DURATION

func _update_wanted_ui() -> void:
	if is_instance_valid(wanted_ui_instance):
		wanted_ui_instance.update_stars(wanted_stars)
