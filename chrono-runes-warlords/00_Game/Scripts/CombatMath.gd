class_name CombatMath extends Node

static func calculate_damage(base_damage: int, damage_type: String, enemy_element: String, match_size: int, combo_count: int, hero_attack: int, active_buff_mult: float) -> int:
	# 1. Size Multiplier
	var size_multiplier = 1.0
	if match_size == 4:
		size_multiplier = 1.25
	elif match_size >= 5:
		size_multiplier = 2.0
		
	# 2. Elemental Multiplier
	var elemental_multiplier = get_elemental_multiplier(damage_type, enemy_element)
	
	# 3. Combo Multiplier
	var combo_multiplier = 1.0 + (combo_count * 0.1)
	
	# 4. Formula
	# (base_damage * MatchMult * ElemMult * ComboMult * BuffMult) + hero_attack
	var board_damage = base_damage * size_multiplier * elemental_multiplier * combo_multiplier * active_buff_mult
	
	return int(board_damage + hero_attack)

static func get_elemental_multiplier(damage_type: String, enemy_element: String) -> float:
	if enemy_element == "": return 1.0
	
	# Weakness (2.0x)
	if (damage_type == "red" and enemy_element == "green") or \
	   (damage_type == "green" and enemy_element == "blue") or \
	   (damage_type == "blue" and enemy_element == "red") or \
	   (damage_type == "yellow" and enemy_element == "purple") or \
	   (damage_type == "purple" and enemy_element == "yellow"):
		return 2.0
		
	# Resistance (0.5x)
	elif (damage_type == "green" and enemy_element == "red") or \
		 (damage_type == "blue" and enemy_element == "green") or \
		 (damage_type == "red" and enemy_element == "blue"):
		return 0.5
		
	return 1.0

static func get_damage_color(type: String, is_crit: bool, is_resist: bool) -> Color:
	if is_crit:
		return Color.GOLD
	if is_resist:
		return Color.GRAY
		
	match type:
		"red": return Color(1.0, 0.3, 0.3)
		"blue": return Color(0.3, 0.6, 1.0)
		"green": return Color(0.4, 0.8, 0.4)
		"yellow": return Color(1.0, 1.0, 0.4)
		"purple": return Color(0.7, 0.4, 1.0)
		_: return Color(0.9, 0.9, 0.9)
