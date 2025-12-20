extends Node2D

# --- NODES (MATCHING SCENE HIERARCHY) ---
@onready var board_manager: BoardManager = $BoardManager
@onready var heroes_container: HBoxContainer = $HeroesContainer
@onready var ui_layer: CanvasLayer = $UILayer
@onready var camera: Camera2D = $Camera2D

# CORRECT PATHS VERIFIED IN SCENE
@onready var wave_label: Label = $WaveLabel
@onready var player_hp_bar: ProgressBar = $UILayer/PlayerHPBar
@onready var player_hp_text: Label = $UILayer/PlayerHPBar/PlayerHPText
@onready var mana_bar: TextureProgressBar = $UILayer/ManaBar

# --- SCENE PATHS (FLAT FOLDER) ---
var victory_scene_path: String = "res://00_Game/Scenes/VictoryScreen.tscn"
var pause_menu_path: String = "res://00_Game/Scenes/PauseMenu.tscn"
var game_over_scene_path: String = "res://00_Game/Scenes/GameOverUI.tscn" 
var floating_text_scene_path: String = "res://00_Game/Scenes/FloatingText.tscn"
var battle_hero_scene_path: String = "res://00_Game/Scenes/BattleHero.tscn"
var enemy_scene_path: String = "res://00_Game/Scenes/Enemy.tscn"

# --- VARIABLES ---
var current_level: int = 1
var current_wave: int = 1
const MAX_WAVES: int = 3

var player_max_hp: int = 1000
var player_current_hp: int = 1000
var current_score: int = 0
var gold_earned_this_session: int = 0

var current_enemy_damage: int = 0
var active_buff_multiplier: float = 1.0
var buff_remaining_turns: int = 0

var is_player_turn: bool = true
var is_level_transitioning: bool = false
var enemy: Node = null
var leader_data = null

# --- INITIALIZATION ---
func _ready() -> void:
	if Audio.bg_music:
		Audio.play_music(Audio.bg_music)
		
	# Sync Level
	current_level = GameEconomy.current_map_level
	
	# Connect Board Signals
	if board_manager:
		board_manager.damage_dealt.connect(_on_player_damage_dealt)
		board_manager.turn_finished.connect(_on_board_settled) 
		board_manager.mana_gained.connect(_on_mana_gained)
		
	# Setup Stats
	var team_level = GameEconomy.get_team_total_level()
	player_max_hp = 1000 + (team_level * 50)
	
	# Handle Initial Enemy in Scene (if any)
	var initial_enemy = get_node_or_null("Enemy")
	if initial_enemy:
		initial_enemy.queue_free() # We spawn dynamically
	
	# Resume or Start Fresh
	if GameEconomy.has_active_battle():
		print(">>> RESUMING SAVED BATTLE STATE...")
		_load_battle_state()
	else:
		print(">>> STARTING FRESH BATTLE...")
		player_current_hp = player_max_hp
		current_wave = 1
		spawn_next_enemy()
		if board_manager: board_manager.spawn_board()
		
	update_player_ui()
	update_wave_ui()
	_setup_battle_heroes()
	
	# Get Leader
	var leader_id = GameEconomy.get_team_leader_id()
	if leader_id != "":
		leader_data = GameEconomy.get_character_data(leader_id)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not get_tree().paused:
			show_pause_menu()

# --- WAVE & ENEMY LOGIC ---

func spawn_next_enemy() -> void:
	buff_remaining_turns = 0
	if is_instance_valid(enemy): enemy.queue_free()
	
	var scene = load(enemy_scene_path)
	if not scene:
		print("ERROR: Could not load Enemy scene at ", enemy_scene_path)
		return
		
	var new_enemy = scene.instantiate()
	add_child(new_enemy)
	new_enemy.position = Vector2(360, 250)
	
	calculate_and_apply_enemy_stats(new_enemy)
	
	# Random Element
	var types = ["red", "blue", "green", "yellow", "purple"]
	var random_type = types.pick_random()
	if new_enemy.has_method("setup_element"):
		new_enemy.setup_element(random_type)
	
	# Force UI Update
	if new_enemy.has_method("update_ui"):
		new_enemy.update_ui()
		
	enemy = new_enemy
	
	# Connect Signals
	if enemy.has_signal("attack_finished"):
		enemy.attack_finished.connect(_on_enemy_attack_finished)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
	
	if board_manager:
		board_manager.is_processing_move = false
		
	start_player_turn()
	is_level_transitioning = false
	
	_save_current_battle_state()

func _on_enemy_died() -> void:
	is_level_transitioning = true
	Audio.play_sfx("victory")
	
	# Rewards
	var gold_reward = 100 * current_level
	heal_player(int(player_max_hp * 0.2))
	gold_earned_this_session += gold_reward
	GameEconomy.add_gold(gold_reward)
	
	# WAVE CHECK
	if current_wave < MAX_WAVES:
		current_wave += 1
		var center = get_viewport_rect().get_center()
		spawn_status_text("WAVE CLEARED!", Color.GREEN, center)
		update_wave_ui()
		
		# Save Progress
		_save_current_battle_state()
		
		if board_manager: board_manager.is_processing_move = true
		await get_tree().create_timer(1.0).timeout
		
		spawn_next_enemy()
	else:
		# LEVEL CLEARED
		GameEconomy.complete_current_level()
		GameEconomy.save_game()
		
		# Clear Battle State
		GameEconomy.clear_battle_snapshot()
		
		show_victory_screen()

func show_victory_screen() -> void:
	await get_tree().create_timer(1.0).timeout
	
	var scene = load(victory_scene_path)
	if scene:
		var inst = scene.instantiate()
		ui_layer.add_child(inst)
		
		var claim_btn = inst.find_child("ClaimButton", true, false)
		if claim_btn:
			claim_btn.pressed.connect(_on_victory_claim_pressed)
			
	if board_manager: board_manager.is_processing_move = true

func _on_victory_claim_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func calculate_and_apply_enemy_stats(enemy_node: Node) -> void:
	var base_hp = 500 + (current_level * 50) + (current_wave * 100)
	var dmg = 40 + (current_level * 5)
	
	# Boss Wave?
	if current_level % 5 == 0 and current_wave == MAX_WAVES:
		base_hp *= 2
		dmg *= 1.5
		enemy_node.scale = Vector2(1.5, 1.5)
	
	if "max_hp" in enemy_node: enemy_node.max_hp = base_hp
	if "current_hp" in enemy_node: enemy_node.current_hp = base_hp
	current_enemy_damage = int(dmg)

# --- TURN & COMBAT LOGIC ---

func _on_board_settled() -> void:
	_save_current_battle_state()
	GameEconomy.save_game()
	print("Auto-saved after turn.")
	
	is_player_turn = false
	if board_manager: board_manager.is_processing_move = true
	
	await get_tree().create_timer(0.5).timeout
	
	if is_instance_valid(enemy):
		_start_enemy_turn()
	else:
		start_player_turn()

func _start_enemy_turn() -> void:
	if not is_instance_valid(enemy):
		start_player_turn()
		return
		
	# Process Status
	var is_stunned = false
	if enemy.has_method("process_turn_start"):
		is_stunned = enemy.process_turn_start()
		
	if is_stunned:
		spawn_status_text("ENEMY STUNNED!", Color.BLUE, enemy.global_position + Vector2(0, -100))
		await get_tree().create_timer(1.0).timeout
		start_player_turn()
	else:
		if enemy.has_method("attack_player"):
			enemy.attack_player()
		else:
			_on_enemy_attack_finished()

func _on_enemy_attack_finished() -> void:
	take_player_damage(current_enemy_damage)
	start_player_turn()
	_save_current_battle_state()

func start_player_turn() -> void:
	is_player_turn = true
	if board_manager: board_manager.is_processing_move = false

func take_player_damage(amount: int) -> void:
	player_current_hp -= amount
	update_player_ui()
	shake_screen(5.0, 0.3)
	
	if player_current_hp <= 0:
		GameEconomy.clear_battle_snapshot()
		game_over(false)

func game_over(is_victory: bool) -> void:
	if Audio.bg_music: Audio.stop_music()
	if is_victory: Audio.play_sfx("victory")
	else: Audio.play_sfx("gameover")
	
	if not is_victory:
		GameEconomy.clear_battle_snapshot()
		GameEconomy.save_game()
		
	var scene = load(game_over_scene_path)
	if scene:
		var popup = scene.instantiate()
		ui_layer.add_child(popup)
		if popup.has_method("show_result"):
			popup.show_result(is_victory, current_score)
		if popup.has_signal("restart_requested"):
			popup.restart_requested.connect(_on_restart_game)

func _on_restart_game() -> void:
	GameEconomy.clear_battle_snapshot()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_player_damage_dealt(amount: int, type: String, match_count: int, combo_count: int) -> void:
	if is_level_transitioning: return
	if not is_instance_valid(enemy): return
	
	var hero_attack = GameEconomy.get_hero_attack(type)
	var enemy_elem = enemy.element_type if "element_type" in enemy else ""
	
	var final_damage = CombatMath.calculate_damage(
		amount, type, enemy_elem, match_count, combo_count, hero_attack, active_buff_multiplier
	)
	
	if buff_remaining_turns > 0:
		buff_remaining_turns -= 1
		if buff_remaining_turns <= 0: active_buff_multiplier = 1.0
		
	if enemy.has_method("take_damage"):
		enemy.take_damage(final_damage, type)
		
	distribute_mana(type, match_count)
	
	# Visuals
	var elem_mult = CombatMath.get_elemental_multiplier(type, enemy_elem)
	var is_crit = elem_mult > 1.0
	var is_resist = elem_mult < 1.0
	var color = CombatMath.get_damage_color(type, is_crit, is_resist)
	var text = str(final_damage)
	if is_crit: text = "CRIT " + text
	
	spawn_status_text(text, color, enemy.global_position)
	current_score += final_damage
	
	await get_tree().create_timer(0.2).timeout
	Audio.play_sfx("enemyHit")

func _on_hero_skill_activated(hero_data: CharacterData) -> void:
	if is_level_transitioning or not is_instance_valid(enemy): return
	
	Audio.play_sfx("combo", 0.5)
	var final_power = GameEconomy.get_hero_skill_power(hero_data.id)
	var elem_mult = 1.0
	if "element_type" in enemy:
		elem_mult = CombatMath.get_elemental_multiplier(
			_get_element_color(hero_data.element_text), enemy.element_type
		)
		
	match hero_data.skill_type:
		CharacterData.SkillType.DIRECT_DAMAGE:
			final_power = int(final_power * active_buff_multiplier * elem_mult)
			enemy.take_damage(final_power, "magic")
			spawn_status_text("SKILL %d" % final_power, Color.RED, enemy.global_position)
			
		CharacterData.SkillType.HEAL:
			heal_player(250)
			
		CharacterData.SkillType.BUFF_ATTACK:
			active_buff_multiplier = 1.5
			buff_remaining_turns = 3
			spawn_status_text("BUFF UP!", Color.GOLD, player_hp_bar.global_position)
			
		CharacterData.SkillType.STUN:
			enemy.apply_status("stun", 2)
			spawn_status_text("STUN!", Color.BLUE, enemy.global_position)
			
		CharacterData.SkillType.DOT:
			var dot = int(final_power * 0.5 * elem_mult)
			enemy.apply_status("dot", 3, dot)
			spawn_status_text("POISON!", Color.PURPLE, enemy.global_position)
			
		CharacterData.SkillType.DEFENSE_BREAK:
			enemy.apply_status("def_break", 3)
			spawn_status_text("BREAK!", Color.YELLOW, enemy.global_position)
	
	_save_current_battle_state()
	GameEconomy.save_game()

# --- UI & HELPERS ---

func update_player_ui() -> void:
	# Safe Access
	if player_hp_bar:
		player_hp_bar.value = (float(player_current_hp) / player_max_hp) * 100
	if player_hp_text:
		player_hp_text.text = "%d / %d" % [player_current_hp, player_max_hp]

func update_wave_ui() -> void:
	# Safe Access
	if wave_label:
		wave_label.text = "WAVE %d/%d" % [current_wave, MAX_WAVES]

func heal_player(amount: int) -> void:
	player_current_hp = min(player_current_hp + amount, player_max_hp)
	update_player_ui()
	# Optional: spawn text relative to UI
	if player_hp_bar:
		spawn_status_text("+%d HP" % amount, Color.GREEN, player_hp_bar.global_position)

func spawn_status_text(text: String, color: Color, pos: Vector2) -> void:
	var scene = load(floating_text_scene_path)
	if not scene: return
	
	var ft = scene.instantiate()
	add_child(ft)
	var jitter = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	ft.global_position = pos + jitter
	
	if ft.has_method("start_animation"):
		ft.start_animation(text, color)

func show_pause_menu() -> void:
	var scene = load(pause_menu_path)
	if not scene: return
	
	var layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	
	var menu = scene.instantiate()
	layer.add_child(menu)
	if menu.has_signal("quit_requested"):
		menu.quit_requested.connect(_on_pause_quit)
	get_tree().paused = true

func _on_pause_quit() -> void:
	_save_current_battle_state()
	GameEconomy.save_game()
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainMenu.tscn")

func distribute_mana(type: String, count: int) -> void:
	if not heroes_container: return
	for h in heroes_container.get_children():
		if h.hero_data and _get_element_color(h.hero_data.element_text) == type:
			if h.has_method("add_mana"):
				h.add_mana(count * 15)

func _setup_battle_heroes() -> void:
	if not heroes_container: return
	for c in heroes_container.get_children(): c.queue_free()
	
	var team = GameEconomy.selected_team_ids
	var leader = GameEconomy.get_team_leader_id()
	var saved_mana = {}
	if GameEconomy.has_active_battle() and "heroes_mana" in GameEconomy.active_battle_snapshot:
		saved_mana = GameEconomy.active_battle_snapshot["heroes_mana"]
		
	var scene = load(battle_hero_scene_path)
	if not scene: return
	
	for hid in team:
		var data = GameEconomy.get_character_data(hid)
		if data:
			var inst = scene.instantiate()
			heroes_container.add_child(inst)
			if inst.has_method("setup"):
				inst.setup(data, hid == leader)
			if hid in saved_mana:
				inst.current_mana = saved_mana[hid]
				if inst.has_method("update_ui"): inst.update_ui()
			if inst.has_signal("skill_activated"):
				inst.skill_activated.connect(_on_hero_skill_activated)

func _on_mana_gained(amt: int, type: String) -> void:
	pass

func shake_screen(intensity: float, duration: float) -> void:
	if not camera: return
	var tw = create_tween()
	var orig = camera.offset
	for i in range(10):
		var off = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tw.tween_property(camera, "offset", orig + off, duration / 10.0)
	tw.tween_property(camera, "offset", orig, 0.05)

func _get_element_color(text: String) -> String:
	match text.to_lower():
		"fire": return "red"
		"water": return "blue"
		"nature", "earth": return "green"
		"light": return "yellow"
		"dark": return "purple"
	return "red"

# --- PERSISTENCE ---

func _save_current_battle_state() -> void:
	if player_current_hp <= 0: return
	
	var ehp = 0
	var eelem = "red"
	if is_instance_valid(enemy):
		ehp = enemy.current_hp
		if "element_type" in enemy: eelem = enemy.element_type
		
		# Save Status
		GameEconomy.current_enemy_stun_turns = enemy.stun_turns
		GameEconomy.current_enemy_dot_turns = enemy.dot_turns
		GameEconomy.current_enemy_break_turns = enemy.defense_break_turns
	else:
		GameEconomy.current_enemy_stun_turns = 0
		GameEconomy.current_enemy_dot_turns = 0
		GameEconomy.current_enemy_break_turns = 0
		
	var manas = {}
	if heroes_container:
		for h in heroes_container.get_children():
			if h.hero_data: manas[h.hero_data.id] = h.current_mana
			
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

func _load_battle_state() -> void:
	var data = GameEconomy.get_battle_snapshot()
	current_level = data.get("level", 1)
	current_wave = data.get("wave", 1)
	player_current_hp = data.get("player_hp", player_max_hp)
	current_score = data.get("score", 0)
	
	var ehp = data.get("enemy_hp", 500)
	var eelem = data.get("enemy_element", "red")
	var bdata = data.get("board", [])
	
	spawn_next_enemy()
	
	if is_instance_valid(enemy):
		enemy.current_hp = ehp
		if enemy.has_method("setup_element"): enemy.setup_element(eelem)
		if enemy.has_method("update_ui"): enemy.update_ui()
		
		# Restore Status
		enemy.stun_turns = GameEconomy.current_enemy_stun_turns
		enemy.dot_turns = GameEconomy.current_enemy_dot_turns
		enemy.defense_break_turns = GameEconomy.current_enemy_break_turns
		if enemy.has_method("update_status_visuals"):
			enemy.update_status_visuals()
			
		# ZOMBIE FIX: If loaded dead, kill immediately or skip
		if enemy.current_hp <= 0:
			print("Loaded DEAD enemy. Skipping or Killing...")
			_on_enemy_died() 
			
	if board_manager:
		board_manager.load_board_data(bdata)
	
	update_wave_ui()
	start_player_turn()
