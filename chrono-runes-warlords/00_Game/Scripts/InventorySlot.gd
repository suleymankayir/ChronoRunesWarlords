class_name InventorySlot extends TextureRect

# --- SIGNALS ---
signal clicked(character_data: CharacterData)

# --- REFERENCES ---
var _data: CharacterData

# Node References
@onready var hero_image: TextureRect = $SlotRoot/MarginContainer/HeroImage
@onready var border: ColorRect = $SlotRoot/Border

func _ready() -> void:
	# Tıklama olaylarını almak için mouse_filter ayarını kontrol ediyoruz
	mouse_filter = MouseFilter.MOUSE_FILTER_STOP
	
	# Eğer data daha önce (set_slot_data ile) set edildiyse, şimdi UI'ı güncelle
	if _data:
		_update_ui()

func set_slot_data(data: CharacterData) -> void:
	_data = data
	
	# Eğer node hazırsa hemen güncelle, değilse _ready'i bekle
	if is_node_ready():
		_update_ui()

func _update_ui() -> void:
	if not _data: return
	
	# 1. Görseli yükle
	if hero_image:
		hero_image.texture = _data.full_body_art
	
	# 2. Çerçeve rengini nadirliğe göre ayarla
	if border:
		border.color = _get_color_by_rarity(_data.rarity)

func _gui_input(event: InputEvent) -> void:
	# Sol tık kontrolü
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _data:
				clicked.emit(_data)

# Yardımcı Fonksiyon: Renk seçimi
func _get_color_by_rarity(rarity_enum: CharacterData.Rarity) -> Color:
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
