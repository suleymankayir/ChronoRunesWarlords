class_name ShopPopup extends Control

# --- UI REFERENCES ---
@export var btn_ad: Button      # +500 Gold (Ad)
@export var btn_buy: Button     # +5000 Gold (Buy)
@export var btn_close: Button   # Close
@export var panel_root: Control # Panel root for animation

func _ready() -> void:
	# Set anchors to full screen (Safety)
	anchors_preset = Control.PRESET_FULL_RECT
	
	if btn_ad: btn_ad.pressed.connect(_on_ad_pressed)
	if btn_buy: btn_buy.pressed.connect(_on_buy_pressed)
	if btn_close: btn_close.pressed.connect(close)

func open() -> void:
	show()
	# Animation: Small to big
	if panel_root:
		panel_root.pivot_offset = panel_root.size / 2
		panel_root.scale = Vector2.ZERO
		
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(panel_root, "scale", Vector2.ONE, 0.3)

func close() -> void:
	# Efficiency: Can close with animation or delete directly
	queue_free()

func _on_ad_pressed() -> void:
	print("📺 Watching Ad...")
	
	# Lock buttons (Prevent spam)
	if btn_ad: btn_ad.disabled = true
	if btn_buy: btn_buy.disabled = true
	
	# Wait 1 Second (Ad Simulation)
	await get_tree().create_timer(1.0).timeout
	
	# Give reward
	GameEconomy.add_gold(500) # REFACTORED
	print("💰 Ad Reward: 500 Gold added. New Balance: ", GameEconomy.gold)
	
	close()

func _on_buy_pressed() -> void:
	print("💳 Purchase Successful!")
	
	# Give reward
	GameEconomy.add_gold(5000) # REFACTORED
	print("💰 Purchase: 5000 Gold added. New Balance: ", GameEconomy.gold)
	
	close()
