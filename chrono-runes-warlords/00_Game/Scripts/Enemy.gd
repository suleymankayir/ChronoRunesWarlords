class_name Enemy extends Node2D

signal died # Öldüğünde haber verecek
@export var vfx_hit_scene: PackedScene
@export var max_hp: int = 20
var current_hp: int

@onready var hp_bar: ProgressBar = $ProgressBar
@onready var hp_text: Label = $ProgressBar/HPText
@onready var visuals: Sprite2D = $Visuals

func _ready() -> void:
	# Başlangıç ayarları
	current_hp = max_hp
	update_ui()

var stun_turns: int = 0
var dot_turns: int = 0
var dot_damage: int = 0
var defense_break_turns: int = 0
var defense_multiplier: float = 1.0

func apply_status(type: String, turns: int, value: int = 0) -> void:
	match type:
		"stun":
			stun_turns = turns
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

func process_turn_start() -> bool:
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
			
	# 3. Check Stun (Stun prevents action, so check last)
	if stun_turns > 0:
		stun_turns -= 1
		print("ENEMY IS STUNNED! Turns remaining: ", stun_turns)
		if stun_turns <= 0:
			visuals.modulate = Color.WHITE
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


func take_damage(amount: int, element_type: String) -> void:
	if defense_multiplier > 1.0:
		amount = int(amount * defense_multiplier)
		
	current_hp -= amount
	current_hp = max(0, current_hp) # Can 0'ın altına düşmesin
	
	if vfx_hit_scene:
		var vfx = vfx_hit_scene.instantiate() as VFX_Explosion
		get_parent().add_child(vfx) # MainGame'e ekle ki düşman titrerken partikül de titremesin
		
		# Düşmanın tam ortasında, Kan Kırmızısı veya Parlak Beyaz patlasın
		# global_position kullanarak tam yerini buluyoruz
		vfx.setup(global_position, Color.RED) # Veya Color(2, 0, 0) yaparsan parlar (HDR)
	
	update_ui()
	play_hit_animation()
	Audio.play_sfx("enemyHit", randf_range(0.9, 1.1))
	print("Düşman hasar aldı: ", amount, " | Kalan Can: ", current_hp)
	
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
	tween.tween_property(visuals, "modulate", Color.RED, 0.1) # Eski rengine (Kırmızı) dön
	
	# 2. Titreme (Shake)
	var shake_strength = 10.0
	for i in range(5):
		var offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		tween.tween_property(visuals, "position", offset, 0.05)
	
	# Sonunda merkeze dön
	tween.tween_property(visuals, "position", Vector2.ZERO, 0.05)

func die() -> void:
	Audio.play_sfx("enemyDeath")
	print("DÜŞMAN ÖLDÜ! ZAFER!")
	died.emit()
	# Şimdilik sadece yok olsun, sonra buraya Loot/Win ekranı gelecek
	queue_free()
signal attack_finished # Saldırım bitti, sıra sende demek için

func attack_player() -> void:
	Audio.play_sfx("enemyAttack")
	print("Düşman Saldırıyor!")
	
	# JUICE: Düşman ileri doğru (ekrana) hamle yapsın
	var original_pos = position
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	
	# 1. Geri çekil (Hazırlık)
	tween.tween_property(self, "position", position + Vector2(0, -50), 0.2)
	# 2. İleri fırla (Vuruş)
	tween.tween_property(self, "position", position + Vector2(0, 100), 0.1)
	
	# Vuruş anında sinyal göndereceğiz (MainGame yakalayacak)
	tween.tween_callback(func(): _deal_damage_to_player())
	
	# 3. Yerine dön
	tween.tween_property(self, "position", original_pos, 0.4)
	
	# Animasyon bitince haber ver
	await tween.finished
	attack_finished.emit()

func _deal_damage_to_player() -> void:
	# Burada sadece görsel efekt veya ses çalınabilir
	# Asıl hasar düşme işlemi MainGame'de yapılacak
	pass
