extends Control

@onready var grid_container: GridContainer = $GridContainer

func _ready() -> void:
	# Ensure grid container is available
	if not grid_container:
		print("Error: GridContainer not found in MapScene")
		return
		
	# Clear existing children if any
	for child in grid_container.get_children():
		child.queue_free()
		
	# Basic layout settings for grid if not set in editor
	if grid_container.columns == 0:
		grid_container.columns = 5
	
	# Create Buttons
	var total_levels = 20
	if GameEconomy.max_unlocked_level > 20:
		total_levels = GameEconomy.max_unlocked_level + 5
		
	for i in range(1, total_levels + 1):
		var btn = Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(80, 80)
		grid_container.add_child(btn)
		
		if i <= GameEconomy.max_unlocked_level:
			btn.disabled = false
			btn.modulate = Color(1, 1, 1, 1) # Normal
			# Connect signal using a callable to pass the level argument
			btn.pressed.connect(_on_level_button_pressed.bind(i))
		else:
			btn.disabled = true
			btn.modulate = Color(0.3, 0.3, 0.3, 0.8) # Locked (Dark Grey)

func _on_level_button_pressed(level: int) -> void:
	GameEconomy.start_level_from_map(level)
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainGame.tscn")
