extends Control
class_name BattleHero

signal skill_activated(hero_data: CharacterData)

# Nodes expected in the scene
@onready var icon: TextureRect = $Icon
@onready var mana_bar: ProgressBar = $ManaBar
@onready var click_button: TextureButton = $ClickButton
@onready var ready_label: Label = $ReadyLabel
@onready var leader_label: Label = $LeaderLabel
# Adding ManaLabel support as requested (Optional if user hasn't added it yet, but Logic requires it)
@onready var mana_label: Label = get_node_or_null("ManaLabel") 

var hero_data: CharacterData
var current_mana: int = 0
var max_mana: int = 100

func _ready() -> void:
	# FIX 1: Fix Input Blocking
	# Force Mouse Filter to IGNORE so clicks pass through to the button
	if ready_label: 
		ready_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ready_label.visible = false
	if leader_label: 
		leader_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		leader_label.visible = false
	if mana_label:
		mana_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	# Also ensure ManaBar doesn't block if it's on top
	if mana_bar:
		mana_bar.mouse_filter = Control.MOUSE_FILTER_PASS
		
	if click_button: 
		click_button.pressed.connect(_on_click_button_pressed)

func setup(data: CharacterData, is_leader: bool, initial_mana: int = -1) -> void:
	hero_data = data
	# Only reset to 0 if no saved mana provided (initial_mana == -1)
	if initial_mana == -1:
		current_mana = 0
	else:
		# Clamp to non-negative to prevent corrupted save data issues
		current_mana = max(0, initial_mana)
	
	if hero_data and icon:
		icon.texture = hero_data.portrait
		
	# Reset Max Mana (Default 100)
	max_mana = 100
	
	# Leader Label Logic
	if leader_label:
		leader_label.visible = is_leader
		
	update_ui()

func add_mana(amount: int) -> void:
	current_mana += amount
	current_mana = min(current_mana, max_mana)
	
	# FIX 2: Visual Glitch & Overlap Logic
	update_ui()
	
	if current_mana >= max_mana:
		_play_ready_animation()

func update_ui() -> void:
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = current_mana
		
	# LOGIC: Toggle Labels based on Full Mana
	if current_mana >= max_mana:
		# MANA IS FULL
		if ready_label: ready_label.visible = true
		if mana_label: mana_label.visible = false
		
		# If using ProgressBar built-in text
		if mana_bar: mana_bar.show_percentage = false
		
		modulate = Color(1.2, 1.2, 1.2) # Slight glow
	else:
		# MANA IS NOT FULL
		if ready_label: ready_label.visible = false
		if mana_label: mana_label.visible = true
		
		# If using ProgressBar built-in text
		if mana_bar: mana_bar.show_percentage = true
		
		modulate = Color.WHITE

func _on_click_button_pressed() -> void:
	if current_mana >= max_mana:
		current_mana = 0
		update_ui()
		emit_signal("skill_activated", hero_data)
	else:
		# Feedback: Not Ready
		var tween = create_tween()
		tween.tween_property(self, "position:x", position.x + 5, 0.05)
		tween.tween_property(self, "position:x", position.x - 5, 0.05)
		tween.tween_property(self, "position:x", position.x, 0.05)

func _play_ready_animation() -> void:
	# Small pulse animation when fully charged
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
