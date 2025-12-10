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
@export var gold_shop_popup: GoldShopPopup
@export var equip_button: Button

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
		
	if gold_shop_popup:
		gold_shop_popup.purchase_successful.connect(_on_gold_purchased)
		
	if equip_button:
		equip_button.pressed.connect(_on_equip_pressed)

# --- PUBLIC API ---

func open(data: CharacterData) -> void:
	print(">>> OPEN CALL: ", data.character_name) 
	
	# 1. State Reset (Crucial)
	show()
	modulate.a = 1.0
	scale = Vector2.ONE
	
	if content_panel:
		content_panel.visible = true
		content_panel.modulate.a = 1.0
		content_panel.scale = Vector2.ONE

	# 2. Data Handling
	_current_data = data
	_populate_ui(data)
	
	# 3. Team Button Logic
	if has_method("_update_equip_button_state") and data:
		var is_in_team = GameEconomy.is_hero_selected(data.id)
		_update_equip_button_state(is_in_team)
	
	# 4. Animation (Simple Entry)
	if content_panel:
		content_panel.scale = Vector2(0.9, 0.9)
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(content_panel, "scale", Vector2.ONE, 0.2)

func _on_close_pressed() -> void:
	hide()
	popup_closed.emit()

func close() -> void:
	_on_close_pressed()

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

	# [FIX] Update Upgrade Button with Dynamic Cost
	if upgrade_button:
		var cost = data.level * 100
		upgrade_button.text = "UPGRADE (%d G)" % cost

func _update_equip_button_state(in_team: bool) -> void:
	if not equip_button:
		return
		
	if in_team:
		equip_button.text = "TAKIMDAN ÇIKAR"
		equip_button.modulate = Color(1, 0.3, 0.3) # Red tint
	else:
		equip_button.text = "TAKIMA AL"
		equip_button.modulate = Color(0.3, 1, 0.3) # Green tint

func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			close()

func _on_upgrade_pressed() -> void:
	if not _current_data:
		return

	var cost = _current_data.level * 100
	
	if GameEconomy.has_enough_gold(cost):
		if GameEconomy.spend_gold(cost):
			# Success
			_current_data.level += 1
			
			# [CRITICAL FIX] Save to GameEconomy immediately!
			GameEconomy.save_hero_level(_current_data.id, _current_data.level)
			
			_populate_ui(_current_data) # Update UI text
			
			# Visual Feedback: Punch effect on hero image
			if hero_image:
				var tween = create_tween()
				tween.tween_property(hero_image, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.tween_property(hero_image, "scale", Vector2.ONE, 0.1)
				
			upgrade_requested.emit(_current_data.id) 
			print("Upgrade successful! New Level: ", _current_data.level)
	else:
		# Failure
		var missing_gold = cost - GameEconomy.gold
		print("Not enough gold! Cost: ", cost, " Current: ", GameEconomy.gold, " Missing: ", missing_gold)
		
		if gold_shop_popup:
			gold_shop_popup.open(missing_gold)
		elif upgrade_button:
			_shake_button(upgrade_button)

func _on_equip_pressed() -> void:
	if not _current_data:
		return
		
	# Toggle Selection
	GameEconomy.toggle_hero_selection(_current_data.id)
	
	# Update Visuals based on new state
	var is_now_in_team = GameEconomy.is_hero_selected(_current_data.id)
	_update_equip_button_state(is_now_in_team)

func _on_gold_purchased() -> void:
	if _current_data:
		_populate_ui(_current_data)

func _shake_button(button: Button) -> void:
	var tween = create_tween()
	var original_pos = button.position
	var shake_offset = 10.0
	
	# Simple shake: right, left, right, left, return
	tween.tween_property(button, "position:x", original_pos.x + shake_offset, 0.05)
	tween.tween_property(button, "position:x", original_pos.x - shake_offset, 0.05)
	tween.tween_property(button, "position:x", original_pos.x + shake_offset * 0.5, 0.05)
	tween.tween_property(button, "position:x", original_pos.x - shake_offset * 0.5, 0.05)
	tween.tween_property(button, "position:x", original_pos.x, 0.05)

# --- TEST FUNCTION (User Requested) ---
func _on_test_button_pressed() -> void:
	var dummy_data = CharacterData.new()
	dummy_data.id = "test_999"
	dummy_data.character_name = "Test Hero" 
	dummy_data.description = "Dummy data for testing popup."
	dummy_data.element_text = "Void"
	dummy_data.rarity = CharacterData.Rarity.LEGENDARY
	dummy_data.rarity_color = Color.GOLD
	dummy_data.level = 99
	open(dummy_data)
