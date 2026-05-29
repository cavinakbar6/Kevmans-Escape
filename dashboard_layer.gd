extends CanvasLayer

@export var shake_decay: float = 5.0
@export var sway_smoothness: float = 3.0  # ✅ Makin besar = makin smooth/lambat
var shake_strength: float = 0.0
var sway_strength: float = 0.0
var target_sway: float = 0.0  # ✅ Target value untuk interpolasi smooth
var default_offset: Vector2 = Vector2.ZERO
var current_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	default_offset = offset
	current_offset = default_offset

func _process(delta: float) -> void:
	#print("shake_strength: ",shake_strength)
	if shake_strength > 0.0001:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		offset = default_offset + Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
	
	# ✅ Lerp current sway_strength menuju target_sway
	sway_strength = lerp(sway_strength, target_sway, sway_smoothness * delta)
	offset.x = default_offset.x + sway_strength
	
	#print("default offset x: ",default_offset.x)


# 🎳 Shake: langsung respond (instant)
func on_camera_shake(amount: float) -> void:
	shake_strength = amount * 100

# 🌊 Sway: smooth via target (tidak langsung jump)
func on_camera_sway(amount: float) -> void:
	target_sway = amount * 10 # ✅ Cukup set target, biarkan _process yang menghaluskan
