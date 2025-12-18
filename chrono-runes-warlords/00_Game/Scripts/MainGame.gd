extends Node2D

@onready var board_manager: BoardManager = $BoardManager
@onready var enemy: Enemy = $Enemy
@onready var player_hp_bar: ProgressBar = $UILayer/PlayerHPBar
@onready var player_hp_text: Label = $UILayer/PlayerHPBar/PlayerHPText
@onready var ui_layer: CanvasLayer = $UILayer
@onready var mana_bar: TextureProgressBar = $UILayer/ManaBar 
@onready var fog_layer: TextureRect = $BackgroundLayer/FogLayer

@export var game_over_scene: PackedScene
@export var floating_text_scene: PackedScene
@export var battle_hero_scene: PackedScene 
@export var heroes_container: HBoxContainer 
@export var pause_menu_scene: PackedScene 
@export var camera: Camera2D

var current_level: int = 1
var gold_earned_this_session: int = 0
var player_max_hp: int = 500
var player_current_hp: int = 500

var base_enemy_hp: int = 500
var base_enemy_damage: int = 40
var current_enemy_damage: int = 0

var is_player_turn: bool = true
var is_level_transitioning: bool = false 

var current_combo: int = 0
var current_score: int = 0

var leader_data: CharacterData
var buff_remaining_turns: int = 0 
var active_buff_multiplier: float = 1.0 
var current_wave: int = 1 # Added for Suspend/Resume tracking 

func _ready() -> void:
	if Audio.bg_music:
		Audio.play_music(Audio.bg_music)
		
	# Use global level tracking
	current_level = GameEconomy.current_map_level
		
	# DYNAMIC STATS
	var team_level = GameEconomy.get_team_total_level()
	player_max_hp = 500 + (team_level * 50)
	
	board_manager.damage_dealt.connect(_on_player_damage_dealt)
	board_manager.turn_finished.connect(_on_board_settled) 
	board_manager.mana_gained.connect(_on_mana_gained)
	
	# BATTLE PERSISTENCE CHECK
	if GameEconomy.has_active_battle():
		print(">>> RESUMING SAVED BATTLE STATE...")
		_load_battle_state()
	else:
		print(">>> STARTING FRESH BATTLE...")
		player_current_hp = player_max_hp
		
		# Reset Mana for all heroes if possible (requires waiting for setup or doing it in setup)
		# For now, just ensure enemy setup is correct for the level
		if is_instance_valid(enemy): enemy.queue_free()
		
		# Spawn fresh enemy
		spawn_next_enemy()
		board_manager.spawn_board()

		
	update_player_ui()
	_setup_battle_heroes()
	
	var leader_id = GameEconomy.get_team_leader_id()
	if leader_id != "":
		leader_data = GameEconomy.get_character_data(leader_id)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not get_tree().paused:
			show_pause_menu()

func show_pause_menu() -> void:
	if not pause_menu_scene: return
	
	# Create a DEDICATED CanvasLayer for the Pause Menu
	var pause_layer = CanvasLayer.new()
	pause_layer.layer = 100 
	pause_layer.name = "DedicatedPauseLayer"
	add_child(pause_layer)
	
	var menu = pause_menu_scene.instantiate()
	pause_layer.add_child(menu)
	
	if menu.has_signal("quit_requested"):
		menu.quit_requested.connect(_on_pause_quit)
		
	get_tree().paused = true

func _on_pause_quit() -> void:
	# SUSPEND SESSION: Save state so we can resume (unless team changes)
	_save_current_battle_state()
	GameEconomy.save_game() # FIX: Flush to disk immediately
	await get_tree().create_timer(0.1).timeout # Safety Buffer
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainMenu.tscn")

func _setup_battle_heroes() -> void:
	if not heroes_container: return
	for child in heroes_container.get_children():
		child.queue_free()
	var team_ids = GameEconomy.selected_team_ids
	var leader_id = GameEconomy.get_team_leader_id()
	
	var saved_mana = {}
	
	if GameEconomy.has_active_battle() and GameEconomy.active_battle_snapshot.has("heroes_mana"):
		saved_mana = GameEconomy.active_battle_snapshot["heroes_mana"]
	
	for hero_id in team_ids:
		var data = GameEconomy.get_character_data(hero_id)
		if data:
			var hero_instance = battle_hero_scene.instantiate()
			heroes_container.add_child(hero_instance)
			var is_leader = (hero_id == leader_id)
			if hero_instance.has_method("setup"):
				hero_instance.setup(data, is_leader)
			
			if saved_mana.has(hero_id):
				hero_instance.current_mana = int(saved_mana[hero_id])
				if hero_instance.has_method("update_ui"):
					hero_instance.update_ui()
			
			if hero_instance.has_signal("skill_activated"):
				hero_instance.skill_activated.connect(_on_hero_skill_activated)

func _on_board_settled() -> void:
	_save_current_battle_state()
	GameEconomy.save_game() # Fixed: Aggressive Save
	print("Auto-saved after turn.")
	
	is_player_turn = false
	board_manager.is_processing_move = true 
	await get_tree().create_timer(0.5).timeout
	
	if is_instance_valid(enemy):
		_start_enemy_turn()
	else:
		start_player_turn()

func _start_enemy_turn() -> void:
	if not is_instance_valid(enemy):
		start_player_turn()
		return
		
	# PROCESS STATUS EFFECTS
	var is_stunned = enemy.process_turn_start()
	
	if is_stunned:
		spawn_status_text("DÜŞMAN SERSEMLEDİ!", Color.BLUE, enemy.global_position + Vector2(0, -100), 1.5)
		await get_tree().create_timer(1.0).timeout
		start_player_turn()
	else:
		enemy.attack_player()
		
func _on_enemy_attack_finished() -> void:
	take_player_damage(current_enemy_damage)
	start_player_turn()
	_save_current_battle_state() 
	
func start_player_turn() -> void:
	is_player_turn = true
	board_manager.is_processing_move = false 
	
func take_player_damage(amount: int) -> void:
	player_current_hp -= amount
	update_player_ui()
	shake_screen(5.0, 0.3)
	
	if player_current_hp <= 0:
		GameEconomy.clear_battle_snapshot() 
		game_over(false)

func game_over(is_victory: bool) -> void:
	if not game_over_scene: return
	Audio.stop_music()
	if is_victory: Audio.play_sfx("victory")
	else: Audio.play_sfx("gameover")
	
	GameEconomy.check_new_high_score(current_score)
	
	if not is_victory:
		GameEconomy.clear_battle_snapshot()
	else:
		# If you want to keep state for subsequent wins until boss is done, logic goes here.
		# For now, we clear it here OR in _on_enemy_died. 
		# But usually on GAME OVER (win/loss screen), we might want to clear.
		# However, existing logic clears in _on_enemy_died before moving to next level IF it's a win.
		# Wait, actually GameEconomy.clear_battle_snapshot() was already there.
		# THE CRITICAL FIX is ensuring it clears on LOSS.
		# THE CRITICAL FIX is ensuring it clears on LOSS.
		GameEconomy.clear_battle_snapshot()
		# Explicit Save on Game Over
		GameEconomy.save_game()

	
	var popup = game_over_scene.instantiate()
	ui_layer.add_child(popup)
	if popup.has_method("show_result"):
		popup.show_result(is_victory, current_score)
	if popup.has_signal("restart_requested"):
		popup.restart_requested.connect(_on_restart_game)

func _on_restart_game() -> void:
	# FIX: Clear state before reloading to prevent "Zombie Loop"
	GameEconomy.clear_battle_snapshot()
	get_tree().paused = false
	get_tree().reload_current_scene()
		
func update_player_ui() -> void:
	if player_max_hp > 0:
		player_hp_bar.value = (float(player_current_hp) / player_max_hp) * 100
	player_hp_text.text = str(player_current_hp) + " / " + str(player_max_hp)

func _on_player_damage_dealt(amount: int, type: String, match_count: int, combo_count: int) -> void:
	if is_level_transitioning: return
	if not is_instance_valid(enemy): return
	
	# 1. Get Stats & Info
	var hero_attack = GameEconomy.get_hero_attack(type)
	var enemy_elem = enemy.element_type if enemy.get("element_type") else ""
	
	# 2. Calculate Final Damage
	var final_damage = CombatMath.calculate_damage(
		amount, 
		type, 
		enemy_elem, 
		match_count, 
		combo_count, 
		hero_attack, 
		active_buff_multiplier
	)
	
	# Handle Buff Expiry
	if buff_remaining_turns > 0:
		buff_remaining_turns -= 1
		if buff_remaining_turns <= 0:
			active_buff_multiplier = 1.0

	enemy.take_damage(final_damage, type)
	distribute_mana(type, match_count)
	
	# 3. Visuals & Juice (Refactored)
	var elem_mult = CombatMath.get_elemental_multiplier(type, enemy_elem)
	var is_crit = elem_mult > 1.0
	var is_resist = elem_mult < 1.0
	
	# Determine Text Scale & Color with Priority
	var text_content = str(final_damage)
	var text_scale = 1.0
	var text_color = CombatMath.get_damage_color(type, is_crit, is_resist)
	
	if match_count >= 5:
		text_scale = 2.0
		text_color = Color.MAGENTA
		spawn_status_text("LEGENDARY!", Color.VIOLET, get_viewport_rect().get_center() + Vector2(0, -350), 2.0)
	elif is_crit:
		text_scale = 1.6
		text_color = Color.GOLD
		text_content = "CRITICAL %s!" % final_damage
	elif match_count == 4:
		text_scale = 1.3
		text_color = Color.CYAN
		spawn_status_text("GREAT!", Color.CYAN, get_viewport_rect().get_center() + Vector2(0, -350), 1.5)
	elif is_resist:
		text_scale = 0.7
		text_color = Color.GRAY
		text_content = "RESIST %s" % final_damage
		
	if active_buff_multiplier > 1.0:
		text_content += "\nBUFFED"
		text_scale *= 1.2
		
	# Spawn Damage Text
	spawn_status_text(text_content, text_color, enemy.global_position, text_scale)
	
	# Dynamic Screen Shake
	var shake_intensity = 0.0
	var shake_duration = 0.0
	
	if match_count == 3:
		shake_intensity = 2.0
		shake_duration = 0.2
	elif match_count == 4:
		shake_intensity = 5.0
		shake_duration = 0.3
	elif match_count >= 5:
		shake_intensity = 10.0
		shake_duration = 0.5
		
	if combo_count > 1:
		shake_intensity += float(combo_count)
		# Combo Text
		var combo_text = "COMBO x%d" % combo_count
		var center_pos = get_viewport_rect().get_center() + Vector2(0, -200)
		var combo_jitter = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		spawn_status_text(combo_text, Color.GOLD, center_pos + combo_jitter, 1.3)
		
	if shake_intensity > 0:
		shake_screen(shake_intensity, shake_duration)
	
	current_score += final_damage
	
	# Audio Pitch Scaling
	var pitch_mod = 1.0 + (float(combo_count) * 0.05)
	Audio.play_sfx("playerAttack", pitch_mod)
	
	await get_tree().create_timer(0.2).timeout
	Audio.play_sfx("enemyHit")

func distribute_mana(gem_type: String, match_count: int) -> void:
	if heroes_container:
		for hero in heroes_container.get_children():
			if not hero.hero_data: continue
			var hero_element = _get_element_color(hero.hero_data.element_text)
			if hero_element == gem_type:
				var mana_amount = match_count * 15
				if hero.has_method("add_mana"): hero.add_mana(mana_amount)

func _get_element_color(text: String) -> String:
	match text.to_lower():
		"fire": return "red"
		"water": return "blue"
		"earth", "nature": return "green"
		"light": return "yellow"
		"dark": return "purple"
		_: return text.to_lower() 

func _get_element_color_value(type: String) -> Color:
	match type:
		"red": return Color(1.0, 0.3, 0.3)
		"blue": return Color(0.3, 0.6, 1.0)
		"green": return Color(0.4, 0.8, 0.4)
		"yellow": return Color(1.0, 1.0, 0.4)
		"purple": return Color(0.7, 0.4, 1.0)
		_: return Color(0.9, 0.9, 0.9)

func spawn_status_text(text: String, color: Color, location: Vector2, text_scale: float = 1.0) -> void:
	if not floating_text_scene: return
	var ft = floating_text_scene.instantiate()
	add_child(ft)
	# JITTER: Prevent overlap for simultaneous texts
	var jitter = Vector2(randf_range(-40, 40), randf_range(-40, 40))
	ft.global_position = location + Vector2(0, -50) + jitter
	
	# POP ANIMATION
	ft.scale = Vector2.ZERO
	var target_scale = Vector2(text_scale, text_scale)
	var tween = create_tween()
	tween.tween_property(ft, "scale", target_scale * 1.5, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ft, "scale", target_scale, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if ft.has_method("start_animation"):
		ft.start_animation(text, color)
		
func shake_screen(intensity: float, duration: float) -> void:
	if not camera: return
	
	var original_offset = camera.offset
	var tween = create_tween()
	var loops = int(duration * 20)
	
	for i in range(loops):
		var rand_x = randf_range(-intensity, intensity)
		var rand_y = randf_range(-intensity, intensity)
		tween.tween_property(camera, "offset", original_offset + Vector2(rand_x, rand_y), 0.05)
		
	tween.tween_property(camera, "offset", original_offset, 0.05)
		
func _on_mana_gained(amount: int, color_type: String) -> void:
	pass

func _on_hero_skill_activated(hero_data: CharacterData) -> void:
	if is_level_transitioning: return
	if not is_instance_valid(enemy): return
	
	Audio.play_sfx("combo", 0.5)
	
	var hero_level = GameEconomy.get_hero_level(hero_data.id)
	var final_power = GameEconomy.get_hero_skill_power(hero_data.id)
	
	match hero_data.skill_type:
		CharacterData.SkillType.DIRECT_DAMAGE:
			# Buff Application
			if buff_remaining_turns > 0:
				final_power = int(final_power * active_buff_multiplier)
				buff_remaining_turns -= 1
				if buff_remaining_turns <= 0:
					active_buff_multiplier = 1.0
			
			enemy.take_damage(final_power, "magic")
			spawn_status_text("SKILL!\n%d" % final_power, Color.RED, enemy.global_position, 1.2)
			
		CharacterData.SkillType.HEAL:
			var heal_amount = 200 + (hero_level * 30)
			heal_player(heal_amount)
			spawn_status_text("HEAL +%d" % heal_amount, Color.GREEN, ui_layer.offset + Vector2(200, 400), 1.2)
			
		CharacterData.SkillType.BUFF_ATTACK:
			active_buff_multiplier = 1.2 + (float(hero_level) * 0.05)
			buff_remaining_turns = 5
			spawn_status_text("DAMAGE UP!\nx%.2f" % active_buff_multiplier, Color.GOLD, ui_layer.offset + Vector2(200, 400), 1.2)

		CharacterData.SkillType.STUN:
			enemy.apply_status("stun", 2)
			spawn_status_text("KÖK SALDI!", Color.BLUE, enemy.global_position, 1.5)
			
		CharacterData.SkillType.DOT:
			var dot_dmg = int(final_power * 0.5)
			enemy.apply_status("dot", 3, dot_dmg)
			spawn_status_text("ZEHİRLENDİ!", Color.PURPLE, enemy.global_position, 1.2)
			
		CharacterData.SkillType.DEFENSE_BREAK:
			enemy.apply_status("def_break", 3)
			spawn_status_text("ZIRH KIRILDI!", Color.YELLOW, enemy.global_position, 1.2)
			
		CharacterData.SkillType.MANA_BATTERY:
			spawn_status_text("MANA YÜKLENDİ!", Color.CYAN, get_viewport_rect().get_center(), 1.2)
			if heroes_container:
				for hero in heroes_container.get_children():
					# Don't give mana to self to prevent infinite loops if cost < gain
					if hero.hero_data and hero.hero_data.id != hero_data.id:
						if hero.has_method("add_mana"):
							hero.add_mana(50)
							
		CharacterData.SkillType.CLEANSE:
			spawn_status_text("ARINDIRILDI!", Color.WHITE, get_viewport_rect().get_center(), 1.2)
			# Placeholder logic: In future, clear negative statuses on player if any
			
		CharacterData.SkillType.BOARD_MANIPULATION: # Color Wipe
			if board_manager:
				board_manager.destroy_gems_by_color(hero_data.element_text.to_lower())
				
		CharacterData.SkillType.TRANSMUTE:
			if board_manager:
				# Transmute 5 random gems to hero's element
				board_manager.transmute_pieces(5, hero_data.element_text.to_lower())
	
	# Save state immediately after using ANY skill
	_save_current_battle_state()
	GameEconomy.save_game()

func _on_enemy_died() -> void:
	is_level_transitioning = true
	Audio.play_sfx("victory") 
	
	var is_boss_level = (current_level % 5 == 0)
	var gold_reward = 100 * current_level
	if is_boss_level: gold_reward = 500
	
	heal_player(int(player_max_hp * 0.2))
	gold_earned_this_session += gold_reward
	GameEconomy.add_gold(gold_reward) 
	
	# PROGRESSION UPDATE
	GameEconomy.complete_current_level()
	# Explicit Save on Win (Major Event)
	GameEconomy.save_game()
	
	# GameEconomy incremented map_level, so we update local too
	current_level = GameEconomy.current_map_level
	
	_save_current_battle_state() 
	
	board_manager.is_processing_move = true 
	await get_tree().create_timer(1.0).timeout
	spawn_next_enemy()

func spawn_next_enemy() -> void:
	buff_remaining_turns = 0
	if is_instance_valid(enemy): enemy.queue_free()
	
	var new_enemy = load("res://00_Game/Scenes/Enemy.tscn").instantiate()
	add_child(new_enemy)
	new_enemy.position = Vector2(360, 250)
	
	calculate_and_apply_enemy_stats(new_enemy)
	
	# FIX: Force UI update here to ensure Max HP is correct, especially for bosses
	new_enemy.update_ui()
			
	var types = ["red", "blue", "green", "yellow", "purple"]
	var random_type = types.pick_random()
	new_enemy.setup_element(random_type)
	
	enemy = new_enemy
	enemy.attack_finished.connect(_on_enemy_attack_finished)
	enemy.died.connect(_on_enemy_died)
	
	board_manager.is_processing_move = false
	start_player_turn()
	is_level_transitioning = false
	
	_save_current_battle_state()

func calculate_and_apply_enemy_stats(target_enemy: Enemy) -> void:
	# 1. Base Multiplier (Smoother Curve)
	var multiplier = 1.0 + ((current_level - 1) * 0.15)
	
	# 2. Apply Base Stats
	target_enemy.max_hp = int(base_enemy_hp * multiplier)
	current_enemy_damage = int(base_enemy_damage * multiplier)
	
	# 3. Boss Check & Modifiers
	if current_level % 5 == 0:
		target_enemy.max_hp = int(target_enemy.max_hp * 2.5)
		current_enemy_damage = int(current_enemy_damage * 1.3)
		target_enemy.scale = Vector2(1.5, 1.5)
	else:
		target_enemy.scale = Vector2(1.0, 1.0)

	# 4. Finalize
	target_enemy.current_hp = target_enemy.max_hp
	target_enemy.update_ui()

func heal_player(amount: int) -> void:
	player_current_hp = min(player_current_hp + amount, player_max_hp)
	update_player_ui()

# --- STATE SAVING & LOADING ---

func _save_current_battle_state() -> void:
	# FIX: Do not save state if player is dead (avoids "Zombie Loop")
	if player_current_hp <= 0:
		return
		
	var enemy_hp = 0
	var enemy_elem = "red"
	if is_instance_valid(enemy):
		enemy_hp = enemy.current_hp
		enemy_elem = enemy.element_type
	
	var heroes_mana = {}
	if heroes_container:
		for hero in heroes_container.get_children():
			if hero.get("hero_data") and "current_mana" in hero:
				heroes_mana[hero.hero_data.id] = hero.current_mana
		
	var data = {
		"level": current_level,
		"wave": current_wave,
		"player_hp": player_current_hp,
		"score": current_score,
		"enemy_hp": enemy_hp,
		"enemy_element": enemy_elem,
		"board": board_manager.get_board_data(),
		"heroes_mana": heroes_mana
	}
	GameEconomy.save_battle_snapshot(data)

func _load_battle_state() -> void:
	var data = GameEconomy.get_battle_snapshot()
	current_level = data.get("level", 1)
	current_wave = data.get("wave", 1)
	player_current_hp = data.get("player_hp", player_max_hp)
	current_score = data.get("score", 0)
	
	var enemy_hp = data.get("enemy_hp", 500)
	var enemy_elem = data.get("enemy_element", "red")
	var board_data = data.get("board", [])
	
	if is_instance_valid(enemy): enemy.queue_free()
	
	var new_enemy = load("res://00_Game/Scenes/Enemy.tscn").instantiate()
	add_child(new_enemy)
	new_enemy.position = Vector2(360, 250)
	calculate_and_apply_enemy_stats(new_enemy)
	
	new_enemy.current_hp = enemy_hp
	new_enemy.setup_element(enemy_elem)
	new_enemy.update_ui()
	
	# FIX: Auto-kill if loaded dead enemy (Zombie Bug)
	if new_enemy.current_hp <= 0:
		print("Loaded a dead enemy (0 HP). Triggering death sequence...")
		if new_enemy.has_method("die"):
			new_enemy.die()
		else:
			_on_enemy_died() # Fallback if no public die method
	
	if current_level % 5 == 0:
		new_enemy.scale = Vector2(1.5, 1.5)
		
	enemy = new_enemy
	enemy.attack_finished.connect(_on_enemy_attack_finished)
	enemy.died.connect(_on_enemy_died)
	
	board_manager.load_board_data(board_data)
	start_player_turn()
