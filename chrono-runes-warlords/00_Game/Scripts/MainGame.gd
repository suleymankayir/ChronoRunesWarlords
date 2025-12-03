extends Node2D

func _ready() -> void:
	# GM (GameManager) sinyalini dinle
	GM.state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(new_state: GM.GameState) -> void:
	var bg_rect = $Background
	
	# Duruma göre arkaplan rengini değiştir (Görsel Debugging)
	match new_state:
		GM.GameState.MAIN_MENU:
			# Koyu Mavi (Menü Hissi)
			bg_rect.color = Color("#1a1c2c") 
		GM.GameState.COMBAT:
			# Kan Kırmızısı (Savaş Hissi)
			bg_rect.color = Color("#3e1616")
