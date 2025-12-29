extends SceneTree

# Test suite for Priority 1 fixes
# Run with: godot --headless --script _Debug/TestPriority1Fixes.gd

var test_results = []
var tests_passed = 0
var tests_failed = 0

func _init():
	print("\n╔════════════════════════════════════════════════════════════╗")
	print("║         PRIORITY 1 FIXES - AUTOMATED TEST SUITE           ║")
	print("╚════════════════════════════════════════════════════════════╝\n")

	run_all_tests()

	print("\n" + "═" * 60)
	print("TEST SUMMARY")
	print("═" * 60)
	print("✓ PASSED: %d" % tests_passed)
	print("✗ FAILED: %d" % tests_failed)
	print("  TOTAL:  %d" % (tests_passed + tests_failed))

	if tests_failed == 0:
		print("\n🎉 ALL TESTS PASSED! Priority 1 fixes verified.")
	else:
		print("\n⚠️  SOME TESTS FAILED - Review failures above")

	print("═" * 60 + "\n")

	quit()

func run_all_tests():
	test_1_mana_gained_implemented()
	test_2_no_double_mana_distribution()
	test_3_skill_sfx_and_vibration()
	test_4_buff_consolidation()
	test_5_visual_feedback_exists()

# ============================================================================
# TEST 1: Verify _on_mana_gained is properly implemented
# ============================================================================
func test_1_mana_gained_implemented():
	print("\n[TEST 1] Verify _on_mana_gained Implementation")
	print("─" * 60)

	var file = FileAccess.open("res://00_Game/Scripts/MainGame.gd", FileAccess.READ)
	if not file:
		log_fail("TEST 1", "Could not open MainGame.gd")
		return

	var content = file.get_as_text()
	file.close()

	# Find the function
	var func_start = content.find("func _on_mana_gained")
	if func_start == -1:
		log_fail("TEST 1", "_on_mana_gained function not found")
		return

	var next_func = content.find("\nfunc ", func_start + 1)
	var func_body = content.substr(func_start, next_func - func_start)

	# Check for required components
	var checks = {
		"heroes_container check": func_body.contains("heroes_container"),
		"hero loop": func_body.contains("for h in"),
		"element matching": func_body.contains("_get_element_color") and func_body.contains("hero_color"),
		"add_mana call": func_body.contains("add_mana(amt)"),
		"visual feedback": func_body.contains("spawn_status_text") and func_body.contains("MP"),
		"pulse effect": func_body.contains("tween") and func_body.contains("modulate"),
		"not empty": not func_body.strip_edges().ends_with("pass")
	}

	var all_passed = true
	for check_name in checks:
		if checks[check_name]:
			print("  ✓ %s" % check_name)
		else:
			print("  ✗ %s MISSING" % check_name)
			all_passed = false

	if all_passed:
		log_pass("TEST 1", "_on_mana_gained fully implemented with all features")
	else:
		log_fail("TEST 1", "Some components missing from _on_mana_gained")

# ============================================================================
# TEST 2: Verify no double mana distribution
# ============================================================================
func test_2_no_double_mana_distribution():
	print("\n[TEST 2] Verify No Double Mana Distribution")
	print("─" * 60)

	var file = FileAccess.open("res://00_Game/Scripts/MainGame.gd", FileAccess.READ)
	if not file:
		log_fail("TEST 2", "Could not open MainGame.gd")
		return

	var content = file.get_as_text()
	file.close()

	# Find _on_player_damage_dealt function
	var func_start = content.find("func _on_player_damage_dealt")
	if func_start == -1:
		log_fail("TEST 2", "_on_player_damage_dealt not found")
		return

	var next_func = content.find("\nfunc ", func_start + 1)
	var func_body = content.substr(func_start, next_func - func_start)

	# Check that distribute_mana is NOT called in this function
	var has_distribute_call = func_body.contains("distribute_mana(")

	if has_distribute_call:
		log_fail("TEST 2", "CRITICAL: distribute_mana() still called in _on_player_damage_dealt - DOUBLE MANA BUG EXISTS!")
	else:
		print("  ✓ No distribute_mana() call found")

		# Verify comment explaining the change
		var has_explanation = func_body.contains("signal") or func_body.contains("BoardManager")
		if has_explanation:
			print("  ✓ Explanatory comment present")
			log_pass("TEST 2", "Double mana distribution bug fixed")
		else:
			print("  ⚠ Comment explaining change not found (minor)")
			log_pass("TEST 2", "Double mana distribution bug fixed (but add comment)")

# ============================================================================
# TEST 3: Verify skill SFX and vibration
# ============================================================================
func test_3_skill_sfx_and_vibration():
	print("\n[TEST 3] Verify Skill Activation SFX & Vibration")
	print("─" * 60)

	var file = FileAccess.open("res://00_Game/Scripts/MainGame.gd", FileAccess.READ)
	if not file:
		log_fail("TEST 3", "Could not open MainGame.gd")
		return

	var content = file.get_as_text()
	file.close()

	# Find _on_hero_skill_activated
	var func_start = content.find("func _on_hero_skill_activated")
	if func_start == -1:
		log_fail("TEST 3", "_on_hero_skill_activated not found")
		return

	var next_func = content.find("\nfunc ", func_start + 1)
	var func_body = content.substr(func_start, next_func - func_start)

	# Check for correct SFX
	var has_upgrade_sfx = func_body.contains('play_sfx("upgrade")')
	var has_wrong_sfx = func_body.contains('play_sfx("combo"')

	# Check for vibration
	var has_heavy_vibration = func_body.contains("vibrate_heavy()")

	if has_upgrade_sfx and not has_wrong_sfx:
		print("  ✓ Correct SFX: 'upgrade'")
	elif has_wrong_sfx:
		print("  ✗ Wrong SFX: still using 'combo'")
	else:
		print("  ✗ No SFX call found")

	if has_heavy_vibration:
		print("  ✓ Heavy vibration feedback present")
	else:
		print("  ✗ Heavy vibration missing")

	if has_upgrade_sfx and not has_wrong_sfx and has_heavy_vibration:
		log_pass("TEST 3", "Skill activation audio and haptics correct")
	else:
		log_fail("TEST 3", "Skill activation audio or haptics incorrect")

# ============================================================================
# TEST 4: Verify buff consolidation
# ============================================================================
func test_4_buff_consolidation():
	print("\n[TEST 4] Verify Buff Management Consolidation")
	print("─" * 60)

	var file = FileAccess.open("res://00_Game/Scripts/MainGame.gd", FileAccess.READ)
	if not file:
		log_fail("TEST 4", "Could not open MainGame.gd")
		return

	var content = file.get_as_text()
	file.close()

	var issues = []

	# Check 1: No local buff variables in MainGame
	if content.contains("var active_buff_multiplier"):
		issues.append("Still has 'var active_buff_multiplier' declaration")
		print("  ✗ Local buff_multiplier variable still exists")
	else:
		print("  ✓ Local buff_multiplier variable removed")

	if content.contains("var buff_remaining_turns"):
		issues.append("Still has 'var buff_remaining_turns' declaration")
		print("  ✗ Local buff_remaining_turns variable still exists")
	else:
		print("  ✓ Local buff_remaining_turns variable removed")

	# Check 2: Uses TurnManager for buff multiplier
	var uses_turn_manager = content.contains("turn_manager.get_buff_multiplier()")
	if uses_turn_manager:
		print("  ✓ Uses turn_manager.get_buff_multiplier()")
	else:
		issues.append("Doesn't use turn_manager.get_buff_multiplier()")
		print("  ✗ Doesn't use turn_manager.get_buff_multiplier()")

	# Check 3: BUFF_ATTACK uses turn_manager.apply_buff()
	var uses_apply_buff = content.contains("turn_manager.apply_buff(")
	if uses_apply_buff:
		print("  ✓ Uses turn_manager.apply_buff() for BUFF_ATTACK")
	else:
		issues.append("BUFF_ATTACK doesn't use turn_manager.apply_buff()")
		print("  ✗ BUFF_ATTACK doesn't use turn_manager.apply_buff()")

	if issues.is_empty():
		log_pass("TEST 4", "Buff management fully consolidated to TurnManager")
	else:
		log_fail("TEST 4", "Buff consolidation incomplete: " + ", ".join(issues))

# ============================================================================
# TEST 5: Verify visual feedback exists
# ============================================================================
func test_5_visual_feedback_exists():
	print("\n[TEST 5] Verify Visual Feedback Components")
	print("─" * 60)

	var file = FileAccess.open("res://00_Game/Scripts/MainGame.gd", FileAccess.READ)
	if not file:
		log_fail("TEST 5", "Could not open MainGame.gd")
		return

	var content = file.get_as_text()
	file.close()

	# Find _on_mana_gained
	var func_start = content.find("func _on_mana_gained")
	var next_func = content.find("\nfunc ", func_start + 1)
	var func_body = content.substr(func_start, next_func - func_start)

	var checks = []

	# Check for cyan color
	if func_body.contains("Color.CYAN") or func_body.contains("Color(0") and func_body.contains("1, 1"):
		print("  ✓ Cyan color for mana text")
		checks.append(true)
	else:
		print("  ✗ Cyan color not found")
		checks.append(false)

	# Check for MP text
	if func_body.contains("MP"):
		print("  ✓ 'MP' text in feedback")
		checks.append(true)
	else:
		print("  ✗ 'MP' text missing")
		checks.append(false)

	# Check for tween/pulse effect
	if func_body.contains("create_tween()"):
		print("  ✓ Tween animation created")
		checks.append(true)
	else:
		print("  ✗ Tween animation missing")
		checks.append(false)

	# Check for modulate color change (blue flash)
	if func_body.contains("modulate") and func_body.contains("1.3") or func_body.contains("1.8"):
		print("  ✓ Blue flash effect (modulate)")
		checks.append(true)
	else:
		print("  ✗ Blue flash effect missing")
		checks.append(false)

	if checks.count(true) == checks.size():
		log_pass("TEST 5", "All visual feedback components present")
	elif checks.count(true) >= 2:
		log_pass("TEST 5", "Most visual feedback present (%d/%d)" % [checks.count(true), checks.size()])
	else:
		log_fail("TEST 5", "Visual feedback incomplete (%d/%d)" % [checks.count(true), checks.size()])

# ============================================================================
# Helper functions
# ============================================================================
func log_pass(test_name: String, message: String):
	print("\n  ✅ PASS: %s" % message)
	test_results.append({"test": test_name, "passed": true, "message": message})
	tests_passed += 1

func log_fail(test_name: String, message: String):
	print("\n  ❌ FAIL: %s" % message)
	test_results.append({"test": test_name, "passed": false, "message": message})
	tests_failed += 1
