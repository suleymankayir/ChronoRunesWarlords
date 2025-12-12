extends Node

# --- SIGNALS ---
signal gold_updated(new_amount)
signal gems_updated(new_amount)
signal inventory_updated
signal team_updated
signal high_score_updated(new_score)

# --- CONSTANTS ---
const SAVE_PATH: String = "user://savegame.json"
const MAX_TEAM_SIZE: int = 3

# --- VARIABLES ---
var gold: int = 1000
var gems: int = 50
var owned_heroes: Dictionary = {}
var selected_team_ids: Array[String] = []
var high_score: int = 0

# DATABASE
var character_db: Dictionary = {}

func _ready() -> void:
	# 1. Load Database of Characters
	_load_character_database()
	
	# 2. Load User Save Data
	load_game()

func _load_character_database() -> void:
	var path = "res://00_Game/Resources/Characters/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(path + file_name) as CharacterData
				if res:
					character_db[res.id] = res
			file_name = dir.get_next()
		print("GameEconomy: Loaded %d heroes into Database." % character_db.size())
	else:
		push_error("GameEconomy: Failed to open Characters directory!")

func get_character_data(id: String) -> CharacterData:
	if id in character_db:
		return character_db[id]
	push_error("GameEconomy: Character ID not found in DB: " + id)
	return null

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

func add_hero(hero_data: CharacterData) -> int:
	if hero_data.id in owned_heroes:
		print("GameEconomy: Hero ", hero_data.id, " already owned! Converting to Gold.")
		var refund_amount = 100
		add_gold(refund_amount) # Saves automatically
		return refund_amount
	else:
		print("GameEconomy: Adding new hero ", hero_data.id)
		owned_heroes[hero_data.id] = {"level": 1}
		inventory_updated.emit()
		save_game()
		return 0

func get_hero_level(id: String) -> int:
	if id in owned_heroes:
		return owned_heroes[id].get("level", 1)
	return 1

func save_hero_level(id: String, new_level: int) -> void:
	if id in owned_heroes:
		owned_heroes[id]["level"] = new_level
		print("GameEconomy: Hero ", id, " upgraded to level ", new_level)
		inventory_updated.emit()
		save_game()

# --- TEAM MANAGEMENT ---

func toggle_hero_selection(hero_id: String) -> void:
	if hero_id in selected_team_ids:
		selected_team_ids.erase(hero_id)
		print("GameEconomy: Removed ", hero_id, " from team.")
		team_updated.emit()
		save_game()
	elif selected_team_ids.size() < MAX_TEAM_SIZE:
		if hero_id in owned_heroes:
			selected_team_ids.append(hero_id)
			print("GameEconomy: Added ", hero_id, " to team.")
			team_updated.emit()
			save_game()
	else:
		print("GameEconomy: Team is full, cannot add ", hero_id)

func is_hero_selected(hero_id: String) -> bool:
	return hero_id in selected_team_ids

func get_team_leader_id() -> String:
	if not selected_team_ids.is_empty():
		return selected_team_ids[0]
	return ""

# --- GAMEPLAY & SCALING LOGIC ---

func check_new_high_score(current_score: int) -> bool:
	if current_score > high_score:
		print("GameEconomy: NEW HIGH SCORE! ", current_score)
		high_score = current_score
		high_score_updated.emit(high_score)
		save_game()
		return true
	return false

func get_team_total_level() -> int:
	var total_level = 0
	if selected_team_ids.is_empty():
		return 1 # Base level if empty
		
	for id in selected_team_ids:
		total_level += get_hero_level(id)
	
	return total_level

# --- PERSISTENCE (SAVE/LOAD) - BULLETPROOF VERSION ---

func save_game() -> void:
	var save_data = {
		"gold": gold,
		"gems": gems,
		"owned_heroes": owned_heroes,
		"selected_team_ids": selected_team_ids,
		"high_score": high_score
	}
	
	print("GameEconomy: SAVING DATA -> ", JSON.stringify(save_data))
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		file.close() # Ensure close
	else:
		push_error("GameEconomy: FAILED to open save file for writing at " + SAVE_PATH)

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("GameEconomy: No save file found at ", SAVE_PATH, ". Using default values.")
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		print("GameEconomy: LOADING DATA RAW -> ", text)
		
		var json = JSON.new()
		var error = json.parse(text)
		
		if error == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY:
				print("GameEconomy: LOAD SUCCESS. Data: ", data)
				
				# Use .get() with defaults for safety
				gold = int(data.get("gold", 1000))
				gems = int(data.get("gems", 50))
				owned_heroes = data.get("owned_heroes", {})
				
				# Handle Array type safety
				var loaded_team = data.get("selected_team_ids", [])
				selected_team_ids.clear()
				selected_team_ids.assign(loaded_team)
				
				high_score = int(data.get("high_score", 0))
				
				# Emit signals to update listeners
				gold_updated.emit(gold)
				gems_updated.emit(gems)
				inventory_updated.emit()
				team_updated.emit()
				high_score_updated.emit(high_score)
			else:
				push_error("GameEconomy: Save data is not a Dictionary!")
		else:
			push_error("GameEconomy: JSON Parse Error on Load: " + json.get_error_message())
	else:
		push_error("GameEconomy: FAILED to open save file for reading!")
