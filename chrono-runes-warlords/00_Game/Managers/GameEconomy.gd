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
var active_battle_snapshot: Dictionary = {} # STORE BATTLE STATE HERE
var character_db: Dictionary = {}

# --- NEW VARIABLES ---
var max_unlocked_level: int = 1
var current_map_level: int = 1

func _ready() -> void:
	_load_character_database()
	if FileAccess.file_exists(SAVE_PATH):
		load_game()
		
	# FORCE ADD FOR TESTING (Fix for old saves)
	if not "hero_nature_druid" in owned_heroes:
		owned_heroes.append("hero_nature_druid")
		print("Force added hero_nature_druid to inventory")
		
	if not "hero_nature_druid" in selected_team_ids and selected_team_ids.size() < MAX_TEAM_SIZE:
		selected_team_ids.append("hero_nature_druid")
		print("Force added hero_nature_druid to team")
	
	# Explicitly ensure it's in the database if dynamic loading missed it (Fallback)
	if not character_db.has("hero_nature_druid"):
		var res = load("res://00_Game/Resources/Characters/hero_nature_druid.tres")
		if res: character_db["hero_nature_druid"] = res

func start_new_game() -> void:
	print(">>> YENİ OYUN BAŞLATILIYOR (RAM + DISK)...")
	
	# 1. Force Set RAM Variables First
	gold = 200
	gems = 50
	owned_heroes = ["hero_fire", "hero_light_mage", "hero_nature_druid"]
	selected_team_ids = ["hero_fire", "hero_light_mage", "hero_nature_druid"]
	hero_levels = {} 
	active_battle_snapshot = {}
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

		"battle_state": active_battle_snapshot,
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
					active_battle_snapshot = loaded_battle

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
		# Save handled by caller or auto-save
	
	current_map_level += 1

func start_level_from_map(level_id: int) -> void:
	current_map_level = level_id
	clear_battle_snapshot()
	save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
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

func save_battle_snapshot(data: Dictionary) -> void:
	active_battle_snapshot = data
	# save_game() - Removed for optimization, handled by auto-save or explicit save

func clear_battle_snapshot() -> void:
	active_battle_snapshot = {}
	save_game() # FIX: Immediate save to prevent "Zombie State" on restart
	
func has_active_battle() -> bool:
	return not active_battle_snapshot.is_empty()

func get_battle_snapshot() -> Dictionary:
	return active_battle_snapshot
	
func reset_battle_state() -> void:
	# Keep for legacy calls/hard resets
	current_map_level = 1
	active_battle_snapshot = {}
	save_game()

# --- HELPER FUNCTIONS ---

func has_enough_gold(amount: int) -> bool:
	return gold >= amount

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_updated.emit(gold)
		save_game() # FIX: Save immediately
		return true
	return false

func add_gold(amount: int) -> void:
	gold += amount
	gold_updated.emit(gold)
	save_game() # FIX: Save immediately

func add_gems(amount: int) -> void:
	gems += amount
	gems_updated.emit(gems)

func spend_gems(amount: int) -> bool:
	if gems >= amount:
		gems -= amount
		gems_updated.emit(gems)
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
	save_game() # FIX: Save immediately

func get_hero_level(id: String) -> int:
	return hero_levels.get(id, 1) # Default to 1 if not found

# --- SCORE & TEAM ---

func check_new_high_score(score: int) -> void:
	if score > high_score:
		high_score = score
		high_score_updated.emit(high_score)

func toggle_hero_selection(hero_id: String) -> void:
	# CRITICAL: Changing team resets any suspended battle
	clear_battle_snapshot()
	
	if hero_id in selected_team_ids:
		selected_team_ids.erase(hero_id)
		team_updated.emit()
	elif selected_team_ids.size() < MAX_TEAM_SIZE and hero_id in owned_heroes:
		selected_team_ids.append(hero_id)
		team_updated.emit()

func is_hero_selected(hero_id: String) -> bool:
	return hero_id in selected_team_ids

# --- INDIVIDUAL HERO STATS ---

func get_hero_attack(damage_type: String) -> int:
	for hero_id in selected_team_ids:
		var data = get_character_data(hero_id)
		if data:
			# Convert data.element_text (e.g. "Fire") to "red" format if needed
			# Quick normalization mapping
			var elem = data.element_text.to_lower()
			var mapped_color = elem
			match elem:
				"fire": mapped_color = "red"
				"water": mapped_color = "blue"
				"earth", "nature": mapped_color = "green"
				"light": mapped_color = "yellow"
				"dark": mapped_color = "purple"
			
			if mapped_color == damage_type:
				var level = get_hero_level(hero_id)
				# Formula: Base 10 + (Level * 3)
				return 10 + (level * 3)
	return 0

func get_hero_skill_power(hero_id: String) -> int:
	if hero_id in owned_heroes:
		var level = get_hero_level(hero_id)
		# Formula: Base 50 + (Level * 25)
		return 50 + (level * 25)
	return 50 # Fallback base
