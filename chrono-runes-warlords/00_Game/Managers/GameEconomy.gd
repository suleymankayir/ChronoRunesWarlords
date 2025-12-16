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
var hero_levels: Dictionary = {} 
var high_score: int = 0
var battle_state: Dictionary = {} # STORE BATTLE STATE HERE
var character_db: Dictionary = {}

# --- NEW VARIABLES ---
var max_unlocked_level: int = 1
var current_map_level: int = 1

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
	hero_levels = {} 
	battle_state = {}
	max_unlocked_level = 1
	current_map_level = 1
	
	# Initialize levels for owned heroes
	for h in owned_heroes:
		hero_levels[h] = 1
	
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
		"hero_levels": hero_levels,
		"high_score": high_score,
		"battle_state": battle_state,
		"max_unlocked_level": max_unlocked_level
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
				max_unlocked_level = int(data.get("max_unlocked_level", 1))
				
				var loaded_heroes = data.get("owned_heroes", [])
				if typeof(loaded_heroes) == TYPE_ARRAY:
					owned_heroes = loaded_heroes
				
				var loaded_team = data.get("selected_team_ids", [])
				selected_team_ids.clear()
				for id in loaded_team:
					selected_team_ids.append(str(id))
					
				var loaded_levels = data.get("hero_levels", {})
				if typeof(loaded_levels) == TYPE_DICTIONARY:
					hero_levels = loaded_levels
					
				var loaded_battle = data.get("battle_state", {})
				if typeof(loaded_battle) == TYPE_DICTIONARY:
					battle_state = loaded_battle

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

func complete_current_level() -> void:
	# Progression Logic
	if current_map_level == max_unlocked_level:
		max_unlocked_level += 1
		save_game()
	
	current_map_level += 1

func start_level_from_map(level_id: int) -> void:
	current_map_level = level_id
	clear_battle_state()
	save_game()


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

# --- BATTLE PERSISTENCE ---

func save_battle_state(data: Dictionary) -> void:
	battle_state = data
	save_game()

func clear_battle_state() -> void:
	battle_state = {}
	save_game()
	
func has_saved_battle() -> bool:
	return not battle_state.is_empty()

# --- HELPER FUNCTIONS ---

func has_enough_gold(amount: int) -> bool:
	return gold >= amount

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_updated.emit(gold)
		save_game()
		return true
	return false

func add_gold(amount: int) -> void:
	gold += amount
	gold_updated.emit(gold)
	save_game()

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

# --- HERO MANAGEMENT ---

func add_hero(hero_data: CharacterData) -> int:
	if hero_data.id in owned_heroes:
		add_gold(100) # Duplicate reward
		return 100
	
	owned_heroes.append(hero_data.id)
	hero_levels[hero_data.id] = 1 # Init level 1
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

# --- LEVEL SYSTEM ---

func save_hero_level(id: String, level: int) -> void:
	hero_levels[id] = level
	inventory_updated.emit()
	save_game()

func get_hero_level(id: String) -> int:
	return hero_levels.get(id, 1) # Default to 1 if not found

# --- SCORE & TEAM ---

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
