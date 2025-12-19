class_name AudioManager extends Node

# --- AUDIO LIBRARY (Kept for legacy system compatibility) ---
var sounds: Dictionary = {
	"swap": preload("res://01_Assets/Audio/SFX/swap.wav"),
	"match": preload("res://01_Assets/Audio/SFX/match.wav"),
	"error": preload("res://01_Assets/Audio/SFX/error.wav"),
	"combo": preload("res://01_Assets/Audio/SFX/combo.wav"),
	
	"playerAttack": preload("res://01_Assets/Audio/SFX/playerAttack.wav"),
	"enemyHit": preload("res://01_Assets/Audio/SFX/enemyHit.wav"),
	"enemyAttack": preload("res://01_Assets/Audio/SFX/enemyAttack.wav"),
	"enemyDeath": preload("res://01_Assets/Audio/SFX/enemyDeath.wav"),
	
	"victory": preload("res://01_Assets/Audio/SFX/victory.wav"),
	"gameover": preload("res://01_Assets/Audio/SFX/gameover.wav")
}

# MUSIC SETTINGS
var bg_music = preload("res://01_Assets/Audio/Music/bg_music.mp3") 
var music_tween: Tween
@onready var music_player: AudioStreamPlayer = $MusicPlayer

var music_volume: float = 1.0
var sfx_volume: float = 1.0

func _ready() -> void:
	if bg_music:
		play_music(bg_music)
		
	# Initialize volume variables from AudioServer
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		music_volume = db_to_linear(AudioServer.get_bus_volume_db(music_bus))
		
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		sfx_volume = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))

# ------------------------------------------------------------------------------
# HYBRID SFX FUNCTION (Magic Here)
# ------------------------------------------------------------------------------
# 'data' variable can be a String ("swap") or an AudioStream (file).
# Type not specified (Variant), checking internally.
func play_sfx(data, pitch_scale: float = 1.0) -> void:
	var stream_to_play: AudioStream = null

	# SCENARIO 1: Legacy system (if String)
	if data is String:
		if sounds.has(data):
			stream_to_play = sounds[data]
		else:
			print("⚠️ ERROR: Sound not found in dictionary -> ", data)
			return

	# SCENARIO 2: New system (if AudioStream - used by SummonUI)
	elif data is AudioStream:
		stream_to_play = data

	# SCENARIO 3: Invalid data
	else:
		print("⚠️ ERROR: Invalid data type sent to play_sfx!")
		return

	# --- PLAYING PROCESS ---
	if stream_to_play:
		var player = AudioStreamPlayer.new()
		player.stream = stream_to_play
		player.bus = "SFX"
		player.pitch_scale = pitch_scale
		
		add_child(player)
		player.play()
		# Delete player from memory when finished (Memory Leak prevention)
		player.finished.connect(player.queue_free)

# ------------------------------------------------------------------------------
# MUSIC FUNCTIONS (Kept as is)
# ------------------------------------------------------------------------------
func play_music(stream: AudioStream) -> void:
	# 1. Cancel previous fade-out if exists
	if music_tween:
		music_tween.kill()
	
	# Create player if not exists (Crash prevention)
	if not music_player:
		music_player = AudioStreamPlayer.new()
		music_player.name = "MusicPlayer"
		add_child(music_player)

	# 2. Always reset volume to normal (Fade-out might have lowered it)
	music_player.volume_db = 0.0
	
	# 3. Do not restart if same song is already playing
	if music_player.stream == stream and music_player.playing:
		return
		
	# 4. Start new song
	music_player.stream = stream
	music_player.bus = "Music"
	music_player.play()

func stop_music() -> void:
	if music_tween:
		music_tween.kill()
	
	if music_player and music_player.playing:
		# Assign Tween to class variable so play_music can find and stop it
		music_tween = create_tween()
		music_tween.tween_property(music_player, "volume_db", -80.0, 1.0)
		music_tween.tween_callback(music_player.stop)

# ------------------------------------------------------------------------------
# AUDIO SETTINGS (New)
# ------------------------------------------------------------------------------
func set_music_volume(value: float) -> void:
	music_volume = value
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx == -1: return
	
	if value <= 0.05:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx == -1: return
	
	if value <= 0.05:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
