extends Node

# Autoload singleton untuk menyimpan High Score secara persisten
# Data disimpan di user://highscore.cfg agar tetap ada walau game ditutup

var config := ConfigFile.new()
var save_path := "user://highscore.cfg"
var high_score: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_high_score()

func load_high_score() -> void:
	if config.load(save_path) == OK:
		high_score = config.get_value("score", "high_score", 0)

func save_high_score() -> void:
	config.set_value("score", "high_score", high_score)
	config.save(save_path)

# Cek apakah skor baru lebih tinggi, kalau iya update dan simpan
# Return true jika ini rekor baru
func try_set_high_score(new_score: int) -> bool:
	if new_score > high_score:
		high_score = new_score
		save_high_score()
		return true
	return false

func get_high_score() -> int:
	return high_score
