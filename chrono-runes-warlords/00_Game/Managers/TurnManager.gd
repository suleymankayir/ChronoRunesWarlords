class_name TurnManager extends Node

# Handles turn flow orchestration (player/enemy turns)
# Extracted from MainGame.gd for better separation of concerns

signal player_turn_started
signal enemy_turn_started
signal turn_ended
signal request_save

# Buff state
var active_buff_multiplier: float = 1.0
var buff_remaining_turns: int = 0

# Turn state
var is_player_turn: bool = true

# References (set by MainGame)
var enemy: Node
var board_manager: BoardManager

func start_player_turn() -> void:
	is_player_turn = true
	
	# Decrement buff duration at start of player turn
	if buff_remaining_turns > 0:
		buff_remaining_turns -= 1
		if buff_remaining_turns <= 0: 
			active_buff_multiplier = 1.0
			# Signal MainGame to show "Buff Ended" text
	
	if board_manager: 
		board_manager.is_processing_move = false
	
	player_turn_started.emit()

func end_player_turn() -> void:
	is_player_turn = false
	if board_manager: 
		board_manager.is_processing_move = true
	
	turn_ended.emit()

func start_enemy_turn() -> void:
	if not is_instance_valid(enemy):
		start_player_turn()
		return
		
	enemy_turn_started.emit()
	
	# Process Status
	var is_stunned = false
	if enemy.has_method("process_turn_start"):
		is_stunned = enemy.process_turn_start()
		
	if is_stunned:
		# Enemy is stunned, skip to player turn
		# MainGame handles the visual feedback
		# SAFETY: Guard against null get_tree()
		if get_tree():
			await get_tree().create_timer(1.0).timeout
		start_player_turn()
	else:
		if enemy.has_method("attack_player"):
			enemy.attack_player()
		else:
			_on_enemy_attack_finished()

func _on_enemy_attack_finished() -> void:
	# MainGame handles the actual damage
	request_save.emit()
	start_player_turn()

func apply_buff(multiplier: float, turns: int) -> void:
	active_buff_multiplier = multiplier
	buff_remaining_turns = turns

func get_buff_multiplier() -> float:
	return active_buff_multiplier

func is_buff_active() -> bool:
	return buff_remaining_turns > 0
