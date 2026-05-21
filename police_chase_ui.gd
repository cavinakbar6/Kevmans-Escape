extends CanvasLayer

# =============================================================
# POLICE CHASE UI
# Polisi muncul langsung DI DALAM spion dashboard yang sudah ada.
# Tidak ada panel terpisah — ikon polisi overlay langsung di atas
# gambar spion di dashboard texture.
# =============================================================

# Icon overlay areas — invisible containers yang nempel di posisi spion dashboard
# Posisi disesuaikan dengan gambar dashboard (gamespace_dashboard.png)
@onready var left_mirror_area: Control = $LeftMirrorArea
@onready var rearview_mirror_area: Control = $RearviewMirrorArea

# Warning indicators
@onready var warning_left: Label = $WarningLeft
@onready var warning_center: Label = $WarningCenter
@onready var warning_right: Label = $WarningRight

# Charge flash overlay
@onready var charge_flash: ColorRect = $ChargeFlash

# Reference — use Node type to avoid class_name resolution issues
var chase_manager: Node = null
var _time: float = 0.0

# State constants (mirror PoliceChaseManager.PoliceState enum)
const STATE_LOCK_ON = 1
const STATE_CHARGING = 2

# Ikon polisi yang sudah di-spawn di UI
var _police_icons: Dictionary = {}  # unit_id -> {left: Node, rear: Node}

# Preloaded police texture
var police_texture: Texture2D = null

func _ready() -> void:
	police_texture = load("res://asset/police_pixel.jpg")
	
	# Hide everything initially
	left_mirror_area.visible = false
	rearview_mirror_area.visible = false
	warning_left.visible = false
	warning_center.visible = false
	warning_right.visible = false
	charge_flash.visible = false

func set_chase_manager(manager: Node) -> void:
	chase_manager = manager

func _process(delta: float) -> void:
	if chase_manager == null or not chase_manager.is_active():
		_hide_all()
		return
	
	_time += delta
	var units = chase_manager.get_police_units()
	
	if units.size() == 0:
		_hide_all()
		return
	
	# Show mirror overlay areas
	left_mirror_area.visible = true
	rearview_mirror_area.visible = true
	
	# Ensure we have icons for all units
	_sync_icons(units)
	
	# Reset warning states
	var warn_left_active = false
	var warn_center_active = false
	var warn_right_active = false
	var any_charging = false
	
	# Update each unit's visual
	for unit in units:
		if not unit.visible:
			_hide_unit_icons(unit.id)
			continue
		
		# Polisi muncul di spion berdasarkan lane:
		#   lane -1 (kiri)  → spion kiri (side mirror)
		#   lane 0 (tengah) → spion tengah (rearview)
		#   lane 1 (kanan)  → spion tengah (rearview) — gak ada spion kanan di dashboard
		var target_area: Control = null
		match unit.lane:
			-1:
				target_area = left_mirror_area
			0:
				target_area = rearview_mirror_area
			1:
				target_area = rearview_mirror_area  # Kanan juga muncul di rearview
		
		_update_unit_icon(unit, target_area)
		
		# Warning indicators
		if unit.warning_active:
			match unit.target_lane:
				-1:
					warn_left_active = true
				0:
					warn_center_active = true
				1:
					warn_right_active = true
		
		# Charge flash
		if unit.state == STATE_CHARGING:
			any_charging = true
	
	# Update warnings with flash effect
	_update_warning(warning_left, warn_left_active, delta)
	_update_warning(warning_center, warn_center_active, delta)
	_update_warning(warning_right, warn_right_active, delta)
	
	# Charge flash overlay
	if any_charging:
		charge_flash.visible = true
		var flash_alpha = abs(sin(_time * 15.0)) * 0.15
		charge_flash.color = Color(1.0, 0.2, 0.1, flash_alpha)
	else:
		charge_flash.visible = false

# =============================================================
# ICON MANAGEMENT
# =============================================================

func _sync_icons(units: Array) -> void:
	for unit in units:
		if not _police_icons.has(unit.id):
			_create_unit_icons(unit.id)
	
	var valid_ids = []
	for unit in units:
		valid_ids.append(unit.id)
	for icon_id in _police_icons.keys():
		if icon_id not in valid_ids:
			_remove_unit_icons(icon_id)

func _create_unit_icons(unit_id: int) -> void:
	var icons = {}
	
	for area_name in ["left", "rear"]:
		var icon = TextureRect.new()
		icon.texture = police_texture
		icon.custom_minimum_size = Vector2(40, 40)
		icon.size = Vector2(40, 40)
		icon.expand_mode = 1  # EXPAND_IGNORE_SIZE
		icon.stretch_mode = 5  # STRETCH_KEEP_ASPECT_CENTERED
		icon.visible = false
		icon.modulate = Color(1.0, 1.0, 1.0, 0.9)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Sirine glow behind icon
		var glow = ColorRect.new()
		glow.custom_minimum_size = Vector2(50, 50)
		glow.size = Vector2(50, 50)
		glow.color = Color(1.0, 0.0, 0.0, 0.3)
		glow.name = "Glow"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.show_behind_parent = true
		icon.add_child(glow)
		
		match area_name:
			"left":
				left_mirror_area.add_child(icon)
			"rear":
				rearview_mirror_area.add_child(icon)
		
		icons[area_name] = icon
	
	_police_icons[unit_id] = icons

func _remove_unit_icons(unit_id: int) -> void:
	if _police_icons.has(unit_id):
		var icons = _police_icons[unit_id]
		for key in icons.keys():
			if is_instance_valid(icons[key]):
				icons[key].queue_free()
		_police_icons.erase(unit_id)

func _hide_unit_icons(unit_id: int) -> void:
	if _police_icons.has(unit_id):
		var icons = _police_icons[unit_id]
		for key in icons.keys():
			if is_instance_valid(icons[key]):
				icons[key].visible = false

func _update_unit_icon(unit, target_area: Control) -> void:
	if not _police_icons.has(unit.id):
		return
	
	var icons = _police_icons[unit.id]
	
	# Hide all icons first
	for key in icons.keys():
		if is_instance_valid(icons[key]):
			icons[key].visible = false
	
	# Determine which icon key matches the target area
	var active_key = ""
	if target_area == left_mirror_area:
		active_key = "left"
	elif target_area == rearview_mirror_area:
		active_key = "rear"
	
	if active_key == "" or not icons.has(active_key):
		return
	
	var icon = icons[active_key]
	if not is_instance_valid(icon):
		return
	
	icon.visible = true
	
	# Calculate size based on scale_factor
	var base_size = 25.0
	if active_key == "rear":
		base_size = 22.0  # Rearview lebih kecil
	var icon_size = base_size * unit.scale_factor
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size = Vector2(icon_size, icon_size)
	
	# Calculate position within the mirror area
	var area_size = target_area.size
	var pos_x = unit.mirror_x * (area_size.x - icon_size)
	var pos_y = unit.mirror_y * (area_size.y - icon_size)
	
	# Untuk lane 1 (kanan) yang muncul di rearview, geser ke sisi kanan mirror
	if unit.lane == 1 and active_key == "rear":
		pos_x = (0.5 + unit.mirror_x * 0.5) * (area_size.x - icon_size)
	elif unit.lane == -1 and active_key == "left":
		# Di spion kiri, center the icon
		pos_x = unit.mirror_x * (area_size.x - icon_size)
	
	icon.position = Vector2(pos_x, pos_y)
	
	# Sirine flash effect on glow
	var glow = icon.get_node_or_null("Glow")
	if glow:
		var flash_speed = 5.0 + chase_manager.wanted_level * 2.0
		var is_red = sin(_time * flash_speed + unit.id * 1.5) > 0
		if is_red:
			glow.color = Color(1.0, 0.0, 0.0, 0.5)
		else:
			glow.color = Color(0.0, 0.3, 1.0, 0.5)
		glow.size = Vector2(icon_size + 8, icon_size + 8)
		glow.position = Vector2(-4, -4)
	
	# Tint icon based on state
	match unit.state:
		STATE_LOCK_ON:
			var flash = abs(sin(_time * 8.0)) 
			icon.modulate = Color(1.0, 0.5 + flash * 0.5, 0.5 + flash * 0.5, 1.0)
		STATE_CHARGING:
			icon.modulate = Color(1.0, 0.3, 0.3, 1.0)
		_:
			icon.modulate = Color(1.0, 1.0, 1.0, 0.85)

# =============================================================
# WARNING INDICATORS
# =============================================================

func _update_warning(warning_label: Label, is_active: bool, _delta: float) -> void:
	warning_label.visible = is_active
	if is_active:
		var flash_speed = 4.0 + chase_manager.wanted_level * 2.0
		var alpha = 0.5 + abs(sin(_time * flash_speed)) * 0.5
		warning_label.modulate = Color(1.0, 0.2, 0.1, alpha)
		
		var scale_pulse = 1.0 + sin(_time * flash_speed * 2.0) * 0.1
		warning_label.scale = Vector2(scale_pulse, scale_pulse)

# =============================================================
# IMPACT EFFECT (saat polisi berhasil nabrak)
# =============================================================

func play_impact_effect(attack_lane: int) -> void:
	# 1. FULL SCREEN RED FLASH
	var flash = ColorRect.new()
	flash.anchors_preset = 15
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.color = Color(1.0, 0.0, 0.0, 0.7)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 100
	add_child(flash)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "color", Color(1.0, 0.0, 0.0, 0.0), 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	flash_tween.tween_callback(flash.queue_free)
	
	# 2. WHITE FLICKER
	var white = ColorRect.new()
	white.anchors_preset = 15
	white.anchor_right = 1.0
	white.anchor_bottom = 1.0
	white.color = Color(1.0, 1.0, 1.0, 0.6)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white.z_index = 101
	add_child(white)
	
	var white_tween = create_tween()
	white_tween.tween_property(white, "color", Color(1.0, 1.0, 1.0, 0.0), 0.15)
	white_tween.tween_callback(white.queue_free)
	
	# 3. "CRASH!" TEXT
	var crash_label = Label.new()
	crash_label.text = "CRASH!"
	crash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crash_label.anchors_preset = 8
	crash_label.anchor_left = 0.5
	crash_label.anchor_top = 0.5
	crash_label.anchor_right = 0.5
	crash_label.anchor_bottom = 0.5
	crash_label.offset_left = -200
	crash_label.offset_top = -60
	crash_label.offset_right = 200
	crash_label.offset_bottom = 60
	crash_label.add_theme_font_size_override("font_size", 90)
	crash_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.05, 1.0))
	crash_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	crash_label.add_theme_constant_override("outline_size", 10)
	crash_label.pivot_offset = Vector2(200, 60)
	crash_label.scale = Vector2(0.1, 0.1)
	crash_label.modulate = Color(1, 1, 1, 0)
	crash_label.z_index = 102
	crash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crash_label)
	
	var text_tween = create_tween()
	text_tween.set_parallel(true)
	text_tween.tween_property(crash_label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	text_tween.tween_property(crash_label, "modulate", Color(1, 1, 1, 1), 0.15)
	
	var text_tween2 = create_tween()
	text_tween2.tween_interval(0.5)
	text_tween2.tween_property(crash_label, "modulate", Color(1, 1, 1, 0), 0.4)
	text_tween2.tween_property(crash_label, "scale", Vector2(1.5, 1.5), 0.4)
	text_tween2.tween_callback(crash_label.queue_free)
	
	# 4. SPEED LINES
	_spawn_speed_lines(attack_lane)
	
	# 5. Mirror areas flash
	_flash_mirror_areas()

func _spawn_speed_lines(attack_lane: int) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var num_lines = 8
	
	for i in range(num_lines):
		var line = ColorRect.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.z_index = 99
		
		var line_height = randf_range(2, 6)
		var line_width = randf_range(80, 200)
		line.size = Vector2(line_width, line_height)
		
		var start_x: float
		var end_x: float
		match attack_lane:
			-1:
				start_x = -line_width
				end_x = viewport_size.x + 50
			1:
				start_x = viewport_size.x
				end_x = -line_width - 50
			_:
				start_x = viewport_size.x * 0.5 - line_width * 0.5
				end_x = start_x + (randf_range(-200, 200))
		
		var y_pos = randf_range(viewport_size.y * 0.2, viewport_size.y * 0.8)
		line.position = Vector2(start_x, y_pos)
		
		var r = randf_range(0.8, 1.0)
		var g = randf_range(0.1, 0.4)
		line.color = Color(r, g, 0.0, 0.8)
		
		add_child(line)
		
		var delay = randf_range(0.0, 0.15)
		var speed = randf_range(0.15, 0.35)
		var line_tween = create_tween()
		line_tween.tween_interval(delay)
		line_tween.set_parallel(true)
		line_tween.tween_property(line, "position:x", end_x, speed).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		line_tween.tween_property(line, "color:a", 0.0, speed)
		
		var cleanup_tween = create_tween()
		cleanup_tween.tween_interval(delay + speed + 0.1)
		cleanup_tween.tween_callback(line.queue_free)

func _flash_mirror_areas() -> void:
	# Flash merah di area spion saat impact
	for area in [left_mirror_area, rearview_mirror_area]:
		if not is_instance_valid(area) or not area.visible:
			continue
		var flash_rect = ColorRect.new()
		flash_rect.size = area.size
		flash_rect.color = Color(1.0, 0.0, 0.0, 0.6)
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(flash_rect)
		
		var ft = create_tween()
		ft.tween_property(flash_rect, "color:a", 0.0, 0.4)
		ft.tween_callback(flash_rect.queue_free)

# =============================================================
# UTILITY
# =============================================================

func _hide_all() -> void:
	left_mirror_area.visible = false
	rearview_mirror_area.visible = false
	warning_left.visible = false
	warning_center.visible = false
	warning_right.visible = false
	charge_flash.visible = false
	
	for unit_id in _police_icons.keys():
		_hide_unit_icons(unit_id)

func cleanup() -> void:
	for unit_id in _police_icons.keys():
		_remove_unit_icons(unit_id)
	_police_icons.clear()
