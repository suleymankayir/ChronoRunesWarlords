class_name GameOverUI extends Control

signal restart_requested # MainGame'e "Baştan başlat" diyecek
signal menu_requested
@onready var score_label: Label = $TextureRect/ScoreLabel
@onready var title_label: Label = $TextureRect/TitleLabel # YOLU KONTROL ET!
@onready var restart_button: Button = $TextureRect/RestartButton # YOLU KONTROL ET!
@onready var background_image: TextureRect = $TextureRect
@onready var menu_button: Button = $TextureRect/MenuButton # Yolunu kontrol et!


func _ready() -> void:
	# Başlangıçta görünmez olsun
	visible = false
	# Butona basılınca sinyal gönder
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
func show_result(is_victory: bool, final_score:int) -> void:
	visible = true
	get_tree().paused = true
	
	SaveM.update_high_score(final_score)
	var best_score = SaveM.game_data["high_score"]
	
	score_label.text = "SKOR: %d\nEN İYİ: %d" % [final_score, best_score]
	
	if final_score >= best_score and final_score > 0:
		score_label.modulate = Color.YELLOW # Rekor kırıldıysa altın rengi yap!
		score_label.text += "\nYENİ REKOR!"
	
	# 1. Önce Metin ve Renkleri Ayarla (Setup)
	if is_victory:
		title_label.text = "ZAFER!"
		title_label.modulate = Color("#5cd65c") # RPG Yeşili
		# MONETIZASYON FIRSATI: Buraya "2x Ödül" butonu konulur.
	else:
		title_label.text = "YENİLGİ..."
		title_label.modulate = Color("#ff4d4d") # Kan Kırmızısı
		# MONETIZASYON FIRSATI: Buraya "Revive" (Canlan) butonu konulur.
	
	# 2. Sonra Animasyonu Başlat (Action)
	# Tek bir Tween bloğu yeterli.
	
	# Başlangıç durumu: Küçücük olsun (Görünmez gibi)
	background_image.scale = Vector2.ZERO
	# Merkezden büyüsün diye pivotu ortaya alıyoruz
	background_image.pivot_offset = background_image.size / 2
	
	# "Pop" efektiyle büyüt
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(background_image, "scale", Vector2(1.0, 1.0), 0.4)

func _on_restart_pressed() -> void:
	# Oyunu tekrar akışkan hale getir
	get_tree().paused = false
	restart_requested.emit()
	queue_free() # Kendini yok et (MainGame yenisini yaratır veya sahne resetlenir)
	
func _on_menu_pressed() -> void:
	get_tree().paused = false # Oyunu çözmeyi unutma!
	# Direkt sahne değiştir:
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainMenu.tscn")
