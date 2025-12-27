class_name Enemy extends Node2D

signal died # Signal when dead
@export var vfx_hit_scene: PackedScene
@export var max_hp: int = 20
var current_hp: int
var current_base_color: Color = Color.WHITE
# Replaces start_position logic for more robustness
var home_position: Vector2 = Vector2.ZERO

@onready var hp_bar: ProgressBar = $ProgressBar
@onready var hp_text: Label = $ProgressBar/HPText
@onready var visuals: Sprite2D = $Visuals
@onready var status_container: HBoxContainer = $StatusContainer

func _ready() -> void:
	# Initial settings
	# Wait for MainGame to set position, but set default here
	home_position = position 
	current_hp = max_hp
	update_ui()
	
	# Wait one frame ensuring data from save file (if any) is populated
	await get_tree().process_frame
	update_status_visuals()

	update_status_visuals()

func update_home_position() -> void:
	home_position = position
	print("Enemy Home Position Set: ", home_position)

var stun_turns: int = 0
var stun_immunity_turns: int = 0  # BALANCE: Prevents perma-stun exploit
var dot_turns: int = 0
var dot_damage: int = 0
var defense_break_turns: int = 0
var defense_multiplier: float = 1.0

func apply_status(type: String, turns: int, value: int = 0) -> void:
	match type:
		"stun":
			# BALANCE: Check immunity to prevent perma-stun
			if stun_immunity_turns > 0:
				if get_parent().has_method("spawn_status_text"):
					get_parent().spawn_status_text("IMMUNE!", Color.ORANGE, global_position + Vector2(0, -50))
				print("Enemy is immune to stun! Cooldown: ", stun_immunity_turns)
				return
			
			stun_turns = turns
			stun_immunity_turns = 3  # Immune for 3 turns after stun ends
			visuals.modulate = Color(0.2, 0.2, 1.0) # Blue tint for Freeze
			print("ENEMY STUNNED for ", turns, " turns!")
		"dot":
			dot_turns = turns
			dot_damage = value
			visuals.modulate = Color(0.8, 0, 0.8) # Purple/Red tint for Poison/Burn
			print("ENEMY POISONED for ", turns, " turns! Dmg: ", value)
		"def_break":
			defense_break_turns = turns
			defense_multiplier = 1.5
			visuals.modulate = Color(1.0, 1.0, 0.2) # Yellow tint for Weakened
			print("ENEMY DEFENSE BROKEN for ", turns, " turns! Multiplier: 1.5")
			
	# Trigger a small shake to show status applied
	var tween = create_tween()
	tween.tween_property(visuals, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(visuals, "scale", Vector2.ONE, 0.1)
	
	update_status_visuals()

func update_status_visuals() -> void:
	if not status_container: return
	
	# Clear existing
	for child in status_container.get_children():
		child.queue_free()

	# Define Paths
	var icon_stun_path = "res://01_Assets/Art/UI/Icons/icon_stun.png"
	var icon_poison_path = "res://01_Assets/Art/UI/Icons/icon_poison.png"
	var icon_break_path = "res://01_Assets/Art/UI/Icons/icon_break.png"

	# Helper to create icon
	var create_icon = func(path: String):
		var icon = TextureRect.new()
		var exists = FileAccess.file_exists(path)
		
		# DEBUG LOGGING
		print("[Enemy] Checking icon: ", path, " | Exists: ", exists)
		
		if exists:
			icon.texture = load(path)
			icon.modulate = Color.WHITE # Clean original art
		else:
			# MISSING ASSET FALLBACK
			icon.texture = preload("res://icon.svg")
			icon.modulate = Color.RED # Bright RED to indicate error/missing
			
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(48, 48)
		
		status_container.add_child(icon)
		
	if stun_turns > 0:
		create_icon.call(icon_stun_path)
	if dot_turns > 0:
		create_icon.call(icon_poison_path)
	if defense_break_turns > 0:
		create_icon.call(icon_break_path)

func process_turn_start() -> bool:
	# 0. Decrement stun immunity
	if stun_immunity_turns > 0:
		stun_immunity_turns -= 1
		if stun_immunity_turns == 0:
			print("Enemy stun immunity expired!")
	
	# 1. Apply DoT
	if dot_turns > 0:
		take_damage(dot_damage, "dot")
		dot_turns -= 1
		# Visual feedback for DoT tick
		if get_parent().has_method("spawn_status_text"):
			get_parent().spawn_status_text("-%d" % dot_damage, Color.PURPLE, global_position + Vector2(0, -50))
			
		if dot_turns <= 0:
			visuals.modulate = Color.WHITE # Reset color if no other status

	# 2. Decrement Def Break
	if defense_break_turns > 0:
		defense_break_turns -= 1
		if defense_break_turns <= 0:
			defense_multiplier = 1.0
			visuals.modulate = Color.WHITE
			print("ENEMY DEFENSE RESTORED")
			
	# Update Visuals after decrements (DoT/Def updates)
	update_status_visuals()
			
	# 3. Check Stun (Stun prevents action, so check last)
	if stun_turns > 0:
		stun_turns -= 1
		print("ENEMY IS STUNNED! Turns remaining: ", stun_turns)
		
		# CRITICAL UX FIX: If Stun reaches 0, we are still skipping THIS turn.
		# So we keep the Modulate/Icon visible for this one last turn.
		# We ONLY update visuals (remove icon) if there are still turns left (refreshing)
		# or if we started at 0 (handled below).
		
		if stun_turns > 0:
			update_status_visuals()
		else:
			# Stun is 0, but we want to KEEP the visual for this skipped turn.
			# Do NOT call update_status_visuals() which would remove it.
			pass
			
		return true # Action Skipped
			
	return false # Can act

var element_type: String = "red"

func setup_element(new_type: String) -> void:
	element_type = new_type
	# Only reset modulate if no status effects are active
	if stun_turns == 0 and dot_turns == 0 and defense_break_turns == 0:
		match element_type:
			"red": visuals.modulate = Color("#ff4d4d")
			"blue": visuals.modulate = Color("#4da6ff")
			"green": visuals.modulate = Color("#5cd65c")
			"yellow": visuals.modulate = Color("#ffd11a")
			"purple": visuals.modulate = Color("#ac00e6")
			_: visuals.modulate = Color.WHITE
			
	current_base_color = visuals.modulate


func take_damage(amount: int, element_type: String) -> void:
	if defense_multiplier > 1.0:
		amount = int(amount * defense_multiplier)
		
	current_hp -= amount
	current_hp = max(0, current_hp) # Prevent HP from dropping below 0
	
	if vfx_hit_scene:
		var vfx = vfx_hit_scene.instantiate() as VFX_Explosion
		get_parent().add_child(vfx) # Add to MainGame so particle doesn't shake with enemy
		
		# Explode in center of enemy, Blood Red or Bright White
		# Find exact location using global_position
		vfx.setup(global_position, Color.RED) # Or use Color(2, 0, 0) to glow (HDR)
	
	update_ui()
	play_hit_animation()
	Audio.play_sfx("enemyHit", randf_range(0.9, 1.1))
	print("Enemy took damage: ", amount, " | HP Remaining: ", current_hp)
	
	if current_hp <= 0:
		die()

func update_ui() -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_text.text = str(current_hp) + " / " + str(max_hp)

func play_hit_animation() -> void:
	# JUICE: Vurulma hissi (Kızarma ve Titreme)
	var tween = create_tween()
	
	# 1. Renk değişimi (Beyaza parlayıp geri dönme - Flash Effect)
	visuals.modulate = Color(10, 10, 10) # Çok parlak beyaz (Glow varsa parlar)
	tween.tween_property(visuals, "modulate", current_base_color, 0.1) # Dönüş: Orijinal renk
	
	# 2. Titreme (Shake)
	var shake_strength = 10.0
	for i in range(5):
		var offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		tween.tween_property(visuals, "position", offset, 0.05)
	
	# Return to center at end
	tween.tween_property(visuals, "position", Vector2.ZERO, 0.05)

func die() -> void:
	Audio.play_sfx("enemyDeath")
	print("ENEMY DIED! VICTORY!")
	died.emit()
	# Just destroy for now, Loot/Win screen will come later
	queue_free()
signal attack_finished # To say my attack is finished, your turn

func attack_player() -> void:
	Audio.play_sfx("enemyAttack")
	print("Enemy Attacking!")
	
	# JUICE: Enemy lunges forward (towards screen)
	var original_pos = position
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	
	# 1. Pull back (Anticipation)
	tween.tween_property(self, "position", position + Vector2(0, -50), 0.2)
	# 2. Lunge forward (Strike)
	tween.tween_property(self, "position", position + Vector2(0, 100), 0.1)
	
	# Emit signal at strike moment (MainGame will catch)
	tween.tween_callback(func(): _deal_damage_to_player())
	
	# 3. Return to position
	tween.tween_property(self, "position", home_position, 0.4)
	
	# Notify when animation finishes
	await tween.finished
	attack_finished.emit()

func _deal_damage_to_player() -> void:
	# Only visual effects or sound can be played here
	# Actual damage dealing logic will be in MainGame
	pass
