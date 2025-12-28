# Test Guide
I have created a verification script to test the bug fixes for the Skill/Mana system.

## How to Run
Since this project uses Godot, you can run the test script using the Godot command line interface.

**Command:**
```bash
godot --headless --script _Debug/VerifyBugFixes.gd
```
*(Ensure `godot` is in your system PATH, or provide the full path to your Godot executable)*

## What is Tested
1. **BattleHero Mana Reset**: Verifies that mana is reset to 0 *before* the `skill_activated` signal is emitted. This ensures that any save operations triggered by the signal capture the correct (empty) mana state.
2. **Enemy Status Visuals**: Verifies that the enemy's color (modulate) is correctly updated based on loaded status effects (Stun, DoT, Defense Break) immediately upon initialization/loading.

## Expected Output
```
--- STARTING BUG FIX VERIFICATION ---

TEST 1: BattleHero Mana Reset Order
   -> Simulating button press with Max Mana...
   -> Signal received. Current Mana: 0
   [PASS] Mana was 0 at signal emission.

TEST 2: Enemy Status Visuals on Load
   -> Simulating _ready with stun_turns = 1...
   [PASS] Visuals modulate is correctly BLUE (Stunned).
   [PASS] Visuals modulate is correctly PURPLE (DoT).

--- ALL TESTS COMPLETED ---
```
