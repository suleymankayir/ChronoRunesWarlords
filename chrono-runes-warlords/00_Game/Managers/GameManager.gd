class_name GameManager extends Node

# OYUNUN BEYNİ
# Bu script oyunun genel akışını (State) yönetir.

signal state_changed(new_state: GameState)

enum GameState {
	BOOT,       # Oyun açılışı, logo vb.
	MAIN_MENU,  # Ana menü ekranı
	COMBAT,     # Savaş/Puzzle ekranı
	PAUSE       # Duraklatma
}

# Şu anki durumu tutan değişken
var current_state: GameState = GameState.BOOT

# Oyun başladığında çalışır
func _ready() -> void:
	print("GameManager Başlatıldı.")
	# Test için direkt menüye geçiş yapıyoruz
	change_state(GameState.MAIN_MENU)

# Durum değiştirme fonksiyonu
func change_state(target_state: GameState) -> void:
	if current_state == target_state:
		return
		
	current_state = target_state
	state_changed.emit(current_state)
	
	_handle_state_logic(current_state)

# Duruma göre ne yapılacağını seçen merkez
func _handle_state_logic(state: GameState) -> void:
	match state:
		GameState.BOOT:
			pass # İleride buraya logo yükleme gelecek
		GameState.MAIN_MENU:
			print("Durum: ANA MENÜ - UI Yükleniyor...")
			# Buraya UI Sahnesi instance edilecek
		GameState.COMBAT:
			print("Durum: SAVAŞ - Puzzle Tahtası ve Düşmanlar Hazırlanıyor...")
		GameState.PAUSE:
			print("Durum: PAUSE - Oyun durduruldu.")
