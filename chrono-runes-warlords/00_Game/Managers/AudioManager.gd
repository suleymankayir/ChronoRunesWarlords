class_name AudioManager extends Node

# --- SES KÜTÜPHANESİ (Senin Listene Göre) ---
var sounds: Dictionary = {
	"swap": preload("res://01_Assets/Audio/SFX/swap.wav"),
	"match": preload("res://01_Assets/Audio/SFX/match.wav"),
	"error": preload("res://01_Assets/Audio/SFX/error.wav"),
	"combo": preload("res://01_Assets/Audio/SFX/combo.wav"),
	
	"playerAttack": preload("res://01_Assets/Audio/SFX/playerAttack.wav"), # Eski "hit"
	"enemyHit": preload("res://01_Assets/Audio/SFX/enemyHit.wav"),         # Düşman acı çekme
	"enemyAttack": preload("res://01_Assets/Audio/SFX/enemyAttack.wav"),   # Düşman saldırısı
	"enemyDeath": preload("res://01_Assets/Audio/SFX/enemyDeath.wav"),     # Düşman ölümü
	
	"victory": preload("res://01_Assets/Audio/SFX/victory.wav"), # Eski "win"
	"gameover": preload("res://01_Assets/Audio/SFX/gameover.wav") # Eski "lose"
}

# MÜZİK DOSYASI (Bunun adını klasöründeki müzik dosyasıyla aynı yap!)
var bg_music = preload("res://01_Assets/Audio/Music/bg_music.mp3") 
var music_tween: Tween
@onready var music_player: AudioStreamPlayer = $MusicPlayer

func _ready() -> void:
	# MÜZİĞİ BAŞLAT (Yorum satırını kaldırdık)
	if bg_music:
		play_music(bg_music)

func play_music(stream: AudioStream) -> void:
	if music_tween:
		music_tween.kill()
	
	music_player.volume_db = 0.0
	
	if music_player.stream == stream and music_player.playing:
		return
		
	music_player.stream = stream
	music_player.bus = "Music"
	music_player.play()

func stop_music() -> void:
	if music_tween:
		music_tween.kill()
	
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, 1.0) # Sesi tamamen kıs (-80 dB)
	tween.tween_callback(music_player.stop)
	
	
func play_sfx(sound_name: String, pitch_scale: float = 1.0) -> void:
	if not sounds.has(sound_name):
		print("HATA: Ses dosyası tanımlı değil -> ", sound_name)
		return
	
	var player = AudioStreamPlayer.new()
	player.stream = sounds[sound_name]
	player.bus = "SFX"
	player.pitch_scale = pitch_scale
	
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
