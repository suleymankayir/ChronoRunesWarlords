class_name SummonUI extends Control

# --- UI REFERANSLARI ---
@export_group("System Refs")
@export var btn_summon: Button
@export var btn_back: Button
@export var result_card: Control
@export var hero_label: Label      
@export var hero_image: TextureRect 

@export var btn_claim: Button # ResultCard'ın içindeki "Tamam/Al" butonu

@export_group("Data")
@export var possible_rewards: Array[Resource] # Hata olmasın diye Resource yaptık

var player_gold: int = 5000 
var summon_cost: int = 100

func _ready() -> void:
	if result_card: result_card.visible = false
	if btn_summon: btn_summon.pressed.connect(_on_summon_pressed)
	if btn_back: btn_back.pressed.connect(_on_back_pressed)
	
	if btn_claim:
		btn_claim.pressed.connect(_on_claim_pressed)
	
func _on_summon_pressed() -> void:
	if possible_rewards.is_empty():
		push_error("⚠️ HATA: 'Possible Rewards' listesi boş!")
		return

	if player_gold >= summon_cost:
		player_gold -= summon_cost
		_show_result_card()

func _show_result_card() -> void:
	if result_card:
		result_card.move_to_front()
		result_card.visible = true
		result_card.scale = Vector2.ONE
		
		# Resource tipinde olduğu için cast ediyoruz
		var data = possible_rewards.pick_random() as CharacterData
		
		if hero_label:
			hero_label.text = data.name 
			# Renk fonksiyonunu buraya eklemeyi unutma (önceki cevaptan)
			hero_label.add_theme_color_override("font_color", _get_color_by_rarity(data.rarity))
		
		if hero_image:
			hero_image.texture = data.full_body_art

		print("🎲 Çıkan: ", data.name)

func _on_back_pressed() -> void:
	print("🔙 Ana Menüye dönülüyor...")
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainMenu.tscn")

func _on_claim_pressed() -> void:
	# Ufak bir ses efekti çal (Opsiyonel)
	# AudioManager.play_sfx(sfx_click)
	
	# Animasyonlu Kapanış (Reverse Pop)
	var tween = create_tween()
	if result_card:
		# Önce biraz küçült
		tween.tween_property(result_card, "scale", Vector2.ZERO, 0.2)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_IN)
		
		# Animasyon bitince görünmez yap
		tween.tween_callback(func(): result_card.visible = false)
		
	print("✅ Ödül alındı, kart kapandı.")

func _get_color_by_rarity(rarity_enum) -> Color:
	# CharacterData senin class ismin, Rarity ise içindeki Enum
	match rarity_enum:
		CharacterData.Rarity.COMMON:
			return Color.GRAY
		CharacterData.Rarity.RARE:
			return Color.DODGER_BLUE
		CharacterData.Rarity.EPIC:
			return Color.PURPLE
		CharacterData.Rarity.LEGENDARY:
			return Color.GOLD
	
	return Color.WHITE # Tanımsızsa beyaz dön
