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

	# Update color based on loaded status
	update_status_color()

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
			print("ENEMY STUNNED for ", turns, " turns!")
		"dot":
			dot_turns = turns
			dot_damage = value
			print("ENEMY POISONED for ", turns, " turns! Dmg: ", value)
		"def_break":
			defense_break_turns = turns
			defense_multiplier = 1.5
			print("ENEMY DEFENSE BROKEN for ", turns, " turns! Multiplier: 1.5")

	update_status_color()

	# Trigger a small shake to show status applied
	var tween = create_tween()
	tween.tween_property(visuals, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(visuals, "scale", Vector2.ONE, 0.1)

	update_status_visuals()

func update_status_visuals() -> void:
	if not status_container: return
	
	# Define Paths
	var icon_stun_path = "res://01_Assets/Art/UI/Icons/icon_stun.png"
	var icon_poison_path = "res://01_Assets/Art/UI/Icons/icon_poison.png"
	var icon_break_path = "res://01_Assets/Art/UI/Icons/icon_break.png"
	
	# OPTIMIZATION: Pool icons - get or create by index
	var status_list = []
	if stun_turns > 0: status_list.append(icon_stun_path)
	if dot_turns > 0: status_list.append(icon_poison_path)
	if defense_break_turns > 0: status_list.append(icon_break_path)
	
	# Resize pool to match needed count
	var current_count = status_container.get_child_count()
	var needed_count = status_list.size()
	
	# Remove excess icons
	while current_count > needed_count:
		var child = status_container.get_child(current_count - 1)
		child.queue_free()
		current_count -= 1
	
	# Create missing icons
	while current_count < needed_count:
		var icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(48, 48)
		status_container.add_child(icon)
		current_count += 1
	
	# Update textures on existing icons
	for i in range(needed_count):
		var icon = status_container.get_child(i) as TextureRect
		var path = status_list[i]
		
		if FileAccess.file_exists(path):
			icon.texture = load(path)
			icon.modulate = Color.WHITE
		else:
			icon.texture = preload("res://icon.svg")
			icon.modulate = Color.RED

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

	# 2. Decrement Def Break
	if defense_break_turns > 0:
		defense_break_turns -= 1
		if defense_break_turns <= 0:
			defense_multiplier = 1.0
			print("ENEMY DEFENSE RESTORED")

	# Update color after status changes
	update_status_color()

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
	# Set base color based on element
	match element_type:
		"red": current_base_color = Color("#ff4d4d")
		"blue": current_base_color = Color("#4da6ff")
		"green": current_base_color = Color("#5cd65c")
		"yellow": current_base_color = Color("#ffd11a")
		"purple": current_base_color = Color("#ac00e6")
		_: current_base_color = Color.WHITE
	# Update actual color based on status effects
	update_status_color()

# Centralized status effect color management
# Priority: Stun > DoT > Def Break > Base Color
func update_status_color() -> void:
	if not visuals:
		return

	if stun_turns > 0:
		visuals.modulate = Color(0.2, 0.2, 1.0)  # Blue tint for Stun
	elif dot_turns > 0:
		visuals.modulate = Color(0.8, 0, 0.8)  # Purple/Red tint for DoT
	elif defense_break_turns > 0:
		visuals.modulate = Color(1.0, 1.0, 0.2)  # Yellow tint for Def Break
	else:
		visuals.modulate = current_base_color  # Reset to base element color

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
	# JUICE: Hit effect (Flash and Shake)
	var tween = create_tween()

	# 1. Flash white then return to appropriate status color
	visuals.modulate = Color(10, 10, 10)  # Bright white flash

	# Use callback to restore proper color after flash
	tween.tween_callback(func(): update_status_color())
	tween.tween_interval(0.1)

	# 2. Shake effect
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
