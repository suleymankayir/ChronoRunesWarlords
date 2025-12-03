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

func take_damage(amount: int, element_type: String) -> void:
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
