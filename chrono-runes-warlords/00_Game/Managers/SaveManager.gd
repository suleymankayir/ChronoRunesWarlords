class_name SaveManager extends Node

# Kayıt dosyasının yolu (user:// demek, telefonun/PC'nin güvenli klasörü demektir)
const SAVE_PATH = "user://savegame.cfg"

# Oyun Verileri (Varsayılan değerler)
var game_data = {
	"high_score": 0,
	"total_gold": 0,
	"damage_level": 1, # Silah seviyesi
	"hp_level": 1,      # Zırh seviyesi
	"owned_heroes": []
}

func _ready() -> void:
	load_data() # Oyun açılınca verileri yükle

func save_data() -> void:
	var config = ConfigFile.new()
	
	# Verileri dosyaya işle
	config.set_value("Player", "high_score", game_data["high_score"])
	config.set_value("Player", "total_gold", game_data["total_gold"])
	
	# Dosyayı fiziksel olarak kaydet
	config.save(SAVE_PATH)
	print("Oyun Kaydedildi: ", game_data)

func load_data() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	
	# Eğer dosya varsa ve hata yoksa
	if err == OK:
		game_data["high_score"] = config.get_value("Player", "high_score", 0)
		game_data["total_gold"] = config.get_value("Player", "total_gold", 0)
		print("Veriler Yüklendi: ", game_data)
	else:
		print("Kayıt dosyası bulunamadı, yeni oyun başlatılıyor.")
		save_data() # Dosya yoksa oluştur

func get_player_max_hp() -> int:
	var base_hp = 500
	# Her seviye %10 can ekler
	var bonus = (game_data["hp_level"] - 1) * 0.10
	return int(base_hp * (1.0 + bonus))
	
func get_player_damage_multiplier() -> float:
	var base_dmg = 1.0
	# Her seviye %10 hasar artışı
	var bonus = (game_data["damage_level"] - 1) * 0.10
	return base_dmg + bonus

func get_upgrade_cost(current_level: int) -> int:
	# Maliyet formülü: 100 * Level (Basit tutalım şimdilik)
	return 100 * current_level

# Skor güncelleme yardımcısı
func update_high_score(current_score: int) -> void:
	if current_score > game_data["high_score"]:
		game_data["high_score"] = current_score
		save_data() # Yeni rekor kırılınca hemen kaydet!
		print("YENİ REKOR!")
		
func unlock_hero(hero_id: String) -> void:
	# Eğer bu kahraman bizde yoksa listeye ekle
	if not game_data["owned_heroes"].has(hero_id):
		game_data["owned_heroes"].append(hero_id)
		save_data()
		print("KAYIT: Yeni Kahraman Eklendi -> ", hero_id)
	else:
		print("BİLGİ: Bu kahraman zaten var. (İleride buna 'Shard' veririz)")
