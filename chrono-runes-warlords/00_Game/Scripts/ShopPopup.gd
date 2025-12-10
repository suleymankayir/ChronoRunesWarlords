class_name ShopPopup extends Control

# --- UI REFERANSLARI ---
@export var btn_ad: Button      # +500 Gold (Reklam)
@export var btn_buy: Button     # +5000 Gold (Satın Al)
@export var btn_close: Button   # Kapat
@export var panel_root: Control # Animasyon için panel kökü

func _ready() -> void:
	# Anchorları tam ekran yap (Garanti olsun)
	anchors_preset = Control.PRESET_FULL_RECT
	
	if btn_ad: btn_ad.pressed.connect(_on_ad_pressed)
	if btn_buy: btn_buy.pressed.connect(_on_buy_pressed)
	if btn_close: btn_close.pressed.connect(close)

func open() -> void:
	show()
	# Animasyon: Küçükten büyüğe
	if panel_root:
		panel_root.pivot_offset = panel_root.size / 2
		panel_root.scale = Vector2.ZERO
		
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(panel_root, "scale", Vector2.ONE, 0.3)

func close() -> void:
	# Verimlilik: Animasyon ile kapanabilir veya direkt silinebilir
	queue_free()

func _on_ad_pressed() -> void:
	print("📺 Reklam izleniyor...")
	
	# Butonları kilitle (Spam engelleme)
	if btn_ad: btn_ad.disabled = true
	if btn_buy: btn_buy.disabled = true
	
	# 1 Saniye bekle (Reklam Simülasyonu)
	await get_tree().create_timer(1.0).timeout
	
	# Ödülü ver
	GameEconomy.add_gold(500) # REFACTORED
	print("💰 Reklam Ödülü: 500 Gold eklendi. Yeni Bakiye: ", GameEconomy.gold)
	
	close()

func _on_buy_pressed() -> void:
	print("💳 Satın Alım Gerçekleşti!")
	
	# Ödülü ver
	GameEconomy.add_gold(5000) # REFACTORED
	print("💰 Satın Alım: 5000 Gold eklendi. Yeni Bakiye: ", GameEconomy.gold)
	
	close()
