class_name GameOverUI extends Control

signal restart_requested # Tell MainGame to 'Restart'
signal menu_requested
@onready var score_label: Label = $TextureRect/ScoreLabel
@onready var title_label: Label = $TextureRect/TitleLabel # CHECK PATH!
@onready var restart_button: Button = $TextureRect/RestartButton # CHECK PATH!
@onready var background_image: TextureRect = $TextureRect
@onready var menu_button: Button = $TextureRect/MenuButton # Check path!


func _ready() -> void:
	# Initially invisible
	visible = false
	# Emit signal when button pressed
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
func show_result(is_victory: bool, final_score:int) -> void:
	visible = true
	get_tree().paused = true
	
	# REFACTORED: Use GameEconomy
	GameEconomy.check_new_high_score(final_score)
	var best_score = GameEconomy.high_score
	
	score_label.text = "SKOR: %d\nEN İYİ: %d" % [final_score, best_score]
	
	if final_score >= best_score and final_score > 0:
		score_label.modulate = Color.YELLOW # Turn gold if record broken!
		score_label.text += "\nNEW RECORD!"
	
	# 1. Setup Text and Colors
	if is_victory:
		title_label.text = "VICTORY!"
		title_label.modulate = Color("#5cd65c") # RPG Green
		# MONETIZATION OP: '2x Reward' button can be placed here.
	else:
		title_label.text = "DEFEAT..."
		title_label.modulate = Color("#ff4d4d") # Blood Red
		# MONETIZATION OP: 'Revive' button can be placed here.
	
	# 2. Start Animation (Action)
	# Single Tween block is enough.
	
	# Initial state: Tiny (Invisible)
	background_image.scale = Vector2.ZERO
	# Set pivot to center to scale from center
	background_image.pivot_offset = background_image.size / 2
	
	# Scale up with 'Pop' effect
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(background_image, "scale", Vector2(1.0, 1.0), 0.4)

func _on_restart_pressed() -> void:
	# Resume game flow
	get_tree().paused = false
	restart_requested.emit()
	queue_free() # Destroy self (MainGame creates new one or scene resets)
	
func _on_menu_pressed() -> void:
	get_tree().paused = false # Don't forget to unpause game!
	# Change scene directly:
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainMenu.tscn")
