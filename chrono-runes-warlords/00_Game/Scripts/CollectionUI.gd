class_name CollectionUI extends Control

# --- CONFIGURATION ---
@export var hero_slot_scene: PackedScene 
@export var character_popup: CharacterDetailPopup # Using the existing popup reference style
@export var grid_container: GridContainer
@export var btn_back: Button
@export var all_possible_heroes: Array[CharacterData] = []

func _ready() -> void:
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	
	# Connect to economy updates
	GameEconomy.inventory_updated.connect(refresh_grid)
	GameEconomy.team_updated.connect(_on_team_updated) # NEW
	
	# Initial Render
	refresh_grid()

func refresh_grid() -> void:
	print(">>> KOLEKSİYON YENİLENİYOR...")
	
	if not grid_container:
		print("ERROR: Grid Container is missing!")
		return

	# Print 2
	print(">>> BANKADAKİ KAHRAMAN SAYISI: ", GameEconomy.owned_heroes.size())
	print(">>> SAHİP OLUNAN ID'LER: ", GameEconomy.owned_heroes.keys())
	
	# Print 3
	print(">>> VİTRİNDEKİ TOPLAM SLOT ADAYI: ", all_possible_heroes.size())
	
	# 1. Clear existing slots
	for child in grid_container.get_children():
		child.queue_free()
	
	# 2. Iterate through all possible heroes
	for hero_data in all_possible_heroes:
		if not hero_data:
			continue
			
		# Print 4 - Loop Logic
		print("--- Kontrol ediliyor: ", hero_data.id, " | Sahip miyiz?: ", GameEconomy.owned_heroes.has(hero_data.id))
		
		# Check if owned
		if hero_data.id in GameEconomy.owned_heroes:
			_create_slot(hero_data)
		else:
			# Optional: Handle locked state logic here if needed in future
			pass

func _create_slot(data: CharacterData) -> void:
	if not hero_slot_scene:
		push_error("Error: Hero Slot Scene not assigned in CollectionUI")
		return

	var new_slot = hero_slot_scene.instantiate()
	
	# Update data with current level
	data.level = GameEconomy.get_hero_level(data.id)
	
	# Assign data directly (as per HeroSlot.gd definition)
	if "slot_data" in new_slot:
		new_slot.slot_data = data
	else:
		push_error("Error: HeroSlot scene missing 'slot_data' property!")
		
	# Connect signal
	if new_slot.has_signal("hero_selected"):
		new_slot.hero_selected.connect(_on_hero_slot_hero_selected)
	else:
		push_error("Error: HeroSlot scene missing 'hero_selected' signal!")
	
	# Set initial team status (NEW)
	if new_slot.has_method("set_team_status"):
		var is_selected = GameEconomy.is_hero_selected(data.id)
		new_slot.set_team_status(is_selected)

	# Set initial leader status
	if new_slot.has_method("set_leader_status"):
		var leader_id = GameEconomy.get_team_leader_id()
		var is_leader = (data.id == leader_id)
		new_slot.set_leader_status(is_leader)
	
	grid_container.add_child(new_slot)

func _on_team_updated() -> void:
	print(">>> Team Updated! Refreshing indicators...")
	
	var leader_id = GameEconomy.get_team_leader_id()
	
	for child in grid_container.get_children():
		if "slot_data" in child and child.slot_data:
			var id = child.slot_data.id
			var is_selected = GameEconomy.is_hero_selected(id)
			var is_leader = (id == leader_id)
			
			if child.has_method("set_team_status"):
				child.set_team_status(is_selected)
				
			if child.has_method("set_leader_status"):
				child.set_leader_status(is_leader)

func _on_hero_slot_hero_selected(data: CharacterData) -> void:
	print(">>> Selected Hero: ", data.character_name)
	
	# Ensure data is fresh
	data.level = GameEconomy.get_hero_level(data.id)
	
	if character_popup:
		character_popup.open(data)
	else:
		push_error("Error: Character Detail Popup not assigned!")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainMenu.tscn")
