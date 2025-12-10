class_name SummonUI extends Control

# --- UI REFERANSLARI ---
@export_group("System Refs")
@export var btn_summon: Button
@export var btn_back: Button
@export var btn_claim: Button      # Kapat/Al butonu
@export var result_card: Control
@export var hero_label: Label      
@export var hero_image: TextureRect 
@export var shop_popup_scene: PackedScene # [NEW] Mağaza Sahnesi

# --- SES ---
@export_group("Audio")
@export var sfx_summon_success: AudioStream

# --- VERİ HAVUZU ---
@export_group("Data")
@export var possible_rewards: Array[Resource]

# --- AYARLAR ---
var summon_cost: int = 100

func _ready() -> void:
	# Başlangıç ayarları
	if result_card: result_card.visible = false
	
	# Butonları bağla
	if btn_summon: btn_summon.pressed.connect(_on_summon_pressed)
	if btn_back: btn_back.pressed.connect(_on_back_pressed)
	if btn_claim: btn_claim.pressed.connect(_on_claim_pressed)

func _on_summon_pressed() -> void:
	# 1. Havuz Kontrolü
	if possible_rewards.is_empty():
		push_error("⚠️ HATA: Inspector'da 'Possible Rewards' listesi boş!")
		return

	# 2. EKONOMİ KONTROLÜ
	if GameEconomy.spend_gold(summon_cost):
		
		# Ses Çal (Audio Manager ismin 'Audio' ise öyle kalsın)
		if sfx_summon_success:
			Audio.play_sfx(sfx_summon_success)
			
		_show_result_card()
		
	else:
		# PARA YETMEDİ
		print("❌ Yetersiz Bakiye! Cüzdan: ", GameEconomy.gold)
		
		# [CHANGED] Use GoldShopPopup if assigned
		if shop_popup_scene:
			print("🛒 Mağaza açılıyor...")
			var shop = shop_popup_scene.instantiate()
			add_child(shop)
			if shop.has_method("open"):
				# Calculate missing gold
				var missing = summon_cost - GameEconomy.gold
				shop.open(missing)
		else:
			print("UYARI: Shop Popup Scene atanmamış!")

func _show_result_card() -> void:
	if result_card:
		result_card.move_to_front()
		result_card.visible = true
		result_card.scale = Vector2.ONE
		
		# 1. Karakter Seç
		var data = possible_rewards.pick_random() as CharacterData
		
		# 2. GLOBAL ENVANTERE EKLE (Kritik Nokta)
		GameEconomy.add_hero(data)
		
		# 3. UI Güncelle
		if hero_label:
			hero_label.text = data.character_name 
			hero_label.add_theme_color_override("font_color", _get_color_by_rarity(data.rarity))
		
		if hero_image:
			hero_image.texture = data.portrait

		print("🎲 Kazanılan: ", data.character_name)

func _on_claim_pressed() -> void:
	# Kartı kapat
	if result_card:
		var tween = create_tween()
		tween.tween_property(result_card, "scale", Vector2.ZERO, 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): result_card.visible = false)

func _on_back_pressed() -> void:
	print("🔙 Ana Menüye dönülüyor...")
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainMenu.tscn")

# Rengi belirleyen yardımcı fonksiyon
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
