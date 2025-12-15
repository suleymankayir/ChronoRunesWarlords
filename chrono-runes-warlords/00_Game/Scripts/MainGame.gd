extends Node2D

@onready var board_manager: BoardManager = $BoardManager
@onready var enemy: Enemy = $Enemy
@onready var player_hp_bar: ProgressBar = $UILayer/PlayerHPBar
@onready var player_hp_text: Label = $UILayer/PlayerHPBar/PlayerHPText
@onready var ui_layer: CanvasLayer = $UILayer
@onready var mana_bar: TextureProgressBar = $UILayer/ManaBar 

@export var game_over_scene: PackedScene
@export var floating_text_scene: PackedScene
@export var battle_hero_scene: PackedScene 
@export var heroes_container: HBoxContainer 
@export var pause_menu_scene: PackedScene 

@onready var fog_layer: TextureRect = $BackgroundLayer/FogLayer

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

func _ready() -> void:
	if Audio.bg_music:
		Audio.play_music(Audio.bg_music)
		
	# DYNAMIC STATS
	var team_level = GameEconomy.get_team_total_level()
	player_max_hp = 500 + (team_level * 50)
	
	board_manager.damage_dealt.connect(_on_player_damage_dealt)
	board_manager.turn_finished.connect(_on_board_settled) 
	board_manager.mana_gained.connect(_on_mana_gained)
	
	# BATTLE PERSISTENCE CHECK
	if GameEconomy.has_saved_battle():
		print(">>> RESUMING SAVED BATTLE STATE...")
		_load_battle_state()
	else:
		print(">>> STARTING FRESH BATTLE...")
		player_current_hp = player_max_hp
		if enemy:
			calculate_and_apply_enemy_stats(enemy)
			enemy.attack_finished.connect(_on_enemy_attack_finished)
			enemy.died.connect(_on_enemy_died)
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
	# This ensures it resides on top of everything (Layer 100) and is isolated from other UI constraints.
	var pause_layer = CanvasLayer.new()
	pause_layer.layer = 100 
	pause_layer.name = "DedicatedPauseLayer"
	add_child(pause_layer)
	
	var menu = pause_menu_scene.instantiate()
	pause_layer.add_child(menu)
	
	# Connect Signals
	if menu.has_signal("quit_requested"):
		menu.quit_requested.connect(_on_pause_quit)
		
	# Pause the game
	get_tree().paused = true

func _on_pause_quit() -> void:
	# CRITICAL: Save Logic
	_save_current_battle_state()
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainMenu.tscn")

func _setup_battle_heroes() -> void:
	if not heroes_container: return
	for child in heroes_container.get_children():
		child.queue_free()
	var team_ids = GameEconomy.selected_team_ids
	var leader_id = GameEconomy.get_team_leader_id()
	
	var saved_mana = {}
	if GameEconomy.has_saved_battle() and GameEconomy.battle_state.has("heroes_mana"):
		saved_mana = GameEconomy.battle_state["heroes_mana"]
	
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
	
	is_player_turn = false
	board_manager.is_processing_move = true 
	await get_tree().create_timer(0.5).timeout
	
	if is_instance_valid(enemy):
		enemy.attack_player()
	else:
		start_player_turn()
		
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
	
	if player_current_hp <= 0:
		GameEconomy.clear_battle_state() 
		game_over(false)

func game_over(is_victory: bool) -> void:
	if not game_over_scene: return
	Audio.stop_music()
	if is_victory: Audio.play_sfx("victory")
	else: Audio.play_sfx("gameover")
	
	GameEconomy.check_new_high_score(current_score)
	GameEconomy.clear_battle_state()
	
	var popup = game_over_scene.instantiate()
	ui_layer.add_child(popup)
	if popup.has_method("show_result"):
		popup.show_result(is_victory, current_score)
	if popup.has_signal("restart_requested"):
		popup.restart_requested.connect(_on_restart_game)

func _on_restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
		
func update_player_ui() -> void:
	if player_max_hp > 0:
		player_hp_bar.value = (float(player_current_hp) / player_max_hp) * 100
	player_hp_text.text = str(player_current_hp) + " / " + str(player_max_hp)

func _on_player_damage_dealt(amount: int, type: String, match_count: int, combo_count: int) -> void:
	if is_level_transitioning: return
	if not is_instance_valid(enemy): return
	
	var team_level = GameEconomy.get_team_total_level()
	var base_multiplier = 1.0 + (team_level * 0.1) 
	var elemental_multiplier = 1.0
	
	if enemy.get("element_type"):
		var enemy_type = enemy.element_type
		if (type == "red" and enemy_type == "green") or \
		   (type == "green" and enemy_type == "blue") or \
		   (type == "blue" and enemy_type == "red") or \
		   (type == "yellow" and enemy_type == "purple") or \
		   (type == "purple" and enemy_type == "yellow"):
			elemental_multiplier = 2.0
		elif (type == enemy_type) or \
			 (type == "red" and enemy_type == "blue") or \
			 (type == "green" and enemy_type == "red") or \
			 (type == "blue" and enemy_type == "green"):
			elemental_multiplier = 0.5
			
	var size_multiplier = 1.0
	if match_count == 4: size_multiplier = 1.5
	elif match_count >= 5: size_multiplier = 2.0
		
	var combo_multiplier = 1.0
	if combo_count > 0: combo_multiplier = 1.0 + (combo_count * 0.1)
		
	var final_damage = int(amount * base_multiplier * elemental_multiplier * size_multiplier * combo_multiplier)
	
	if buff_remaining_turns > 0:
		final_damage = int(final_damage * 1.5)
		buff_remaining_turns -= 1

	enemy.take_damage(final_damage, type)
	distribute_mana(type, match_count)
	
	var text_content = str(final_damage)
	spawn_status_text(text_content, Color.WHITE, enemy.global_position)
	
	current_score += final_damage
	Audio.play_sfx("playerAttack")
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

func spawn_status_text(text: String, color: Color, location: Vector2, text_scale: float = 1.0) -> void:
	if not floating_text_scene: return
	var ft = floating_text_scene.instantiate()
	add_child(ft)
	ft.global_position = location + Vector2(0, -50)
	ft.scale = Vector2(text_scale, text_scale)
	if ft.has_method("start_animation"):
		ft.start_animation(text, color)
		
func _on_mana_gained(amount: int, color_type: String) -> void:
	pass

func _on_hero_skill_activated(hero_data: CharacterData) -> void:
	if is_level_transitioning: return
	if not is_instance_valid(enemy): return
	
	Audio.play_sfx("combo", 0.5)
	var type = hero_data.skill_type
	var level = GameEconomy.get_hero_level(hero_data.id)
	var final_power = int(hero_data.skill_power * (1.0 + ((level - 1) * 0.2)))
	
	match type:
		CharacterData.SkillType.DIRECT_DAMAGE:
			enemy.take_damage(final_power, "magic")
			spawn_status_text("SKILL!", Color.RED, enemy.global_position)
		CharacterData.SkillType.HEAL:
			heal_player(final_power)
			spawn_status_text("HEAL +%d" % final_power, Color.GREEN, ui_layer.offset + Vector2(200, 400))
		CharacterData.SkillType.BUFF_ATTACK:
			buff_remaining_turns = 3
			spawn_status_text("RAGE MODE!", Color.YELLOW, ui_layer.offset + Vector2(200, 400))

func _on_enemy_died() -> void:
	is_level_transitioning = true
	Audio.play_sfx("victory") 
	
	var is_boss_level = (current_level % 5 == 0)
	var gold_reward = 100 * current_level
	if is_boss_level: gold_reward = 500
	
	heal_player(int(player_max_hp * 0.2))
	gold_earned_this_session += gold_reward
	GameEconomy.add_gold(gold_reward) 
	
	current_level += 1
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
	
	if current_level % 5 == 0:
		new_enemy.max_hp *= 3
		current_enemy_damage = int(current_enemy_damage * 1.5)
		new_enemy.current_hp = new_enemy.max_hp
		new_enemy.update_ui()
		new_enemy.scale = Vector2(1.5, 1.5)
	
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
	var multiplier = 1.0 + ((current_level - 1) * 0.2)
	target_enemy.max_hp = int(base_enemy_hp * multiplier)
	current_enemy_damage = int(base_enemy_damage * multiplier)
	target_enemy.current_hp = target_enemy.max_hp
	target_enemy.update_ui()

func heal_player(amount: int) -> void:
	player_current_hp = min(player_current_hp + amount, player_max_hp)
	update_player_ui()

# --- STATE SAVING & LOADING ---

func _save_current_battle_state() -> void:
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
		"player_hp": player_current_hp,
		"score": current_score,
		"enemy_hp": enemy_hp,
		"enemy_element": enemy_elem,
		"board": board_manager.get_board_data(),
		"heroes_mana": heroes_mana
	}
	GameEconomy.save_battle_state(data)

func _load_battle_state() -> void:
	var data = GameEconomy.battle_state
	current_level = data.get("level", 1)
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
	
	if current_level % 5 == 0:
		new_enemy.scale = Vector2(1.5, 1.5)
		
	enemy = new_enemy
	enemy.attack_finished.connect(_on_enemy_attack_finished)
	enemy.died.connect(_on_enemy_died)
	
	board_manager.load_board_data(board_data)
	start_player_turn()
