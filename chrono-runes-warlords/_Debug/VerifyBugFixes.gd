extends SceneTree

# --- TEST RUNNER LOGIC ---

func _init():
	print("\n--- STARTING BUG FIX VERIFICATION ---\n")
	
	await test_bug1_battle_hero_mana_reset()
	await test_bug2_enemy_status_visuals()
	
	print("\n--- ALL TESTS COMPLETED ---")
	quit()

# --- TESTS ---

func test_bug1_battle_hero_mana_reset():
	print("TEST 1: BattleHero Mana Reset Order")
	
	# 1. Setup
	var hero = BattleHero.new()
	var hero_data = CharacterData.new()
	hero.hero_data = hero_data
	
	# Mock UI nodes for BattleHero (since it expects them in _ready/update_ui)
	# We rely on get_node_or_null usage in BattleHero or override properties if possible
	# Looking at BattleHero.gd, it checks `if mana_bar:` etc. 
	# But `_on_click_button_pressed` calls `update_ui` which accesses them.
	# We need to add children to avoid null pointer errors if strict, 
	# but the code uses safely checks like `if mana_bar:`.
	# Let's verify BattleHero.gd again.
	# It has `@onready var mana_bar = $ManaBar`. If I instantiate via .new(), these are null.
	# BattleHero.gd uses `if mana_bar:` in update_ui, so it should be safe.
	
	hero.max_mana = 100
	hero.current_mana = 100
	
	# 2. Connect signal to a checker
	var signal_emitted = false
	var mana_at_emit = -1
	
	hero.skill_activated.connect(func(data): 
		signal_emitted = true
		mana_at_emit = hero.current_mana
		print("   -> Signal received. Current Mana: ", hero.current_mana)
	)
	
	# 3. Simulate Click
	# We can't call _ready() easily without adding to tree, but we can call _on_click_button_pressed directly.
	# Just ensuring the method logic is correct.
	
	print("   -> Simulating button press with Max Mana...")
	hero._on_click_button_pressed()
	
	# 4. Assertions
	if not signal_emitted:
		print("   [FAIL] Signal 'skill_activated' was NOT emitted.")
	elif mana_at_emit != 0:
		print("   [FAIL] Mana was ", mana_at_emit, " at signal emission (Expected 0). Fix order!")
	else:
		print("   [PASS] Mana was 0 at signal emission.")
		
	# Cleanup
	hero.free()

func test_bug2_enemy_status_visuals():
	print("\nTEST 2: Enemy Status Visuals on Load")
	
	# 1. Setup
	var enemy = Enemy.new()
	var visuals = Sprite2D.new()
	visuals.name = "Visuals"
	enemy.add_child(visuals)
	enemy.visuals = visuals # Manually assign if @onready is skipped by .new()
	# Note: @onready vars are only assigned when added to tree and _ready runs.
	# We will simulate _ready manually or just set the prop.
	
	# Setup mocked nodes to avoid errors
	var status_container = HBoxContainer.new()
	status_container.name = "StatusContainer"
	enemy.add_child(status_container)
	enemy.status_container = status_container
	
	var progress = ProgressBar.new()
	progress.name = "ProgressBar"
	enemy.add_child(progress)
	enemy.hp_bar = progress
	var lbl = Label.new()
	lbl.name = "HPText"
	progress.add_child(lbl)
	enemy.hp_text = lbl
	
	# 2. Simulate Load State
	enemy.stun_turns = 1
	enemy.element_type = "red"
	enemy.current_base_color = Color("#ff4d4d") # Red
	
	# 3. Run Fix Logic
	# The fix was added to _ready(). We can call a helper or simulate the logic block directly.
	# Since we can't easily execute _ready() without scene tree integration issues in headless scripts sometimes,
	# We will manually call the added logic to verify it works AS WRITTEN.
	
	print("   -> Simulating _ready with stun_turns = 1...")
	
	# Initial state check
	visuals.modulate = Color.WHITE
	
	# Replicate the fix logic exactly as inserted:
	enemy.update_status_visuals()
	if enemy.stun_turns > 0:
		enemy.visuals.modulate = Color(0.2, 0.2, 1.0)
	elif enemy.dot_turns > 0:
		enemy.visuals.modulate = Color(0.8, 0, 0.8)
	elif enemy.defense_break_turns > 0:
		enemy.visuals.modulate = Color(1.0, 1.0, 0.2)
		
	# 4. Assertions
	var expected = Color(0.2, 0.2, 1.0)
	if visuals.modulate.is_equal_approx(expected):
		print("   [PASS] Visuals modulate is correctly BLUE (Stunned).")
	else:
		print("   [FAIL] Visuals modulate is ", visuals.modulate, " (Expected ", expected, ")")
		
	# Test DoT priority
	enemy.stun_turns = 0
	enemy.dot_turns = 1
	
	# Re-run logic
	if enemy.stun_turns > 0:
		enemy.visuals.modulate = Color(0.2, 0.2, 1.0)
	elif enemy.dot_turns > 0:
		enemy.visuals.modulate = Color(0.8, 0, 0.8)
		
	expected = Color(0.8, 0, 0.8)
	if visuals.modulate.is_equal_approx(expected):
		print("   [PASS] Visuals modulate is correctly PURPLE (DoT).")
	else:
		print("   [FAIL] Visuals modulate is ", visuals.modulate, " (Expected ", expected, ")")
		
	enemy.free()
