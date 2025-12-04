class_name ShopUI extends Control

@onready var gold_label: Label = $GoldLabel
@onready var dmg_level_label: Label = $HBoxContainer/VBoxDmg/LevelText # Yolları kontrol et!
@onready var hp_level_label: Label = $HBoxContainer/VBoxHP/LevelText
@onready var buy_dmg_btn: Button = $HBoxContainer/VBoxDmg/BuyButton_Dmg
@onready var buy_hp_btn: Button = $HBoxContainer/VBoxHP/BuyButton_HP
@onready var back_button: Button = $BackButton

func _ready() -> void:
	update_ui()
	
	buy_dmg_btn.pressed.connect(_on_buy_dmg_pressed)
	buy_hp_btn.pressed.connect(_on_buy_hp_pressed)
	back_button.pressed.connect(_on_back_pressed)

func update_ui() -> void:
	# Güncel parayı göster
	gold_label.text = "ALTIN: " + str(SaveM.game_data["total_gold"])
	
	# Hasar Bilgileri
	var dmg_lvl = SaveM.game_data["damage_level"]
	var dmg_cost = SaveM.get_upgrade_cost(dmg_lvl)
	dmg_level_label.text = "Lvl " + str(dmg_lvl)
	buy_dmg_btn.text = "GÜÇLEN (" + str(dmg_cost) + " G)"
	
	# Can Bilgileri
	var hp_lvl = SaveM.game_data["hp_level"]
	var hp_cost = SaveM.get_upgrade_cost(hp_lvl)
	hp_level_label.text = "Lvl " + str(hp_lvl)
	buy_hp_btn.text = "GÜÇLEN (" + str(hp_cost) + " G)"
	
	# Paran yetmiyorsa butonları gri yap (Disabled)
	var current_gold = SaveM.game_data["total_gold"]
	buy_dmg_btn.disabled = (current_gold < dmg_cost)
	buy_hp_btn.disabled = (current_gold < hp_cost)

func _on_buy_dmg_pressed() -> void:
	var lvl = SaveM.game_data["damage_level"]
	var cost = SaveM.get_upgrade_cost(lvl)
	
	if SaveM.game_data["total_gold"] >= cost:
		SaveM.game_data["total_gold"] -= cost
		SaveM.game_data["damage_level"] += 1
		SaveM.save_data()
		
		Audio.play_sfx("swap", 1.5) # Para sesi niyetine ince swap sesi
		update_ui()

func _on_buy_hp_pressed() -> void:
	var lvl = SaveM.game_data["hp_level"]
	var cost = SaveM.get_upgrade_cost(lvl)
	
	if SaveM.game_data["total_gold"] >= cost:
		SaveM.game_data["total_gold"] -= cost
		SaveM.game_data["hp_level"] += 1
		SaveM.save_data()
		
		Audio.play_sfx("swap", 1.5)
		update_ui()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainMenu.tscn")
