class_name CharacterDetailPopup extends Control

# --- UI REFERANSLARI ---
# Bu değişkenleri editörde ilgili Node'lara sürükle-bırak yapmalısın.
@export var hero_image: TextureRect
@export var hero_name: Label
@export var hero_rarity: Label
@export var hero_element: Label
@export var hero_description: Label

# Arkaplan Node'u (Tıklanabilir olması için ColorRect veya Panel olabilir)
@export var background_dim: Control 

func _ready() -> void:
	# Arkaplana tıklama olayını dinle
	if background_dim:
		background_dim.gui_input.connect(_on_background_input)

func set_data(data: CharacterData) -> void:
	# Verileri UI'a yaz
	if hero_image: hero_image.texture = data.full_body_art
	if hero_name: hero_name.text = data.name
	if hero_description: hero_description.text = data.description
	
	if hero_rarity:
		hero_rarity.text = _get_rarity_name(data.rarity)
		hero_rarity.modulate = _get_color_by_rarity(data.rarity)
		
	if hero_element:
		hero_element.text = _get_element_name(data.element)

func open() -> void:
	show()
	# Basit bir "Pop-up" animasyonu (Game Juice!)
	pivot_offset = size / 2
	scale = Vector2.ZERO
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)

func _on_background_input(event: InputEvent) -> void:
	# Arkaplana tıklandığında popup'ı kapat
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			close_popup()

func close_popup() -> void:
	# Kendini yok et (veya gizle)
	queue_free()

# --- YARDIMCI FONKSİYONLAR ---
func _get_rarity_name(rarity_enum: CharacterData.Rarity) -> String:
	return CharacterData.Rarity.keys()[rarity_enum].capitalize()

func _get_element_name(element_enum: CharacterData.Element) -> String:
	return CharacterData.Element.keys()[element_enum].capitalize()

func _get_color_by_rarity(rarity_enum: CharacterData.Rarity) -> Color:
	match rarity_enum:
		CharacterData.Rarity.COMMON: return Color.GRAY
		CharacterData.Rarity.RARE: return Color.DODGER_BLUE
		CharacterData.Rarity.EPIC: return Color.PURPLE
		CharacterData.Rarity.LEGENDARY: return Color.GOLD
	return Color.WHITE
