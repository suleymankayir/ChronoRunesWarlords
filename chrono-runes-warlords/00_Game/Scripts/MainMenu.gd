class_name MainMenu extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var summon_button: Button = $VBoxContainer/SummonButton
@export var btn_collection: Button
@onready var quit_button: Button = $VBoxContainer/QuitButton

# [CHANGED] Navigation Scenes (Drag & Drop in Inspector)
@export var summon_scene: PackedScene
@export var collection_scene: PackedScene

func _ready() -> void:
	# Müzik çalsın
	if Audio.bg_music:
		Audio.play_music(Audio.bg_music)
	
	start_button.pressed.connect(_on_start_pressed)
	summon_button.pressed.connect(_on_summon_button_pressed) # Renamed to match request
	
	if btn_collection:
		btn_collection.pressed.connect(_on_collection_button_pressed) # Renamed to match request
	
	quit_button.pressed.connect(_on_quit_pressed)
	
	# JUICE: Başlık hafifçe süzülsün (Breathing Effect)
	var title = $VBoxContainer/TitleLabel
	if title:
		var tween = create_tween().set_loops()
		tween.tween_property(title, "scale", Vector2(1.05, 1.05), 1.0)
		tween.tween_property(title, "scale", Vector2(1.0, 1.0), 1.0)
	
	if SaveM.game_data.has("high_score"):
		var best = SaveM.game_data["high_score"]
		$VBoxContainer/HighScoreLabel.text = "EN YÜKSEK SKOR: " + str(best)
	
func _on_start_pressed() -> void:
	Audio.play_sfx("swap") 
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainGame.tscn")
	
func _on_summon_button_pressed() -> void:
	Audio.play_sfx("swap")
	if summon_scene:
		get_tree().change_scene_to_packed(summon_scene)
	else:
		push_error("Error: Summon Scene NOT assigned in MainMenu Inspector!")

func _on_collection_button_pressed() -> void:
	Audio.play_sfx("swap")
	if collection_scene:
		get_tree().change_scene_to_packed(collection_scene)
	else:
		push_error("Error: Collection Scene NOT assigned in MainMenu Inspector!")

func _on_quit_pressed() -> void:
	get_tree().quit()
