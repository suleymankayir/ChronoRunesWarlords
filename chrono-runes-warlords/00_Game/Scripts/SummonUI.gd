class_name SummonUI extends Control

# --- UI REFERENCES ---
@export_group("System Refs")
@export var btn_summon: Button
@export var btn_back: Button
@export var btn_claim: Button      # Close/Claim button
@export var result_card: Control
@export var hero_label: Label      
@export var hero_image: TextureRect 
@export var shop_popup_scene: PackedScene # [NEW] Shop Scene

# --- AUDIO ---
@export_group("Audio")
@export var sfx_summon_success: AudioStream

# --- DATA POOL ---
@export_group("Data")
@export var possible_rewards: Array[Resource]

# --- SETTINGS ---
var summon_cost: int = 100

func _ready() -> void:
	# Initial settings
	if result_card: result_card.visible = false
	
	# Connect buttons
	if btn_summon: btn_summon.pressed.connect(_on_summon_pressed)
	if btn_back: btn_back.pressed.connect(_on_back_pressed)
	if btn_claim: btn_claim.pressed.connect(_on_claim_pressed)

func _on_summon_pressed() -> void:
	# 1. Pool Check
	if possible_rewards.is_empty():
		push_error("⚠️ ERROR: 'Possible Rewards' list is empty in Inspector!")
		return

	# 2. ECONOMY CHECK
	if GameEconomy.spend_gold(summon_cost):
		
		# Play Sound (Keep as 'Audio' if Audio Manager name is correct)
		if sfx_summon_success:
			Audio.play_sfx(sfx_summon_success)
			
		# [UX FIX] Wait for UI update dip
		btn_summon.disabled = true # Prevent double click
		await get_tree().create_timer(0.5).timeout
		btn_summon.disabled = false
		
		_show_result_card()
		
	else:
		# INSUFFICIENT FUNDS
		print("❌ Insufficient Balance! Wallet: ", GameEconomy.gold)
		
		# [CHANGED] Use GoldShopPopup if assigned
		if shop_popup_scene:
			print("🛒 Opening Shop...")
			var shop = shop_popup_scene.instantiate()
			add_child(shop)
			if shop.has_method("open"):
				# Calculate missing gold
				var missing = summon_cost - GameEconomy.gold
				shop.open(missing)
		else:
			print("WARNING: Shop Popup Scene not assigned!")

func _show_result_card() -> void:
	if result_card:
		result_card.move_to_front()
		result_card.visible = true
		result_card.scale = Vector2.ONE
		
		# 1. Pick Character
		var data = possible_rewards.pick_random() as CharacterData
		
		# 2. ADD TO GLOBAL INVENTORY (Critical Point)
		var refund = GameEconomy.add_hero(data)
		
		# 3. Update UI
		if hero_label:
			if refund > 0:
				hero_label.text = "CONVERTED: +%d GOLD" % refund
				hero_label.add_theme_color_override("font_color", Color.YELLOW)
			else:
				hero_label.text = data.character_name 
				hero_label.add_theme_color_override("font_color", _get_color_by_rarity(data.rarity))
		
		if hero_image:
			hero_image.texture = data.portrait

		print("🎲 Won: ", data.character_name)

func _on_claim_pressed() -> void:
	# Close card
	if result_card:
		var tween = create_tween()
		tween.tween_property(result_card, "scale", Vector2.ZERO, 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): result_card.visible = false)

func _on_back_pressed() -> void:
	print("🔙 Returning to Main Menu...")
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainMenu.tscn")

# Helper function for color
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
