class_name MainMenu extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var summon_button: Button = $VBoxContainer/SummonButton
@export var btn_collection: Button
@onready var quit_button: Button = $VBoxContainer/QuitButton

# [NEW] Popup Reference
@export var character_popup: CharacterDetailPopup

func _ready() -> void:
	# Müzik çalsın
	if Audio.bg_music:
		Audio.play_music(Audio.bg_music)
	
	start_button.pressed.connect(_on_start_pressed)
	summon_button.pressed.connect(_on_summon_pressed)
	
	if btn_collection:
		btn_collection.pressed.connect(_on_collection_pressed)
	
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
	
func _on_summon_pressed() -> void:
	Audio.play_sfx("swap")
	get_tree().change_scene_to_file("res://00_Game/Scenes/SummonUI.tscn")

func _on_collection_pressed() -> void:
	Audio.play_sfx("swap")
	get_tree().change_scene_to_file("res://00_Game/Scenes/CollectionUI.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

# [NEW] Test Button Bridge Function
# Connect your TEST BUTTON in the MainMenu scene to THIS function.
func _on_main_menu_test_button_pressed() -> void:
	print(">>> Main Menu: Test Button Pressed Signal Received <<<")
	
	if character_popup:
		print(">>> Main Menu: Delagating to CharacterPopup._on_test_button_pressed() <<<")
		character_popup._on_test_button_pressed()
	else:
		push_error(">>> ERROR: 'character_popup' is NOT assigned in MainMenu Inspector! <<<")
