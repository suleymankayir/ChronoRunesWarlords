extends Node

signal gold_updated(new_amount)
signal gems_updated(new_amount)
signal inventory_updated
signal team_updated # NEW

const SAVE_PATH: String = "user://savegame.json"
const MAX_TEAM_SIZE: int = 3 # NEW

var gold: int = 1000
var gems: int = 50
var owned_heroes: Dictionary = {}
var selected_team_ids: Array[String] = [] # NEW

func _ready() -> void:
	load_game()
	
# --- CURRENCY FUNCTIONS ---

func has_enough_gold(amount: int) -> bool:
	return gold >= amount

func spend_gold(amount: int) -> bool:
	if has_enough_gold(amount):
		gold -= amount
		gold_updated.emit(gold)
		save_game()
		return true
	return false

func add_gold(amount: int) -> void:
	gold += amount
	gold_updated.emit(gold)
	save_game()

func has_enough_gems(amount: int) -> bool:
	return gems >= amount

func spend_gems(amount: int) -> bool:
	if has_enough_gems(amount):
		gems -= amount
		gems_updated.emit(gems)
		save_game()
		return true
	return false

func add_gems(amount: int) -> void:
	gems += amount
	gems_updated.emit(gems)
	save_game()

# --- HERO INVENTORY FUNCTIONS ---

func add_hero(hero_data: CharacterData) -> void:
	if hero_data.id in owned_heroes:
		print("Hero already owned! Converted to Gold.")
		add_gold(100) # Auto-saves in add_gold
	else:
		owned_heroes[hero_data.id] = {"level": 1}
		inventory_updated.emit()
		save_game()

func get_hero_level(id: String) -> int:
	if id in owned_heroes:
		return owned_heroes[id].get("level", 1)
	return 1

func save_hero_level(id: String, new_level: int) -> void:
	if id in owned_heroes:
		owned_heroes[id]["level"] = new_level
		save_game()

# --- TEAM MANAGEMENT (NEW) ---

func toggle_hero_selection(hero_id: String) -> void:
	if hero_id in selected_team_ids:
		selected_team_ids.erase(hero_id)
		team_updated.emit()
		save_game()
	elif selected_team_ids.size() < MAX_TEAM_SIZE:
		if hero_id in owned_heroes:
			selected_team_ids.append(hero_id)
			team_updated.emit()
			save_game()
	else:
		print("Team is full!")

func is_hero_selected(hero_id: String) -> bool:
	return hero_id in selected_team_ids

# --- PERSISTENCE (SAVE/LOAD) ---

func save_game() -> void:
	var save_data = {
		"gold": gold,
		"gems": gems,
		"owned_heroes": owned_heroes,
		"selected_team_ids": selected_team_ids # NEW
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return # No save file, stick to defaults
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(text)
		
		if error == OK:
			var data = json.data
			if "gold" in data:
				gold = int(data["gold"])
			if "gems" in data:
				gems = int(data["gems"])
			if "owned_heroes" in data:
				owned_heroes = data["owned_heroes"]
			if "selected_team_ids" in data: # NEW
				selected_team_ids.assign(data["selected_team_ids"])
				
			# Emit signals to update UI with loaded values
			gold_updated.emit(gold)
			gems_updated.emit(gems)
			inventory_updated.emit()
			team_updated.emit() # NEW
		else:
			print("JSON Parse Error: ", json.get_error_message())
