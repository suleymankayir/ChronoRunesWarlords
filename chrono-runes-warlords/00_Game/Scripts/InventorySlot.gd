class_name InventorySlot extends TextureRect

# --- SIGNALS ---
signal clicked(character_data: CharacterData)

# --- REFERENCES ---
var _data: CharacterData

# Node References
@onready var hero_image: TextureRect = $SlotRoot/MarginContainer/HeroImage
@onready var border: ColorRect = $SlotRoot/Border

func _ready() -> void:
	# Check mouse_filter setting to receive click events
	mouse_filter = MouseFilter.MOUSE_FILTER_STOP
	
	# If data was set before (via set_slot_data), update UI now
	if _data:
		_update_ui()

func set_slot_data(data: CharacterData) -> void:
	_data = data
	
	# If node is ready update immediately, otherwise wait for _ready
	if is_node_ready():
		_update_ui()

func _update_ui() -> void:
	if not _data: return
	
	# 1. Load visual
	if hero_image:
		hero_image.texture = _data.full_body_art
	
	# 2. Set border color by rarity
	if border:
		border.color = _get_color_by_rarity(_data.rarity)

func _gui_input(event: InputEvent) -> void:
	# Left click check
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _data:
				clicked.emit(_data)

# Helper Function: Color selection
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
