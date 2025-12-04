class_name SummonManager extends Node

# Tüm karakterlerin listesi
var all_characters: Array[CharacterData] = []

func _ready() -> void:
	load_database()

# Klasördeki .tres dosyalarını bulup listeye ekler
func load_database() -> void:
	var path = "res://00_Game/Resources/Characters/"
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				# Dosyayı yükle ve listeye at
				var hero = load(path + "/" + file_name) as CharacterData
				if hero:
					all_characters.append(hero)
			
			file_name = dir.get_next()
			
	print("GACHA SİSTEMİ HAZIR. Havuzda ", all_characters.size(), " karakter var.")

# Rastgele bir karakter seçer
func pull_random_hero() -> CharacterData:
	if all_characters.is_empty():
		push_error("HATA: Karakter havuzu boş! .tres dosyalarını kontrol et.")
		return null
		
	return all_characters.pick_random()
