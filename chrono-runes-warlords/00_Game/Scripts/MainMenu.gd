class_name MainMenu extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var summon_button: Button = $VBoxContainer/SummonButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	# Müzik çalsın (Eğer AudioManager'da otomatik başlamıyorsa)
	if Audio.bg_music:
		Audio.play_music(Audio.bg_music)
	
	start_button.pressed.connect(_on_start_pressed)
	summon_button.pressed.connect(_on_summon_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# JUICE: Başlık hafifçe süzülsün (Breathing Effect)
	var title = $VBoxContainer/TitleLabel # Eğer başlığa isim verdiysen
	if title:
		var tween = create_tween().set_loops()
		tween.tween_property(title, "scale", Vector2(1.05, 1.05), 1.0)
		tween.tween_property(title, "scale", Vector2(1.0, 1.0), 1.0)
	
	var best = SaveM.game_data["high_score"]
	$VBoxContainer/HighScoreLabel.text = "EN YÜKSEK SKOR: " + str(best)
	
	
func _on_start_pressed() -> void:
	
	Audio.play_sfx("swap") 
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainGame.tscn")
	
func _on_summon_pressed() -> void:
	Audio.play_sfx("swap")
	get_tree().change_scene_to_file("res://00_Game/Scenes/SummonUI.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
