class_name AudioManager extends Node

# --- SES KÜTÜPHANESİ (Eski sistemin çalışmaya devam etsin diye) ---
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

# MÜZİK AYARLARI
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
# HİBRİT SFX FONKSİYONU (Sihir Burada)
# ------------------------------------------------------------------------------
# 'data' değişkeni String ("swap") de olabilir, AudioStream (dosya) de olabilir.
# Tip belirtmedik (Variant), içeride kontrol edeceğiz.
func play_sfx(data, pitch_scale: float = 1.0) -> void:
	var stream_to_play: AudioStream = null

	# SENARYO 1: Eski sistem (String gelirse)
	if data is String:
		if sounds.has(data):
			stream_to_play = sounds[data]
		else:
			print("⚠️ HATA: Ses sözlükte bulunamadı -> ", data)
			return

	# SENARYO 2: Yeni sistem (AudioStream gelirse - SummonUI burayı kullanır)
	elif data is AudioStream:
		stream_to_play = data

	# SENARYO 3: Hatalı veri
	else:
		print("⚠️ HATA: play_sfx'e geçersiz veri tipi yollandı!")
		return

	# --- ÇALMA İŞLEMİ ---
	if stream_to_play:
		var player = AudioStreamPlayer.new()
		player.stream = stream_to_play
		player.bus = "SFX"
		player.pitch_scale = pitch_scale
		
		add_child(player)
		player.play()
		# Çalma bitince player'ı hafızadan sil (Memory Leak önleyici)
		player.finished.connect(player.queue_free)

# ------------------------------------------------------------------------------
# MÜZİK FONKSİYONLARI (Aynen korundu)
# ------------------------------------------------------------------------------
func play_music(stream: AudioStream) -> void:
	# 1. Önceki fade-out varsa iptal et
	if music_tween:
		music_tween.kill()
	
	# Eğer player yoksa oluştur (Crash önlemi)
	if not music_player:
		music_player = AudioStreamPlayer.new()
		music_player.name = "MusicPlayer"
		add_child(music_player)

	# 2. Sesi her zaman normal seviyeye çek (Çünkü fade-out kısmış olabilir)
	music_player.volume_db = 0.0
	
	# 3. Aynı şarkıysa ve zaten çalıyorsa baştan başlatma
	if music_player.stream == stream and music_player.playing:
		return
		
	# 4. Yeni şarkıyı başlat
	music_player.stream = stream
	music_player.bus = "Music"
	music_player.play()

func stop_music() -> void:
	if music_tween:
		music_tween.kill()
	
	if music_player and music_player.playing:
		# Tween'i sınıf değişkenine ata ki play_music onu bulup durdurabilsin
		music_tween = create_tween()
		music_tween.tween_property(music_player, "volume_db", -80.0, 1.0)
		music_tween.tween_callback(music_player.stop)

# ------------------------------------------------------------------------------
# SES AYARLARI (Yeni)
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
