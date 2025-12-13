extends Node2D

@onready var board_manager: BoardManager = $BoardManager
@onready var enemy: Enemy = $Enemy
@onready var player_hp_bar: ProgressBar = $UILayer/PlayerHPBar
@onready var player_hp_text: Label = $UILayer/PlayerHPBar/PlayerHPText
@onready var ui_layer: CanvasLayer = $UILayer
@onready var mana_bar: TextureProgressBar = $UILayer/ManaBar # Kept for compatibility if needed, but not primary

@export var game_over_scene: PackedScene
@export var floating_text_scene: PackedScene
@export var battle_hero_scene: PackedScene 
@export var heroes_container: HBoxContainer 

@onready var fog_layer: TextureRect = $BackgroundLayer/FogLayer

var current_level: int = 1
var gold_earned_this_session: int = 0
var player_max_hp: int = 500
var player_current_hp: int = 500

var base_enemy_hp: int = 500
var base_enemy_damage: int = 40
var current_enemy_damage: int = 0

var is_player_turn: bool = true
var current_mana: int = 0 # Global mana kept for legacy or other uses if needed
var max_mana: int = 100
var current_score: int = 0
var is_level_transitioning: bool = false 

var leader_data: CharacterData
# var is_damage_buff_active: bool = false # REMOVED per requirement
var buff_remaining_turns: int = 0 # NEW: Duration-based buff

func _ready() -> void:
	if Audio.bg_music:
		Audio.play_music(Audio.bg_music)
		
	# DYNAMIC STATS (SCALING)
	var team_level = GameEconomy.get_team_total_level()
	print(">>> SCALING DEBUG: Team Total Level = ", team_level)
	
	player_max_hp = 500 + (team_level * 50)
	player_current_hp = player_max_hp
	print("Player Max HP Scaled to: ", player_max_hp)
	
	update_player_ui()
	
	# Connect Signals
	board_manager.damage_dealt.connect(_on_player_damage_dealt)
	board_manager.turn_finished.connect(_on_board_settled) 
	board_manager.mana_gained.connect(_on_mana_gained)
	
	if enemy:
		calculate_and_apply_enemy_stats(enemy)
		enemy.attack_finished.connect(_on_enemy_attack_finished)
		enemy.died.connect(_on_enemy_died)
		
	# NEW: Initialize Heroes
	_setup_battle_heroes()
	
	# Debug UI connection
	GameEconomy.gold_updated.connect(func(new_gold): print("UI GOLD UPDATE: ", new_gold))
	
	var leader_id = GameEconomy.get_team_leader_id()
	if leader_id != "":
		leader_data = GameEconomy.get_character_data(leader_id)

func _setup_battle_heroes() -> void:
	if not heroes_container:
		print("Warning: HeroesContainer is not assigned in the Inspector!")
		return
		
	# Clear existing children
	for child in heroes_container.get_children():
		child.queue_free()
		
	var team_ids = GameEconomy.selected_team_ids
	# If no team, maybe safe default or just return
	if team_ids.is_empty():
		return
		
	var leader_id = GameEconomy.get_team_leader_id()
		
	for hero_id in team_ids:
		var data = GameEconomy.get_character_data(hero_id)
		if data:
			var hero_instance = battle_hero_scene.instantiate()
			heroes_container.add_child(hero_instance)
			
			var is_leader = (hero_id == leader_id)
			if hero_instance.has_method("setup"):
				hero_instance.setup(data, is_leader)
				
			if hero_instance.has_signal("skill_activated"):
				hero_instance.skill_activated.connect(_on_hero_skill_activated)

# 1. Oyuncu hamlesini yaptı, taşlar patladı, her şey duruldu.
func _on_board_settled() -> void:
	print("Tahta duruldu. Sıra düşmana geçiyor...")
	is_player_turn = false
	board_manager.is_processing_move = true # Tahtayı kilitle (Garanti olsun)
	
	# Kısa bir bekleme (Olayları idrak etmek için)
	await get_tree().create_timer(0.5).timeout
	
	# Düşmanı saldırt
	if is_instance_valid(enemy):
		enemy.attack_player()
	else:
		start_player_turn()
		
func _on_enemy_attack_finished() -> void:
	# Oyuncuya hasar ver
	take_player_damage(current_enemy_damage)
	# Sırayı oyuncuya ver
	start_player_turn()
	
func start_player_turn() -> void:
	print("Sıra Oyuncuda!")
	is_player_turn = true
	board_manager.is_processing_move = false # Kilidi aç
	
func take_player_damage(amount: int) -> void:
	player_current_hp -= amount
	update_player_ui()
	
	# SCREEN SHAKE
	var tween = create_tween()
	var camera = $Camera2D 
	if camera:
		for i in range(10):
			var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
			tween.tween_property(camera, "offset", offset, 0.05)
		tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

	if player_current_hp <= 0:
		print("GAME OVER - OYUNCU ÖLDÜ")
		game_over(false)

func game_over(is_victory: bool) -> void:
	if not game_over_scene: return
	
	Audio.stop_music()

	if is_victory:
		Audio.play_sfx("victory")
	else:
		Audio.play_sfx("gameover")
	
	# HIGH SCORE CHECK
	GameEconomy.check_new_high_score(current_score)
	
	var popup = game_over_scene.instantiate()
	ui_layer.add_child(popup)
	
	if popup is Control:
		popup.set_anchors_preset(Control.PRESET_FULL_RECT)
		popup.offset_left = 0
		popup.offset_top = 0
		popup.offset_right = 0
		popup.offset_bottom = 0
	
	if popup.has_method("show_result"):
		popup.show_result(is_victory, current_score)
	
	if popup.has_signal("restart_requested"):
		popup.restart_requested.connect(reload_game)

func reload_game() -> void:
	get_tree().reload_current_scene()
		
func update_player_ui() -> void:
	if player_max_hp > 0:
		player_hp_bar.value = (float(player_current_hp) / player_max_hp) * 100
	player_hp_text.text = str(player_current_hp) + " / " + str(player_max_hp)

func _on_player_damage_dealt(amount: int, type: String, match_count: int, combo_count: int) -> void:
	if is_level_transitioning: return
	if not is_instance_valid(enemy):
		return
	
	# DYNAMIC DAMAGE SCALING
	var team_level = GameEconomy.get_team_total_level()
	var base_multiplier = 1.0 + (team_level * 0.1) 
	
	var elemental_multiplier = 1.0
	
	if enemy.get("element_type"):
		var enemy_type = enemy.element_type
		# Advantage Logic (2.0x)
		if (type == "red" and enemy_type == "green") or \
		   (type == "green" and enemy_type == "blue") or \
		   (type == "blue" and enemy_type == "red") or \
		   (type == "yellow" and enemy_type == "purple") or \
		   (type == "purple" and enemy_type == "yellow"):
			elemental_multiplier = 2.0
		# Disadvantage Logic (0.5x)
		elif (type == enemy_type) or \
			 (type == "red" and enemy_type == "blue") or \
			 (type == "green" and enemy_type == "red") or \
			 (type == "blue" and enemy_type == "green"):
			elemental_multiplier = 0.5
			
	var size_multiplier = 1.0
	var combo_multiplier = 1.0
	
	# Match Bonus
	if match_count == 4:
		size_multiplier = 1.5
		spawn_status_text("NICE!", Color.CYAN, enemy.global_position + Vector2(0, -80))
	elif match_count >= 5:
		size_multiplier = 2.0
		spawn_status_text("AMAZING!", Color.MAGENTA, enemy.global_position + Vector2(0, -80))
		
	# Combo Bonus
	if combo_count > 0:
		combo_multiplier = 1.0 + (combo_count * 0.1)
		spawn_status_text("COMBO x%d" % combo_count, Color.YELLOW, enemy.global_position + Vector2(100, -50))
		
	var final_damage = int(amount * base_multiplier * elemental_multiplier * size_multiplier * combo_multiplier)
	
	# UPDATED: BUFF LOGIC (Duration-based)
	if buff_remaining_turns > 0:
		final_damage = int(final_damage * 1.5)
		buff_remaining_turns -= 1
		spawn_status_text("BUFFED! (" + str(buff_remaining_turns) + " left)", Color.YELLOW, enemy.global_position + Vector2(0, -100))
		
	enemy.take_damage(final_damage, type)
	
	# NEW: MANA DISTRIBUTION (Updated to 15 per gem)
	distribute_mana(type, match_count)
	
	# VISUAL FEEDBACK
	var text_content = str(final_damage)
	var text_color = Color.WHITE
	
	match type:
		"red": text_color = Color("#ff4d4d")
		"blue": text_color = Color("#4da6ff")
		"green": text_color = Color("#5cd65c")
		"yellow": text_color = Color("#ffd11a")
		"purple": text_color = Color("#ac00e6")
	
	if elemental_multiplier > 1.0:
		text_content = "CRITICAL!\n%d" % final_damage
		text_color = Color.ORANGE 
		spawn_status_text(text_content, text_color, enemy.global_position)
	elif elemental_multiplier < 1.0:
		text_content = "RESIST\n%d" % final_damage
		text_color = Color.GRAY
		spawn_status_text(text_content, text_color, enemy.global_position)
	else:
		spawn_status_text(text_content, text_color, enemy.global_position)
	
	print("⚔️ DMG REPORT: Base:%d | Elem:x%.1f | Size:x%.1f | Combo:x%.1f -> FINAL: %d" % [amount, elemental_multiplier, size_multiplier, combo_multiplier, final_damage])
	
	current_score += final_damage
	Audio.play_sfx("playerAttack")
	await get_tree().create_timer(0.2).timeout
	Audio.play_sfx("enemyHit")

func distribute_mana(gem_type: String, match_count: int) -> void:
	if heroes_container:
		for hero in heroes_container.get_children():
			if not hero.hero_data: continue
			
			# FIX: CharacterData uses 'element_text' (Fire, Water, etc.) not 'element_type'
			var hero_element = _get_element_color(hero.hero_data.element_text)
			
			if hero_element == gem_type:
				# Mana formula: 15 per tile
				var mana_amount = match_count * 15
				if hero.has_method("add_mana"):
					hero.add_mana(mana_amount)

# Helper to map CharacterData text to Game colors
func _get_element_color(text: String) -> String:
	match text.to_lower():
		"fire": return "red"
		"water": return "blue"
		"earth", "nature": return "green"
		"light": return "yellow"
		"dark": return "purple"
		_: return text.to_lower() # Fallback if it matches directly

func spawn_status_text(text: String, color: Color, location: Vector2, text_scale: float = 1.0) -> void:
	if not floating_text_scene: return
	
	var ft = floating_text_scene.instantiate()
	add_child(ft)
	ft.global_position = location + Vector2(0, -50)
	ft.scale = Vector2(text_scale, text_scale)
	
	if ft.has_method("start_animation"):
		ft.start_animation(text, color)
	
		
func _on_mana_gained(amount: int, color_type: String) -> void:
	# Deprecated function (replaced by _on_player_damage_dealt distribution)
	pass

# NEW: Unified Skill Handler
func _on_hero_skill_activated(hero_data: CharacterData) -> void:
	if is_level_transitioning: return
	if not is_instance_valid(enemy): return
	
	print("SKILL USED: ", hero_data.skill_name)
	Audio.play_sfx("combo", 0.5)
	
	var power = hero_data.skill_power
	var type = hero_data.skill_type
	
	# Scaling based on team level
	var team_level = GameEconomy.get_team_total_level()
	var final_power = int(power * (1.0 + (team_level * 0.1)))
	
	match type:
		CharacterData.SkillType.DIRECT_DAMAGE:
			if enemy.vfx_hit_scene:
				var vfx = enemy.vfx_hit_scene.instantiate()
				enemy.add_child(vfx)
				vfx.scale = Vector2(3.0, 3.0)
				vfx.setup(Vector2.ZERO, Color.RED)
			enemy.take_damage(final_power, "magic")
			spawn_status_text("SKILL!", Color.RED, enemy.global_position)
			
		CharacterData.SkillType.HEAL:
			heal_player(final_power)
			spawn_status_text("HEAL +%d" % final_power, Color.GREEN, ui_layer.offset + Vector2(200, 400))
			var color_rect = ColorRect.new()
			ui_layer.add_child(color_rect)
			color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			color_rect.color = Color(0, 1, 0, 0.3)
			var tween = create_tween()
			tween.tween_property(color_rect, "modulate:a", 0.0, 0.5)
			tween.tween_callback(color_rect.queue_free)
			
		CharacterData.SkillType.BUFF_ATTACK:
			# UPDATED: Duration-based Logic
			buff_remaining_turns = 3
			spawn_status_text("RAGE MODE! (3 HITS)", Color.YELLOW, ui_layer.offset + Vector2(200, 400))
			
	var camera = $Camera2D
	if camera:
		var tween = create_tween()
		for i in range(20):
			tween.tween_property(camera, "offset", Vector2(randf_range(-10,10), randf_range(-10,10)), 0.02)
		tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

func _process(delta: float) -> void:
	# Skill button animation deprecated, logic moved to BattleHero
	pass

func _on_enemy_died() -> void:
	is_level_transitioning = true
	print("Düşman Öldü! Seviye Atlanıyor...")
	Audio.play_sfx("victory") 
	
	var is_boss_level = (current_level % 5 == 0)
	var gold_reward = 0
	
	if is_boss_level:
		gold_reward = 500
		var center = get_viewport_rect().get_center()
		spawn_status_text("BOSS CLEARED!", Color.PURPLE, center + Vector2(0, -100), 1.5)
		spawn_status_text("+500 GOLD", Color.YELLOW, center)
		spawn_status_text("HEALED!", Color.GREEN, center + Vector2(0, 50))
		heal_player(int(player_max_hp * 0.3))
	else:
		gold_reward = 100 * current_level
		heal_player(int(player_max_hp * 0.2))
	
	gold_earned_this_session += gold_reward
	GameEconomy.add_gold(gold_reward) 
	print(">>> Gold Reward Added: ", gold_reward)
	
	current_level += 1
	
	board_manager.is_processing_move = true 
	await get_tree().create_timer(1.0).timeout
	
	spawn_next_enemy()

func spawn_next_enemy() -> void:
	# RESET BUFFS (Do not carry over)
	buff_remaining_turns = 0
	
	if is_instance_valid(enemy):
		enemy.queue_free()
	
	var new_enemy = load("res://00_Game/Scenes/Enemy.tscn").instantiate()
	add_child(new_enemy)
	new_enemy.position = Vector2(360, 250)
	
	calculate_and_apply_enemy_stats(new_enemy)
	
	if current_level % 5 == 0:
		new_enemy.max_hp *= 3
		current_enemy_damage = int(current_enemy_damage * 1.5)
		new_enemy.current_hp = new_enemy.max_hp
		new_enemy.update_ui()
		new_enemy.scale = Vector2(1.5, 1.5)
		var center_pos = get_viewport_rect().get_center()
		spawn_status_text("BOSS FIGHT!", Color.RED, center_pos, 2.0)
	else:
		new_enemy.scale = Vector2(1.0, 1.0)
		var center_pos = get_viewport_rect().get_center()
		spawn_status_text("LEVEL " + str(current_level), Color.WHITE, center_pos, 1.0)

	var types = ["red", "blue", "green", "yellow", "purple"]
	var random_type = types.pick_random()
	new_enemy.setup_element(random_type)
	
	enemy = new_enemy
	enemy.attack_finished.connect(_on_enemy_attack_finished)
	enemy.died.connect(_on_enemy_died)
	
	board_manager.is_processing_move = false
	start_player_turn()
	
	is_level_transitioning = false

func calculate_and_apply_enemy_stats(target_enemy: Enemy) -> void:
	var multiplier = 1.0 + ((current_level - 1) * 0.2)
	target_enemy.max_hp = int(base_enemy_hp * multiplier)
	current_enemy_damage = int(base_enemy_damage * multiplier)
	target_enemy.current_hp = target_enemy.max_hp
	target_enemy.update_ui()
	print("⚔️ DÜŞMAN STATLARI (Lvl ", current_level, ") -> Can: ", target_enemy.max_hp, " | Hasar: ", current_enemy_damage)

func heal_player(amount: int) -> void:
	player_current_hp = min(player_current_hp + amount, player_max_hp)
	update_player_ui()
