extends Node3D
@export var kumpulan_suara: Array[AudioStream] = []
func _ready() -> void:
	# Putar animasinya (pastikan nama animasinya "default")
	if has_node("AnimatedSprite3D"):
		$AnimatedSprite3D.play("default")
	if has_node("Ledakan"):
		if kumpulan_suara.size() > 0:
			$Ledakan.stream = kumpulan_suara.pick_random()
		$Ledakan.pitch_scale = randf_range(0.8, 1.2)
	$Ledakan.play()
	await $Ledakan.finished
	queue_free()
