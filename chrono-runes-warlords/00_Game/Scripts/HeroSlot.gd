class_name HeroSlot extends TextureButton

signal hero_selected(data: CharacterData)

@export var rarity_border: ReferenceRect
@export var level_label: Label
@export var team_indicator: Control
@export var leader_indicator: Control

var slot_data: CharacterData : set = _set_slot_data

func _ready() -> void:
	pressed.connect(_on_pressed)
	
	# Default size to prevent invisibility if no data yet
	custom_minimum_size = Vector2(150, 200)

func _set_slot_data(value: CharacterData) -> void:
	slot_data = value
	
	if slot_data:
		# Update Visuals Immediately
		texture_normal = slot_data.portrait
		ignore_texture_size = true
		stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		custom_minimum_size = Vector2(150, 200)
		
		# Update Rarity Border with Color
		if rarity_border:
			rarity_border.border_color = slot_data.rarity_color
			
		# Update Level Text
		if level_label:
			level_label.text = "Lv. %d" % slot_data.level
		
		# Optional: Add tooltip or other metadata if needed
		tooltip_text = slot_data.character_name

func set_team_status(is_in_team: bool) -> void:
	if team_indicator:
		team_indicator.visible = is_in_team

func set_leader_status(is_leader: bool) -> void:
	if leader_indicator:
		leader_indicator.visible = is_leader

func _on_pressed() -> void:
	if slot_data:
		hero_selected.emit(slot_data)
