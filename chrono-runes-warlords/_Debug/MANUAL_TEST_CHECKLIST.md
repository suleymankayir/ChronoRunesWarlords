# Priority 1 Fixes - Manual Testing Checklist

## Pre-Test Setup
- [ ] Build and run the game
- [ ] Start a new battle (or load existing battle)
- [ ] Note your team composition and hero elements

---

## TEST 1: Mana Gain Visual Feedback ⚡

### Test Steps:
1. [ ] Make a 3-gem match of a color that matches one of your heroes
   - Example: Match 3 red gems if you have Fire Warrior

### Expected Results:
- [ ] **Floating text appears** above the matching hero showing "+15 MP" (or similar) in **CYAN color**
- [ ] **Hero portrait flashes blue** briefly (modulate effect)
- [ ] **Mana bar increases** on the hero
- [ ] **Text position** is above the hero, not overlapping

### Pass Criteria:
✅ All visual feedback elements present and working
⚠️ If missing cyan text or blue flash, FIX NEEDED

---

## TEST 2: No Double Mana Distribution 🔢

### Test Steps:
1. [ ] Note current mana for Fire hero (or any hero)
2. [ ] Make a 3-gem match of that hero's color
3. [ ] Check mana increase amount

### Expected Results:
- [ ] **3-gem match** = approximately **15 mana gained** (BoardManager emits size * 5)
- [ ] **4-gem match** = approximately **20 mana gained**
- [ ] **5-gem match** = approximately **25 mana gained**

### ❌ FAIL Indicators:
- 3-gem match gives 30-45 mana (double distribution bug still present)
- Heroes charge ultimates in 2-3 matches (too fast)

### Pass Criteria:
✅ Mana gains match expected values (size * 5)
✅ Ultimates charge at reasonable rate (~6-7 matches for 3-gem)

---

## TEST 3: Skill Activation Audio & Haptics 🔊

### Test Steps:
1. [ ] Fill a hero's mana to 100 by matching their element
2. [ ] Wait for "READY" label to appear on hero
3. [ ] Tap the hero portrait to activate skill
4. [ ] Listen for audio and feel for vibration

### Expected Results:
- [ ] **"Upgrade" sound effect** plays (NOT "combo" sound)
- [ ] **Phone vibrates heavily** (strong haptic feedback)
- [ ] Skill activates immediately after tap

### Reference Audio:
- ✅ CORRECT: "Upgrade" sound (should sound like power-up/level-up)
- ❌ WRONG: "Combo" sound (cascade/chain sound)

### Pass Criteria:
✅ Upgrade SFX plays
✅ Heavy vibration triggers
✅ Feedback feels satisfying and impactful

---

## TEST 4: Buff Management Consolidation 🛡️

### Test Steps (BUFF_ATTACK Hero Required):
1. [ ] Use a hero with BUFF_ATTACK skill (check your team)
2. [ ] Activate the buff skill
3. [ ] Note the "BUFF UP!" message
4. [ ] Make 4 matches to consume the buff duration
5. [ ] Watch for "Buff Ended" message

### Expected Results:
- [ ] **Turn 1:** Skill activated → "BUFF UP!" appears → damage increases
- [ ] **Turns 2-4:** Damage remains buffed (1.5x multiplier)
- [ ] **Turn 5:** "Buff Ended" appears → damage returns to normal

### Damage Check:
- [ ] **Without buff:** 3-gem match deals ~100-150 damage (varies by level)
- [ ] **With buff:** Same match deals ~150-225 damage (1.5x multiplier)

### Pass Criteria:
✅ Buff lasts exactly 4 turns
✅ Damage multiplier applied correctly
✅ "Buff Ended" message appears when buff expires
✅ No weird buff behavior (infinite buffs, instant expiry, etc.)

---

## TEST 5: No Stray Bugs 🐛

### Quick Checks:
- [ ] No error messages in console/logs
- [ ] Game doesn't crash when using skills
- [ ] Mana bars update smoothly
- [ ] Board still functions normally (swapping, matching, cascades)
- [ ] Combos still work and show proper text

### Pass Criteria:
✅ No crashes or errors
✅ All game systems working normally

---

## TEST RESULTS SUMMARY

| Test | Status | Notes |
|------|--------|-------|
| 1. Mana Visual Feedback | ☐ Pass / ☐ Fail | |
| 2. No Double Mana | ☐ Pass / ☐ Fail | |
| 3. Skill Audio/Haptics | ☐ Pass / ☐ Fail | |
| 4. Buff Management | ☐ Pass / ☐ Fail | |
| 5. No Stray Bugs | ☐ Pass / ☐ Fail | |

---

## If Tests Fail:

### Test 1 Failures:
- **No cyan text:** Check `_on_mana_gained` implementation
- **No blue flash:** Check tween creation in `_on_mana_gained`
- **Wrong hero gets mana:** Check element matching logic

### Test 2 Failures:
- **Double mana:** `distribute_mana()` still being called in `_on_player_damage_dealt`
- **No mana gain:** BoardManager signal not connected or `_on_mana_gained` not working

### Test 3 Failures:
- **Wrong SFX:** Still using `play_sfx("combo")` instead of `play_sfx("upgrade")`
- **No vibration:** Missing `Audio.vibrate_heavy()` call

### Test 4 Failures:
- **Buff doesn't work:** Check TurnManager integration
- **Buff lasts wrong duration:** Check `apply_buff(1.5, 4)` parameters
- **Multiple buffs stack:** TurnManager state issue

---

## After Testing:

Once all tests pass:
1. ✅ Mark Priority 1 as COMPLETE
2. 🎯 Proceed to Priority 2 (Balance adjustments)
3. 📝 Document any edge cases discovered
4. 💾 Create git commit with test results

**Happy Testing! 🎮**
