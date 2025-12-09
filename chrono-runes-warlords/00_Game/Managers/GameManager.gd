extends Node

# --- SİNYALLER ---
signal state_changed(new_state: GameState)
signal gold_changed(new_amount: int) # UI güncellemeleri için yeni sinyal

# --- ENUMLAR ---
enum GameState {
	BOOT,
	MAIN_MENU,
	COMBAT,
	PAUSE
}

# --- STATE DEĞİŞKENLERİ ---
var current_state: GameState = GameState.BOOT

# --- EKONOMİ VE ENVANTER DEĞİŞKENLERİ (YENİ) ---
var total_gold: int = 5000 
var owned_characters: Array[Resource] = [] 

# --- SABİTLER ---
const SAVE_PATH: String = "user://savegame.save"

# ==============================================================================
# LIFECYCLE (YAŞAM DÖNGÜSÜ)
# ==============================================================================
func _ready() -> void:
	print("🧠 GameManager Başlatılıyor...")
	
	# 1. Önce kayıtlı veriyi yükle (Para, Eşyalar)
	_load_game_data()
	
	# 2. Sonra oyunu başlat (State'i tetikle)
	# Gerçek bir oyunda burası BOOT olur, açılış animasyonu biter sonra MENU'ye geçer.
	change_state(GameState.MAIN_MENU)

# ==============================================================================
# BÖLÜM 1: STATE MACHINE (DURUM YÖNETİMİ)
# ==============================================================================
func change_state(target_state: GameState) -> void:
	if current_state == target_state:
		return
		
	current_state = target_state
	state_changed.emit(current_state)
	_handle_state_logic(current_state)

func _handle_state_logic(state: GameState) -> void:
	match state:
		GameState.BOOT:
			pass
		GameState.MAIN_MENU:
			print("Durum: ANA MENÜ - UI Hazırlanıyor...")
		GameState.COMBAT:
			print("Durum: SAVAŞ - Sahne Hazırlanıyor...")
		GameState.PAUSE:
			print("Durum: PAUSE - Oyun Durduruldu.")

# ==============================================================================
# BÖLÜM 2: EKONOMİ SİSTEMİ (ECONOMY SYSTEM)
# ==============================================================================

# Para Harcama (Boolean döner: Yeterli para varsa true, yoksa false)
func remove_gold(amount: int) -> bool:
	if total_gold >= amount:
		total_gold -= amount
		gold_changed.emit(total_gold) # UI'a haber ver
		_save_game_data() # Değişikliği hemen kaydet
		print("💰 Harcama yapıldı. Yeni Bakiye: ", total_gold)
		return true
	else:
		print("❌ Yetersiz Bakiye! İstenen: ", amount, " Mevcut: ", total_gold)
		return false

# Para Ekleme (Ödül vb.)
func add_gold(amount: int) -> void:
	total_gold += amount
	gold_changed.emit(total_gold)
	_save_game_data()

# Karakter Ekleme
func add_character(character: Resource) -> void:
	owned_characters.append(character)
	# Resource kaydetmek şimdilik kapalı (RAM'de tutuyoruz)
	print("🎒 Envantere Eklendi: ", character.resource_name if "resource_name" in character else "Yeni Karakter")

# ==============================================================================
# BÖLÜM 3: SAVE / LOAD (KAYIT SİSTEMİ)
# ==============================================================================
func _save_game_data() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var character_paths: Array[String] = []
		for item in owned_characters:
			# resource_path, dosyanın bilgisayardaki adresidir (res://...)
			character_paths.append(item.resource_path)
		
		
		var data = {
			"gold": total_gold,
			"inventory": character_paths
		}
		
		file.store_string(JSON.stringify(data))
		print("💾 Oyun Kaydedildi (Altın + Envanter).")
		
		
		
		
func _load_game_data() -> void:
	
	if not FileAccess.file_exists(SAVE_PATH):
		print("📂 Kayıt dosyası bulunamadı, yeni oyun başlatılıyor.")
		return 
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var data = JSON.parse_string(json_string)
		
		if data:
			total_gold = int(data.get("gold", 5000))
			
			owned_characters.clear()
			var saved_paths = data.get("inventory", [])
			
			for path in saved_paths:
				# resource_exists ile dosya hala orada mı kontrol et (Güvenlik)
				if ResourceLoader.exists(path):
					var character = load(path)
					owned_characters.append(character)
				else:
					print("⚠️ HATA: Kayıtlı karakter dosyası bulunamadı -> ", path)
			
			print("📂 Kayıt Yüklendi. Cüzdan: ", total_gold, " | Karakter Sayısı: ", owned_characters.size())
