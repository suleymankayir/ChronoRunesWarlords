extends Node

# --- SIGNALS ---
signal gold_updated(new_amount)
signal gems_updated(new_amount)
signal inventory_updated
signal team_updated
signal high_score_updated(new_score)

# --- CONSTANTS ---
const SAVE_PATH: String = "user://save_game.json"
const MAX_TEAM_SIZE: int = 3

# --- VARIABLES ---
var gold: int = 0
var gems: int = 0
var owned_heroes: Array = []
var selected_team_ids: Array = []
var high_score: int = 0
var character_db: Dictionary = {}

func _ready() -> void:
	_load_character_database()
	if FileAccess.file_exists(SAVE_PATH):
		load_game()

func start_new_game() -> void:
	print(">>> YENİ OYUN BAŞLATILIYOR (RAM + DISK)...")
	
	# 1. Force Set RAM Variables First
	gold = 200
	gems = 50
	owned_heroes = ["hero_fire", "hero_water", "hero_earth"]
	selected_team_ids = ["hero_fire", "hero_water", "hero_earth"]
	
	# 2. Emit Signals
	gold_updated.emit(gold)
	gems_updated.emit(gems)
	inventory_updated.emit()
	team_updated.emit()
	
	# 3. Save
	save_game()

func save_game() -> void:
	var save_data = {
		"gold": gold,
		"gems": gems,
		"owned_heroes": owned_heroes,
		"selected_team_ids": selected_team_ids,
		"high_score": high_score
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY:
				gold = int(data.get("gold", 0))
				gems = int(data.get("gems", 0))
				high_score = int(data.get("high_score", 0))
				
				var loaded_heroes = data.get("owned_heroes", [])
				if typeof(loaded_heroes) == TYPE_ARRAY:
					owned_heroes = loaded_heroes
				elif typeof(loaded_heroes) == TYPE_DICTIONARY: # Legacy support
					owned_heroes = loaded_heroes.keys()
				
				var loaded_team = data.get("selected_team_ids", [])
				selected_team_ids.clear()
				for id in loaded_team:
					selected_team_ids.append(str(id))

				# Emit Signals
				gold_updated.emit(gold)
				gems_updated.emit(gems)
				inventory_updated.emit()
				team_updated.emit()
				high_score_updated.emit(high_score)
				file.close()
				return true
		file.close()
	return false

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

func get_character_data(id: String) -> CharacterData:
	return character_db.get(id)

# --- HELPER FUNCTIONS ---

func add_gold(amount: int) -> void:
	gold += amount
	gold_updated.emit(gold)
	save_game()

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_updated.emit(gold)
		save_game()
		return true
	return false

func add_gems(amount: int) -> void:
	gems += amount
	gems_updated.emit(gems)
	save_game()

func spend_gems(amount: int) -> bool:
	if gems >= amount:
		gems -= amount
		gems_updated.emit(gems)
		save_game()
		return true
	return false

func add_hero(hero_data: CharacterData) -> int:
	if hero_data.id in owned_heroes:
		add_gold(100) # Duplicate reward
		return 100
	
	owned_heroes.append(hero_data.id)
	inventory_updated.emit()
	save_game()
	return 0

func unlock_character(hero_data: CharacterData) -> void:
	add_hero(hero_data)

func get_team_total_level() -> int:
	var total = 0
	if selected_team_ids.is_empty():
		return 1
	for id in selected_team_ids:
		total += get_hero_level(id)
	return total

func get_team_leader_id() -> String:
	if not selected_team_ids.is_empty():
		return selected_team_ids[0]
	return ""

func save_hero_level(id: String, level: int) -> void:
	pass # Array doesn't store levels

func get_hero_level(id: String) -> int:
	return 1 # Default level 1 for Array system

func check_new_high_score(score: int) -> void:
	if score > high_score:
		high_score = score
		high_score_updated.emit(high_score)
		save_game()

func toggle_hero_selection(hero_id: String) -> void:
	if hero_id in selected_team_ids:
		selected_team_ids.erase(hero_id)
		team_updated.emit()
		save_game()
	elif selected_team_ids.size() < MAX_TEAM_SIZE and hero_id in owned_heroes:
		selected_team_ids.append(hero_id)
		team_updated.emit()
		save_game()

func is_hero_selected(hero_id: String) -> bool:
	return hero_id in selected_team_ids
