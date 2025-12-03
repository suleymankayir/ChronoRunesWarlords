class_name SaveManager extends Node

# Kayıt dosyasının yolu (user:// demek, telefonun/PC'nin güvenli klasörü demektir)
const SAVE_PATH = "user://savegame.cfg"

# Oyun Verileri (Varsayılan değerler)
var game_data = {
	"high_score": 0,
	"total_gold": 0
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

# Skor güncelleme yardımcısı
func update_high_score(current_score: int) -> void:
	if current_score > game_data["high_score"]:
		game_data["high_score"] = current_score
		save_data() # Yeni rekor kırılınca hemen kaydet!
		print("YENİ REKOR!")
