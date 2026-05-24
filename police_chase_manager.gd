extends Node
# PoliceChaseManager — no class_name to avoid circular dependency
var police_2d_in_3d_scene = preload("res://polisi_2d.tscn") 
var spawned_car_visuals: Dictionary = {}
# =============================================================
# POLICE CHASE MANAGER
# Mengelola semua unit polisi yang mengejar player.
# Sistem state machine per unit: 
#   TRAILING → LOCK_ON → CHARGING → (HIT/MISS path) → COOLDOWN → loop
# =============================================================

signal police_attack_hit(lane: int)
signal police_state_changed(unit_id: int, new_state: String)

# ----- Konfigurasi per wanted level -----
# [jumlah_polisi, base_cooldown, lock_on_time, trail_time]
const WANTED_CONFIG = {
	0: [0, 0.0, 0.0, 0.0],
	1: [1, 8.0, 2.0, 5.0],
	2: [2, 6.5, 1.8, 4.0],
	3: [3, 5.0, 1.5, 3.0],
	4: [4, 3.5, 1.2, 2.5],
	5: [5, 2.5, 0.8, 2.0],
	6: [6, 1.5, 0.5, 1.5],
}

const POLICE_DAMAGE: float = 15.0
const CHARGE_DURATION: float = 0.8      # waktu charge dari jauh sampai nabrak
const PASS_DURATION: float = 0.6        # waktu polisi ngedahuluin (miss)
const STALL_DURATION: float = 2.0       # waktu mogok setelah miss
const RETREAT_DURATION: float = 1.0     # waktu mundur ke belakang
const MISS_COOLDOWN_MULTIPLIER: float = 1.5  # cooldown lebih lama setelah miss

# States
enum PoliceState {
	TRAILING,
	LOCK_ON,
	CHARGING,
	PASSING,
	STALLED,
	RETREATING,
	COOLDOWN,
	INACTIVE
}

# ----- Police Unit Inner Class -----
class PoliceUnit:
	var id: int = 0
	var state: int = 7  # INACTIVE (PoliceState.INACTIVE = 7)
	var lane: int = 0                # posisi saat ini: -1 kiri, 0 tengah, 1 kanan
	var target_lane: int = 0         # lane serangan
	var trail_timer: float = 0.0     # sisa waktu trailing
	var lock_timer: float = 0.0      # sisa waktu lock on
	var cooldown_timer: float = 0.0  # sisa cooldown
	var charge_progress: float = 0.0 # 0.0 jauh → 1.0 sampai
	var pass_progress: float = 0.0   # progress ngedahuluin
	var stall_timer: float = 0.0     # sisa waktu mogok
	var retreat_progress: float = 0.0
	var sway_timer: float = 0.0      # timer untuk efek goyang saat trailing
	var sway_offset: float = 0.0     # offset goyang horizontal
	var last_attack_was_miss: bool = false
	var mirror_x: float = 0.5        # posisi x di dalam mirror (0.0-1.0)
	var mirror_y: float = 0.5        # posisi y di dalam mirror (0.0-1.0)
	var scale_factor: float = 0.3    # ukuran ikon (makin dekat makin besar)
	var visible: bool = false
	var warning_active: bool = false  # apakah tanda seru aktif

# ----- Runtime State -----
var police_units: Array = []   # Array of PoliceUnit
var wanted_level: int = 0
var active: bool = false
var player_ref: Node = null
var _time_passed: float = 0.0

func _ready() -> void:
	pass

# =============================================================
# PUBLIC API
# =============================================================

func set_player(player: Node) -> void:
	player_ref = player

func set_wanted_level(level: int) -> void:
	var _old_level = wanted_level
	wanted_level = clampi(level, 0, 6)
	
	if wanted_level == 0:
		_deactivate_all()
		active = false
		return
	
	active = true
	var config = WANTED_CONFIG.get(wanted_level, WANTED_CONFIG[1])
	var target_count = config[0]
	
	# Tambah polisi baru jika perlu
	while police_units.size() < target_count:
		var unit = PoliceUnit.new()
		unit.id = police_units.size()
		unit.state = PoliceState.COOLDOWN
		unit.cooldown_timer = randf_range(1.0, 3.0)  # stagger spawn
		unit.lane = [-1, 0, 1][randi() % 3]
		police_units.append(unit)
		
		if is_instance_valid(player_ref):
			var new_car_visual = police_2d_in_3d_scene.instantiate()
			# Masukkan ke World ( get_parent() dari Player biasanya root World)
			player_ref.get_parent().add_child(new_car_visual) 
			new_car_visual.set_unit_data(unit)
			# Simpan referensi berdasarkan unit ID
			spawned_car_visuals[unit.id] = new_car_visual
			
	# Kurangi polisi jika bintang turun
	while police_units.size() > target_count:
		police_units.pop_back()
		
		# Kurangi polisi jika bintang turun
	while police_units.size() > target_count:
		var removed_unit = police_units.pop_back()
		
		if spawned_car_visuals.has(removed_unit.id):
			if is_instance_valid(spawned_car_visuals[removed_unit.id]):
				spawned_car_visuals[removed_unit.id].queue_free()
			spawned_car_visuals.erase(removed_unit.id)
			
func get_police_units() -> Array:
	return police_units

func get_active_unit_count() -> int:
	return police_units.size()

func is_active() -> bool:
	return active and wanted_level > 0

# Fungsi untuk mendapatkan lane player berdasarkan posisi X
func _get_player_lane() -> int:
	if not is_instance_valid(player_ref):
		return 0
	var px = player_ref.global_position.x
	if px < -1.3:
		return -1  # kiri
	elif px > 1.3:
		return 1   # kanan
	else:
		return 0   # tengah

# =============================================================
# UPDATE LOOP
# =============================================================

func update(delta: float) -> void:
	if not active or wanted_level == 0:
		return
	
	_time_passed += delta
	var config = WANTED_CONFIG.get(wanted_level, WANTED_CONFIG[1])
	
	for unit in police_units:
		match unit.state:
			PoliceState.TRAILING:
				_update_trailing(unit, delta, config)
			PoliceState.LOCK_ON:
				_update_lock_on(unit, delta, config)
			PoliceState.CHARGING:
				_update_charging(unit, delta)
			PoliceState.PASSING:
				_update_passing(unit, delta)
			PoliceState.STALLED:
				_update_stalled(unit, delta)
			PoliceState.RETREATING:
				_update_retreating(unit, delta)
			PoliceState.COOLDOWN:
				_update_cooldown(unit, delta, config)
			PoliceState.INACTIVE:
				pass

# ----- State Updates -----

func _update_trailing(unit: PoliceUnit, delta: float, config: Array) -> void:
	unit.visible = true
	unit.warning_active = false
	unit.scale_factor = 0.35
	
	# Efek sway (goyang kiri-kanan saat aim)
	unit.sway_timer += delta * (2.0 + wanted_level * 0.5)
	unit.sway_offset = sin(unit.sway_timer * 1.5 + unit.id * 2.0) * 0.3
	
	# Update posisi mirror
	unit.mirror_x = 0.5 + unit.sway_offset
	unit.mirror_y = 0.5 + sin(_time_passed * 1.2 + unit.id) * 0.1
	
	# Sesekali ganti lane target
	if fmod(unit.sway_timer, 3.0) < delta:
		unit.lane = [-1, 0, 1][randi() % 3]
	
	# Countdown trailing
	unit.trail_timer -= delta
	if unit.trail_timer <= 0.0:
		# Pilih target lane (50% chance ikutin player lane, 50% random)
		if randf() < 0.5:
			unit.target_lane = _get_player_lane()
		else:
			unit.target_lane = [-1, 0, 1][randi() % 3]
		unit.lane = unit.target_lane
		_change_state(unit, PoliceState.LOCK_ON)
		unit.lock_timer = config[2]

func _update_lock_on(unit: PoliceUnit, delta: float, _config: Array) -> void:
	unit.visible = true
	unit.warning_active = true
	unit.sway_offset = 0.0  # Berhenti goyang, posisi terkunci
	
	# Posisi mirror terkunci di tengah
	unit.mirror_x = 0.5
	unit.mirror_y = 0.5
	
	# Sedikit zoom in (polisi makin dekat)
	unit.scale_factor = lerp(unit.scale_factor, 0.5, delta * 3.0)
	
	unit.lock_timer -= delta
	if unit.lock_timer <= 0.0:
		_change_state(unit, PoliceState.CHARGING)
		unit.charge_progress = 0.0

func _update_charging(unit: PoliceUnit, delta: float) -> void:
	unit.visible = true
	unit.warning_active = true
	
	unit.charge_progress += delta / CHARGE_DURATION
	unit.charge_progress = clampf(unit.charge_progress, 0.0, 1.0)
	
	# Polisi makin besar (makin dekat)
	unit.scale_factor = lerp(0.5, 1.2, unit.charge_progress)
	unit.mirror_y = lerp(0.5, 0.8, unit.charge_progress)
	
	if unit.charge_progress >= 1.0:
		# Cek hit atau miss
		var player_lane = _get_player_lane()
		if unit.target_lane == player_lane:
			# HIT!
			_on_police_hit(unit)
		else:
			# MISS!
			_on_police_miss(unit)

func _update_passing(unit: PoliceUnit, delta: float) -> void:
	unit.visible = true
	unit.warning_active = false
	
	unit.pass_progress += delta / PASS_DURATION
	unit.pass_progress = clampf(unit.pass_progress, 0.0, 1.0)
	
	# Polisi ngedahuluin — scale mengecil ke atas (depan)
	unit.scale_factor = lerp(1.2, 0.2, unit.pass_progress)
	unit.mirror_y = lerp(0.8, 0.0, unit.pass_progress)
	
	if unit.pass_progress >= 1.0:
		_change_state(unit, PoliceState.STALLED)
		unit.stall_timer = STALL_DURATION
		unit.visible = false  # Mogok di depan, gak keliatan di spion

func _update_stalled(unit: PoliceUnit, delta: float) -> void:
	unit.visible = false  # Di depan player, tidak terlihat di spion belakang
	unit.warning_active = false
	
	unit.stall_timer -= delta
	if unit.stall_timer <= 0.0:
		_change_state(unit, PoliceState.RETREATING)
		unit.retreat_progress = 0.0

func _update_retreating(unit: PoliceUnit, delta: float) -> void:
	unit.visible = true
	unit.warning_active = false
	
	unit.retreat_progress += delta / RETREAT_DURATION
	unit.retreat_progress = clampf(unit.retreat_progress, 0.0, 1.0)
	
	# Polisi muncul lagi dari jauh dan perlahan makin dekat (ke posisi trailing)
	unit.scale_factor = lerp(0.1, 0.35, unit.retreat_progress)
	unit.mirror_x = 0.5
	unit.mirror_y = lerp(0.2, 0.5, unit.retreat_progress)
	
	if unit.retreat_progress >= 1.0:
		var config = WANTED_CONFIG.get(wanted_level, WANTED_CONFIG[1])
		var base_cd = config[1]
		if unit.last_attack_was_miss:
			base_cd *= MISS_COOLDOWN_MULTIPLIER
		unit.cooldown_timer = base_cd + randf_range(-0.5, 0.5)
		_change_state(unit, PoliceState.COOLDOWN)

func _update_cooldown(unit: PoliceUnit, delta: float, config: Array) -> void:
	unit.visible = true
	unit.warning_active = false
	unit.scale_factor = 0.3
	
	# Sedikit goyang pelan saat cooldown (masih ngikutin)
	unit.sway_timer += delta
	unit.mirror_x = 0.5 + sin(unit.sway_timer * 0.8 + unit.id) * 0.15
	unit.mirror_y = 0.45 + sin(unit.sway_timer * 0.5) * 0.05
	
	unit.cooldown_timer -= delta
	if unit.cooldown_timer <= 0.0:
		unit.trail_timer = config[3] + randf_range(-0.5, 0.5)
		unit.lane = [-1, 0, 1][randi() % 3]
		unit.sway_timer = randf() * TAU
		_change_state(unit, PoliceState.TRAILING)

# =============================================================
# HIT / MISS LOGIC
# =============================================================

func _on_police_hit(unit: PoliceUnit) -> void:
	unit.last_attack_was_miss = false
	emit_signal("police_attack_hit", unit.target_lane)
	
	# Apply damage to player
	if is_instance_valid(player_ref) and player_ref.has_method("receive_police_hit"):
		player_ref.receive_police_hit(POLICE_DAMAGE, unit.target_lane)
	
	# Langsung mundur
	_change_state(unit, PoliceState.RETREATING)
	unit.retreat_progress = 0.0

func _on_police_miss(unit: PoliceUnit) -> void:
	unit.last_attack_was_miss = true
	
	# Polisi melewati player lalu mogok
	_change_state(unit, PoliceState.PASSING)
	unit.pass_progress = 0.0

# =============================================================
# UTILITY
# =============================================================

func _change_state(unit: PoliceUnit, new_state: int) -> void:
	unit.state = new_state
	emit_signal("police_state_changed", unit.id, PoliceState.keys()[new_state])

func _deactivate_all() -> void:
	police_units.clear()
