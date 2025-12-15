class_name MainMenu extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var summon_button: Button = $VBoxContainer/SummonButton
@export var btn_collection: Button
@onready var quit_button: Button = $VBoxContainer/QuitButton

@export var summon_scene: PackedScene
@export var collection_scene: PackedScene

var has_save_file: bool = false

func _ready() -> void:
	if Audio.bg_music:
		Audio.play_music(Audio.bg_music)
	
	start_button.pressed.connect(_on_start_pressed)
	summon_button.pressed.connect(_on_summon_button_pressed)
	if btn_collection:
		btn_collection.pressed.connect(_on_collection_button_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Juice: Title Breathing
	var title = $VBoxContainer/TitleLabel
	if title:
		var tween = create_tween().set_loops()
		tween.tween_property(title, "scale", Vector2(1.05, 1.05), 1.0)
		tween.tween_property(title, "scale", Vector2(1.0, 1.0), 1.0)
	
	# Check Save File
	has_save_file = FileAccess.file_exists(GameEconomy.SAVE_PATH)
	if has_save_file:
		start_button.text = "DEVAM ET"
	else:
		start_button.text = "YENİ OYUN"
		
	if GameEconomy.high_score > 0:
		$VBoxContainer/HighScoreLabel.text = "EN YÜKSEK SKOR: " + str(GameEconomy.high_score)

func _on_start_pressed() -> void:
	Audio.play_sfx("swap")
	
	if not has_save_file:
		GameEconomy.start_new_game()
	
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainGame.tscn")

func _on_summon_button_pressed() -> void:
	Audio.play_sfx("swap")
	if summon_scene:
		get_tree().change_scene_to_packed(summon_scene)
	else:
		push_error("MainMenu: Summon Scene NOT assigned!")

func _on_collection_button_pressed() -> void:
	Audio.play_sfx("swap")
	if collection_scene:
		get_tree().change_scene_to_packed(collection_scene)
	else:
		push_error("MainMenu: Collection Scene NOT assigned!")

func _on_quit_pressed() -> void:
	get_tree().quit()
