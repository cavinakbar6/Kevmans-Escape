extends DirectionalLight3D

@export var day_duration: float = 50.0 # default = 50.0
@export var transition_duration: float = 3.0 # default = 3.0
@export var night_duration: float = 40.0 # default = 40.0

# kontrol gelap malam
@export var night_min_intensity: float = 0.2

var max_energy: float = 1.0
var world_env: WorldEnvironment
var time_passed: float = 0.0

# Warna
var color_day = Color(1.0, 1.0, 0.95)
var color_sunset = Color(1.0, 0.5, 0.2)
var color_night = Color(0.2, 0.3, 0.6)

func _ready() -> void:
	max_energy = light_energy
	world_env = get_parent().get_node_or_null("WorldEnvironment")

func _process(delta: float) -> void:
	time_passed += delta
	
	var total_cycle = day_duration + transition_duration + night_duration + transition_duration
	var t = fmod(time_passed, total_cycle)
	
	var intensity_factor = 0.0
	var current_color = color_day
	
	# === SIANG ===
	if t < day_duration:
		intensity_factor = 1.0
		current_color = color_day
	
	# === SUNSET ===
	elif t < day_duration + transition_duration:
		var local_t = (t - day_duration) / transition_duration
		local_t = smoothstep(0.0, 1.0, local_t)
		
		intensity_factor = lerp(1.0, night_min_intensity, local_t)
		
		if local_t < 0.5:
			var t1 = local_t * 2.0
			current_color = color_day.lerp(color_sunset, t1)
		else:
			var t2 = (local_t - 0.5) * 2.0
			current_color = color_sunset.lerp(color_night, t2)
	
	
	# === MALAM ===
	elif t < day_duration + transition_duration + night_duration:
		intensity_factor = night_min_intensity
		current_color = color_night
	
	
	# === SUNRISE ===
	else:
		var local_t = (t - (day_duration + transition_duration + night_duration)) / transition_duration
		local_t = smoothstep(0.0, 1.0, local_t)
		
		intensity_factor = lerp(night_min_intensity, 1.0, local_t)
		
		if local_t < 0.5:
			var t1 = local_t * 2.0
			current_color = color_night.lerp(color_sunset, t1)
		else:
			var t2 = (local_t - 0.5) * 2.0
			current_color = color_sunset.lerp(color_day, t2)
	
	
	# Terapkan cahaya
	light_energy = max_energy * intensity_factor
	light_color = current_color
	
	# ENVIRONMENT
	if is_instance_valid(world_env) and world_env.environment != null:
		var env = world_env.environment
		
		env.background_energy_multiplier = max(intensity_factor, 0.01)
		env.ambient_light_energy = max(intensity_factor, night_min_intensity)
		env.ambient_light_color = current_color
		
		if env.fog_enabled:
			env.fog_light_color = current_color
			env.fog_density = lerp(0.002, 0.01, 1.0 - intensity_factor)

func is_daytime() -> bool:
	var total_cycle = day_duration + transition_duration + night_duration + transition_duration
	var t = fmod(time_passed, total_cycle)
	
	return t < day_duration
