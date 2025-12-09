# SCRIPT 2: CharacterDetailPopup.gd
class_name CharacterDetailPopup extends Control

# --- SIGNALS ---
signal popup_closed
signal upgrade_requested(character_id: String)

# --- CONFIGURATION ---
const ANIM_DURATION: float = 0.3
const ANIM_SCALE_START: Vector2 = Vector2(0.8, 0.8)
const ANIM_SCALE_END: Vector2 = Vector2.ONE
const DIM_ALPHA_START: float = 0.0
const DIM_ALPHA_END: float = 1.0

# --- UI COMPONENTS ---
@export_group("UI References")
@export var background_dim: ColorRect
@export var content_panel: Control
@export var hero_image: TextureRect
@export var hero_name: Label
@export var hero_rarity: Label
@export var hero_element: Label
@export var hero_description: Label
@export var upgrade_button: Button

# --- PRIVATE VARIABLES ---
var _current_data: CharacterData

func _ready() -> void:
	visible = false
	
	if content_panel:
		content_panel.pivot_offset = content_panel.size / 2
		
	if background_dim:
		background_dim.mouse_filter = MouseFilter.MOUSE_FILTER_STOP
		background_dim.gui_input.connect(_on_background_input)
		
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_pressed)

# --- PUBLIC API ---

func open(data: CharacterData) -> void:
	print(">>> 3. OPEN FONKSİYONU ÇALIŞTI! Gelen İsim: ", data.character_name) # BU SATIRI EKLE
	_current_data = data
	
	_populate_ui(data)
	_animate_open()

func close() -> void:
	_animate_close()

# --- PRIVATE HELPERS ---

func _populate_ui(data: CharacterData) -> void:
	if not data: return

	# Use requested field names
	if hero_name:
		hero_name.text = data.character_name
		
	if hero_image:
		hero_image.texture = data.portrait
		
	if hero_description:
		hero_description.text = data.description
		
	if hero_rarity:
		# Convert Enum to String safely
		var rarity_str = CharacterData.Rarity.keys()[data.rarity].capitalize()
		hero_rarity.text = rarity_str
		hero_rarity.modulate = data.rarity_color # Use color from data as requested
		
	if hero_element:
		hero_element.text = data.element_text

func _animate_open() -> void:
	visible = true
	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	if content_panel:
		content_panel.scale = ANIM_SCALE_START
		tween.tween_property(content_panel, "scale", ANIM_SCALE_END, ANIM_DURATION)
		
	if background_dim:
		background_dim.modulate.a = DIM_ALPHA_START
		tween.tween_property(background_dim, "modulate:a", DIM_ALPHA_END, ANIM_DURATION * 0.8)

func _animate_close() -> void:
	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	if content_panel:
		tween.tween_property(content_panel, "scale", Vector2.ZERO, ANIM_DURATION * 0.8)
		
	if background_dim:
		tween.tween_property(background_dim, "modulate:a", DIM_ALPHA_START, ANIM_DURATION * 0.8)
		
	tween.chain().tween_callback(func():
		visible = false
		popup_closed.emit()
		queue_free()
	)

# --- EVENTS ---

func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			close()

func _on_upgrade_pressed() -> void:
	if _current_data:
		upgrade_requested.emit(_current_data.id)

# --- TEST FUNCTION (User Requested) ---
func _on_test_button_pressed() -> void:
	print(">>> 1. SİNYAL ALINDI: Test butonuna basıldı! <<<") # BU SATIRI EKLE
	var dummy_data = CharacterData.new()
	dummy_data.id = "test_999"
	dummy_data.character_name = "Test Hero" 
	dummy_data.description = "Dummy data for testing popup."
	dummy_data.element_text = "Void"
	dummy_data.rarity = CharacterData.Rarity.LEGENDARY
	dummy_data.rarity_color = Color.GOLD
	dummy_data.level = 99
	
	print(">>> 2. VERİ HAZIRLANDI, OPEN ÇAĞRILIYOR... <<<") # BU SATIRI EKLE
	open(dummy_data)


func _on_test_butonu_pressed() -> void:
	pass # Replace with function body.
