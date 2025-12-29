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

# --- MANAGERS (Phase 2 Refactoring) ---
var turn_manager: TurnManager
var state_manager: BattleStateManager

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

var enemy_textures = [
	preload("res://01_Assets/Art/Enemies/enemy_goblin.png"),
	preload("res://01_Assets/Art/Enemies/enemy_orc.png"),
	preload("res://01_Assets/Art/Enemies/enemy_boss.png")
]

var player_max_hp: int = 1000
var player_current_hp: int = 1000
var current_score: int = 0
var gold_earned_this_session: int = 0

var current_enemy_damage: int = 0
# Buff state now managed by TurnManager, but kept for backward compatibility
var active_buff_multiplier: float = 1.0
var buff_remaining_turns: int = 0

var is_player_turn: bool = true
var is_level_transitioning: bool = false
var enemy: Node = null
var leader_data = null

# SAVE OPTIMIZATION: Throttle auto-saves (NOTE: Also in BattleStateManager for future use)
var turns_since_last_save: int = 0
const SAVE_INTERVAL: int = 3

# --- INITIALIZATION ---
func _ready() -> void:
	if wave_label: 
		wave_label.visible = false

	# Editor-based layout preferred
	if heroes_container:
		pass # Layout handled in Editor
		
	if player_hp_bar:
		pass

	if Audio.bg_music:
		Audio.play_music(Audio.bg_music)
		
	# Sync Level
	current_level = GameEconomy.current_map_level
	
	# --- MANAGERS SETUP (Phase 2) ---
	state_manager = BattleStateManager.new()
	state_manager.name = "BattleStateManager"
	add_child(state_manager)
	
	turn_manager = TurnManager.new()
	turn_manager.name = "TurnManager"
	add_child(turn_manager)
	
	# Connect manager signals
	turn_manager.player_turn_started.connect(_on_player_turn_started)
	turn_manager.request_save.connect(func(): _save_current_battle_state())
	state_manager.state_saved.connect(func(): print(">>> State saved via manager"))
	
	# Connect Board Signals
	if board_manager:
		board_manager.damage_dealt.connect(_on_player_damage_dealt)
		board_manager.turn_finished.connect(_on_board_settled) 
		board_manager.mana_gained.connect(_on_mana_gained)
		turn_manager.board_manager = board_manager
		state_manager.board_manager = board_manager
		
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
		# FIX: Load HP from Global Economy if valid
		if GameEconomy.player_global_hp > 0:
			player_current_hp = min(GameEconomy.player_global_hp, player_max_hp)
			print(">>> Restored Global HP: ", player_current_hp)
		else:
			player_current_hp = player_max_hp
			
		current_wave = 1
		spawn_next_enemy()
		if board_manager: board_manager.spawn_board()
		
	update_player_ui()
	show_wave_popup()
	_setup_battle_heroes()
	
	# Get Leader
	var leader_id = GameEconomy.get_team_leader_id()
	if leader_id != "":
		leader_data = GameEconomy.get_character_data(leader_id)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not get_tree().paused:
			show_pause_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		# FIX: Force save battle state on app close/pause
		_save_current_battle_state(true)
		print(">>> Forced Save on App Close/Pause")

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
	new_enemy.position = Vector2(360, 200)
	if new_enemy.has_method("update_home_position"):
		new_enemy.update_home_position()
	
	# 1. Texture & Visuals
	var tex_index = min(current_wave - 1, enemy_textures.size() - 1)
	var sprite = new_enemy.get_node_or_null("Visuals") 
	
	if sprite:
		sprite.texture = enemy_textures[tex_index]
		
	# 2. Scaling Polish
	if current_wave == 3: # Boss
		new_enemy.scale = Vector2(0.7, 0.7)
	else:
		new_enemy.scale = Vector2(0.5, 0.5)
	
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
	
	# NOTE: Save moved to _on_board_settled and after enemy turn
	# Removed early save here to prevent saving empty mana (heroes not spawned yet)

func _on_enemy_died() -> void:
	is_level_transitioning = true
	Audio.play_sfx("victory")
	
	# ANTI-FARMING: Reduce rewards for replays
	var base_gold = 100 * current_level
	var is_first_clear = GameEconomy.is_level_first_clear(current_level)
	var gold_multiplier = 1.0 if is_first_clear else 0.5
	var gold_reward = int(base_gold * gold_multiplier)
	
	heal_player(int(player_max_hp * 0.10))  # BALANCE: Reduced from 0.2 to make attrition meaningful
	gold_earned_this_session += gold_reward
	GameEconomy.add_gold(gold_reward)
	
	# WAVE CHECK
	if current_wave < MAX_WAVES:
		current_wave += 1
		var center = get_viewport_rect().get_center()
		
		# FIX: Show wave cleared text and wait before spawning enemy
		spawn_status_text("WAVE CLEARED!", Color.GREEN, center)
		
		# ANTI-FARMING: Show first clear bonus
		if is_first_clear:
			await get_tree().create_timer(0.5).timeout  # Wait for first text
			spawn_status_text("FIRST CLEAR BONUS!", Color.GOLD, center + Vector2(0, -60))
		
		await get_tree().create_timer(1.0).timeout  # Let player see the text
		show_wave_popup()
		
		spawn_next_enemy()
		# Save Progress AFTER spawning new enemy to avoid saving "Dead" state
		_save_current_battle_state()
	else:
		# LEVEL CLEARED
		GameEconomy.complete_level(current_level)
		# FIX: Save current HP for next level
		GameEconomy.player_global_hp = player_current_hp
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
	# Level increment already done in complete_current_level()
	# Just clear state and return to map
	
	# 1. Clear Saved Battle State
	GameEconomy.clear_battle_snapshot()
	current_wave = 1
	
	# 2. Return to Map
	get_tree().paused = false
	get_tree().change_scene_to_file("res://00_Game/Scenes/MapScene.tscn")

func calculate_and_apply_enemy_stats(enemy_node: Node) -> void:
	# BALANCE: Smoother scaling with sqrt for HP, slower damage growth
	var level_factor = sqrt(current_level) * 200.0
	var base_hp = 500 + int(level_factor) + (current_wave * 100)
	var dmg = 40 + (current_level * 4)  # Reduced from 5 to 4
	
	# Boss Wave? (Every 3 levels instead of 5, reduced multipliers)
	if current_level % 3 == 0 and current_wave == MAX_WAVES:
		base_hp = int(base_hp * 1.8)  # Reduced from 2.0
		dmg = int(dmg * 1.4)  # Reduced from 1.5
		# FIX: Don't make boss too large, use same scale as Wave 3
		# enemy_node.scale set in spawn_next_enemy() handles this
	
	if "max_hp" in enemy_node: enemy_node.max_hp = base_hp
	if "current_hp" in enemy_node: enemy_node.current_hp = base_hp
	current_enemy_damage = int(dmg)

# --- TURN & COMBAT LOGIC ---

func _on_board_settled() -> void:
	print(">>> _on_board_settled called! Previous turns: ", turns_since_last_save)
	turns_since_last_save += 1
	
	# SAVE OPTIMIZATION: Only save every N turns (throttle)
	if turns_since_last_save >= SAVE_INTERVAL:
		_save_current_battle_state()
		print(">>> Auto-saved after ", turns_since_last_save, " turns.")
		turns_since_last_save = 0
	else:
		print(">>> Turn ", turns_since_last_save, " of ", SAVE_INTERVAL, " (next save at ", SAVE_INTERVAL, ")")
	
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
	
	# SAVE OPTIMIZATION: Save after enemy turn (critical event)
	_save_current_battle_state()
	turns_since_last_save = 0  # Reset counter

func start_player_turn() -> void:
	is_player_turn = true
	
	# Sync with TurnManager
	if turn_manager:
		active_buff_multiplier = turn_manager.get_buff_multiplier()
	
	# Decrement buff duration at start of player turn (not per hit!)
	if buff_remaining_turns > 0:
		buff_remaining_turns -= 1
		if buff_remaining_turns <= 0: 
			active_buff_multiplier = 1.0
			spawn_status_text("Buff Ended", Color.GRAY, player_hp_bar.global_position + Vector2(0, -30))
	
	if board_manager: board_manager.is_processing_move = false

func _on_player_turn_started() -> void:
	# Called by TurnManager signal - sync state
	is_player_turn = true
	if board_manager: board_manager.is_processing_move = false

func take_player_damage(amount: int) -> void:
	player_current_hp -= amount
	update_player_ui()
	shake_screen(5.0, 0.3)
	Audio.vibrate_medium()  # HAPTIC: Feedback when taking damage	
	if player_current_hp <= 0:
		GameEconomy.clear_battle_snapshot()
		GameEconomy.player_global_hp = -1 # Reset global HP on death
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
	GameEconomy.player_global_hp = -1 # Reset HP for fresh run
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
	
	# NOTE: Buff decrement moved to start_player_turn to prevent multi-consumption in cascades
	
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
	
	# Match Count Text
	if match_count >= 5:
		spawn_status_text("AMAZING!", Color.MAGENTA, enemy.global_position + Vector2(0, -60), 2.0)
	elif match_count == 4:
		spawn_status_text("GREAT!", Color.CYAN, enemy.global_position + Vector2(0, -40), 1.5)
		
	# Combo Count Text (Only show for actual combos)
	if combo_count >= 2:
		spawn_status_text("COMBO x%d" % combo_count, Color.GOLD, enemy.global_position + Vector2(0, -80), 1.2)
	
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
			# FIX: Scale heal with hero level instead of hardcoded value
			heal_player(final_power)
			
		CharacterData.SkillType.BUFF_ATTACK:
			active_buff_multiplier = 1.5
			buff_remaining_turns = 4  # BALANCE: Increased from 3 to compensate for slower mana
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
	
	# SAVE OPTIMIZATION: Save after skill use (critical event)
	_save_current_battle_state()
	turns_since_last_save = 0  # Reset counter

# --- UI & HELPERS ---

func update_player_ui() -> void:
	# Safe Access
	if player_hp_bar:
		player_hp_bar.value = (float(player_current_hp) / player_max_hp) * 100
	if player_hp_text:
		player_hp_text.text = "%d / %d" % [player_current_hp, player_max_hp]

func show_wave_popup() -> void:
	# Safe Access
	if wave_label:
		wave_label.text = "WAVE %d/%d" % [current_wave, MAX_WAVES]
		wave_label.visible = true
		wave_label.modulate.a = 1.0 # Reset opacity
		
		var tween = create_tween()
		tween.tween_interval(2.0) # Stay visible for 2 seconds
		tween.tween_property(wave_label, "modulate:a", 0.0, 0.5) # Fade out over 0.5s
		tween.tween_callback(func(): wave_label.visible = false)

func heal_player(amount: int) -> void:
	player_current_hp = min(player_current_hp + amount, player_max_hp)
	update_player_ui()
	# Optional: spawn text relative to UI
	if player_hp_bar:
		spawn_status_text("+%d HP" % amount, Color.GREEN, player_hp_bar.global_position)

func spawn_status_text(text: String, color: Color, pos: Vector2, scale: float = 1.0) -> void:
	var scene = load(floating_text_scene_path)
	if not scene: return
	
	var ft = scene.instantiate()
	ft.scale = Vector2(scale, scale)
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
	# SAVE OPTIMIZATION: Always save when quitting (critical event)
	_save_current_battle_state(true)  # Force save
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://00_Game/Scenes/MainMenu.tscn")

func distribute_mana(type: String, count: int) -> void:
	if not heroes_container: return
	for h in heroes_container.get_children():
		if h.hero_data and _get_element_color(h.hero_data.element_text) == type:
			if h.has_method("add_mana"):
				h.add_mana(count * 10)  # BALANCE: Reduced from 15 to slow ultimate charge

func _setup_battle_heroes() -> void:
	if not heroes_container: return
	for c in heroes_container.get_children(): c.queue_free()
	
	var team = GameEconomy.selected_team_ids
	var leader = GameEconomy.get_team_leader_id()
	var saved_mana = {}
	
	# FIX: Always check for saved mana (from battle snapshot)
	if GameEconomy.has_active_battle() and "heroes_mana" in GameEconomy.active_battle_snapshot:
		saved_mana = GameEconomy.active_battle_snapshot["heroes_mana"]
		print(">>> Restoring mana: ", saved_mana)  # Debug output
		
	var scene = load(battle_hero_scene_path)
	if not scene: return
	
	for hid in team:
		var data = GameEconomy.get_character_data(hid)
		if data:
			var inst = scene.instantiate()
			heroes_container.add_child(inst)

			# Pass saved mana directly to setup to avoid reset
			# Use -1 as default to indicate no saved mana (will reset to 0 in setup)
			var initial_mana = saved_mana.get(hid, -1)
			if inst.has_method("setup"):
				inst.setup(data, hid == leader, initial_mana)

			if initial_mana > 0:
				print("  - Restored mana: ", hid, " -> ", initial_mana)

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

func _save_current_battle_state(force: bool = false) -> void:
	if player_current_hp <= 0: return
	
	# SAFETY: Don't save during level transitions unless forced
	if is_level_transitioning and not force: return
	
	var ehp = 0
	var eelem = "red"
	if is_instance_valid(enemy):
		ehp = max(0, enemy.current_hp)  # Ensure never negative
		
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
		# No valid enemy - might be transitioning, skip save
		print("⚠️ Skipping save: no valid enemy instance")
		return
		
	var manas = {}
	if heroes_container:
		print(">>> Heroes container has ", heroes_container.get_child_count(), " children")
		# FIX: Skip save if no heroes are spawned yet
		if heroes_container.get_child_count() == 0:
			print("⚠️ Skipping save: Heroes not spawned yet")
			return
			
		for h in heroes_container.get_children():
			print("  - Checking hero: ", h.name, " | has hero_data: ", h.hero_data != null, " | has current_mana: ", "current_mana" in h)
			if h.hero_data and "current_mana" in h:
				print("    -> Saving mana for ", h.hero_data.id, ": ", h.current_mana)
				manas[h.hero_data.id] = h.current_mana
			else:
				print("⚠️ Hero missing data/mana property: ", h.name)

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
			
		# Update color based on status
		if enemy.has_method("update_status_color"):
			enemy.update_status_color()
			
		# ZOMBIE FIX: If loaded dead, kill immediately or skip
		if enemy.current_hp <= 0:
			print("Loaded DEAD enemy. Skipping or Killing...")
			_on_enemy_died() 
			
	if board_manager:
		# FIX: If no board data saved, spawn fresh board
		if bdata.is_empty():
			board_manager.spawn_board()
		else:
			board_manager.load_board_data(bdata)
			# BUG FIX #1: Check for actual GamePiece children, not all children
			# (HintTimer is always a child, so get_child_count() is never 0)
			var piece_count = 0
			for child in board_manager.get_children():
				if child is GamePiece:
					piece_count += 1
			if piece_count == 0:
				print(">>> Board load failed (no pieces), spawning fresh...")
				board_manager.spawn_board()
	
	show_wave_popup()
	start_player_turn()
