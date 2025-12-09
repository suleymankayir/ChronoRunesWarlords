class_name CollectionUI extends Control

# --- AYARLAR ---
# Az önce yaptığımız 'Kutu' sahnesini buraya sürükleyeceğiz
@export var slot_template: PackedScene 
@export var popup_template: PackedScene # [NEW] Popup sahnesini buraya ata
@export var popup_scene: PackedScene
# --- REFERANSLAR ---
@export var grid_container: GridContainer
@export var btn_back: Button
@export var character_popup: CharacterDetailPopup

func _ready() -> void:
	# Geri butonunu bağla
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	
	# Ekrana karakterleri diz
	_populate_grid()

func _populate_grid() -> void:
	
	print("🔍 Koleksiyon Ekranı Yükleniyor...")
	print("📊 GM Karakter Sayısı: ", GM.owned_characters.size())
	# 1. Önce eski kutuları temizle (Temiz sayfa)
	# Grid'in altındaki tüm çocukları siliyoruz
	for child in grid_container.get_children():
		child.queue_free()
	
	# 2. GameManager'dan listeyi çek
	var my_characters = GM.owned_characters
	
	if my_characters.is_empty():
		print("🎒 Envanter boş.")
		return

	# 3. Her karakter için bir kutu yarat
	for character_data in my_characters:
		# Kutuyu oluştur (Instantiate)
		var new_slot = slot_template.instantiate()
		
		if not new_slot.has_method("set_slot_data"):
			push_error("HATA: Oluşturulan slotta 'set_slot_data' fonksiyonu yok! Script bağlı mı?")
			return
			
		new_slot.set_slot_data(character_data)
		new_slot.clicked.connect(_on_slot_clicked)
		
					
		grid_container.add_child(new_slot)
		
		
func _on_slot_clicked(data: CharacterData) -> void:
	if not popup_scene:
		push_error("⚠️ HATA: Popup Scene atanmamış!")
		return
	var popup = popup_scene.instantiate() as CharacterDetailPopup
	add_child(popup)
	popup.open(data)

func _on_back_pressed() -> void:
	# Ana menüye dön
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainMenu.tscn")

# Yardımcı fonksiyon: Enum'ı yazıya çevirir
func _get_rarity_name(rarity_enum) -> String:
	# Senin Enum yapına göre düzenle
	match rarity_enum:
		0: return "Common"
		1: return "Rare"
		2: return "Epic"
		3: return "Legendary"
	return "Unknown"

func _get_color_by_rarity(rarity_enum) -> Color:
	match rarity_enum:
		CharacterData.Rarity.COMMON:
			return Color.GRAY
		CharacterData.Rarity.RARE:
			return Color.DODGER_BLUE
		CharacterData.Rarity.EPIC:
			return Color.PURPLE
		CharacterData.Rarity.LEGENDARY:
			return Color.GOLD
	return Color.WHITE


func _on_hero_slot_hero_selected(data: CharacterData) -> void:
	
	print(">>> SEÇİLEN KAHRAMAN: ", data.character_name)
	
	if character_popup:
		# Veriyi popup'a paslıyoruz ve açıyoruz
		character_popup.open(data)
	else:
		print("!!! HATA: CollectionUI sahnesine Popup'ı koymayı veya Inspector'dan atamayı unuttun!")
