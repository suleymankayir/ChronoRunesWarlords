class_name BattleStateManager extends Node

# Handles battle state persistence (save/load)
# Extracted from MainGame.gd for better separation of concerns

signal state_saved
signal state_loaded(data: Dictionary)

# Save throttling
var turns_since_last_save: int = 0
const SAVE_INTERVAL: int = 3

# References (set by MainGame)
var board_manager: BoardManager
var heroes_container: HBoxContainer
var enemy: Node

# Battle state variables (synced from MainGame)
# NOTE: These duplicate MainGame state for now. Future refactor should
# consolidate to single source of truth using sync_state() method.
var current_level: int = 1
var current_wave: int = 1
var player_current_hp: int = 1000
var current_score: int = 0
var is_level_transitioning: bool = false

# Call this to sync state from MainGame before saving
func sync_state(level: int, wave: int, hp: int, score: int, transitioning: bool) -> void:
	current_level = level
	current_wave = wave
	player_current_hp = hp
	current_score = score
	is_level_transitioning = transitioning

func should_auto_save() -> bool:
	turns_since_last_save += 1
	if turns_since_last_save >= SAVE_INTERVAL:
		turns_since_last_save = 0
		return true
	return false

func reset_save_counter() -> void:
	turns_since_last_save = 0

func save_battle_state(force: bool = false) -> void:
	if player_current_hp <= 0: return
	
	# SAFETY: Don't save during level transitions unless forced
	if is_level_transitioning and not force: return
	
	var ehp = 0
	var eelem = "red"
	if is_instance_valid(enemy):
		ehp = max(0, enemy.current_hp)
		
		# CRITICAL: Don't save dead enemy state
		if ehp <= 0:
			print("⚠️ Skipping save: enemy is dead or dying")
			return
			
		if "element_type" in enemy: eelem = enemy.element_type
		
		# Save Status
		GameEconomy.current_enemy_stun_turns = enemy.stun_turns
		GameEconomy.current_enemy_dot_turns = enemy.dot_turns
		GameEconomy.current_enemy_break_turns = enemy.defense_break_turns
	else:
		print("⚠️ Skipping save: no valid enemy instance")
		return
		
	var manas = {}
	if heroes_container:
		for h in heroes_container.get_children():
			if h.hero_data and "current_mana" in h:
				manas[h.hero_data.id] = h.current_mana
			else:
				print("⚠️ Hero missing data/mana property: ", h)

	print(">>> Saving Battle State | Mana: ", manas)
	
	var data = {
		"level": current_level,
		"wave": current_wave,
		"player_hp": player_current_hp,
		"score": current_score,
		"enemy_hp": ehp,
		"enemy_element": eelem,
		"board": board_manager.get_board_data() if board_manager else [],
		"heroes_mana": manas
	}
	GameEconomy.save_battle_snapshot(data)
	state_saved.emit()

func load_battle_state() -> Dictionary:
	var data = GameEconomy.get_battle_snapshot()
	current_level = data.get("level", 1)
	current_wave = data.get("wave", 1)
	player_current_hp = data.get("player_hp", 1000)
	current_score = data.get("score", 0)
	
	state_loaded.emit(data)
	return data

func get_enemy_data_from_snapshot() -> Dictionary:
	var data = GameEconomy.get_battle_snapshot()
	return {
		"hp": data.get("enemy_hp", 500),
		"element": data.get("enemy_element", "red"),
		"board": data.get("board", [])
	}
