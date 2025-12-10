extends Node2D

@onready var board_manager: BoardManager = $BoardManager
@onready var enemy: Enemy = $Enemy
@onready var player_hp_bar: ProgressBar = $UILayer/PlayerHPBar
@onready var player_hp_text: Label = $UILayer/PlayerHPBar/PlayerHPText
@onready var ui_layer: CanvasLayer = $UILayer
@onready var skill_button: Button = $UILayer/SkillButton
@onready var mana_bar: TextureProgressBar = $UILayer/ManaBar
@export var game_over_scene: PackedScene
@onready var fog_layer: TextureRect = $BackgroundLayer/FogLayer


var current_level: int = 1
var gold_earned_this_session: int = 0
var player_max_hp: int = 500
var player_current_hp: int = 500
var is_player_turn: bool = true
var current_mana: int = 0
var max_mana: int = 100
var current_score: int = 0
var is_level_transitioning: bool = false # Seviye geçişi var mı?

func _ready() -> void:
	if Audio.bg_music:
		Audio.play_music(Audio.bg_music)
		
	# DYNAMIC STATS (SCALING)
	# Formula: Base 500 + (Total Team Level * 50)
	var team_level = GameEconomy.get_team_total_level()
	# [DEBUG] Print to verify scaling
	print(">>> SCALING DEBUG: Team Total Level = ", team_level)
	
	player_max_hp = 500 + (team_level * 50)
	player_current_hp = player_max_hp
	print("Player Max HP Scaled to: ", player_max_hp)
	
	update_mana_ui()
	update_player_ui()
	
	# Connect Signals
	board_manager.damage_dealt.connect(_on_player_damage_dealt)
	board_manager.turn_finished.connect(_on_board_settled) 
	board_manager.mana_gained.connect(_on_mana_gained)
	
	if enemy:
		enemy.attack_finished.connect(_on_enemy_attack_finished)
		enemy.died.connect(_on_enemy_died)
		
	skill_button.pressed.connect(_on_skill_activated)
	
	# Debug UI connection
	GameEconomy.gold_updated.connect(func(new_gold): print("UI GOLD UPDATE: ", new_gold))

# 1. Oyuncu hamlesini yaptı, taşlar patladı, her şey duruldu.
func _on_board_settled() -> void:
	print("Tahta duruldu. Sıra düşmana geçiyor...")
	is_player_turn = false
	board_manager.is_processing_move = true # Tahtayı kilitle (Garanti olsun)
	
	# Kısa bir bekleme (Olayları idrak etmek için)
	await get_tree().create_timer(0.5).timeout
	
	# Düşmanı saldırt
	if is_instance_valid(enemy):
		enemy.attack_player()
	else:
		start_player_turn()
		
func _on_enemy_attack_finished() -> void:
	# Oyuncuya hasar ver (Örn: 50 vursun)
	take_player_damage(50)
	
	# Sırayı oyuncuya ver
	start_player_turn()
	
func start_player_turn() -> void:
	print("Sıra Oyuncuda!")
	is_player_turn = true
	board_manager.is_processing_move = false # Kilidi aç
	
func take_player_damage(amount: int) -> void:
	player_current_hp -= amount
	update_player_ui()
	
	# SCREEN SHAKE: Oyuncu hasar alınca ekran sallansın (Juice)
	var tween = create_tween()
	var camera = $Camera2D # Eğer kameran yoksa sahneye ekle!
	if camera:
		for i in range(10):
			var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
			tween.tween_property(camera, "offset", offset, 0.05)
		tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

	if player_current_hp <= 0:
		print("GAME OVER - OYUNCU ÖLDÜ")
		game_over(false)

func game_over(is_victory: bool) -> void:
	if not game_over_scene: return
	
	Audio.stop_music()

	if is_victory:
		Audio.play_sfx("victory")
	else:
		Audio.play_sfx("gameover")
	
	# HIGH SCORE CHECK (GAME ECONOMY)
	GameEconomy.check_new_high_score(current_score)
	
	var popup = game_over_scene.instantiate()
	ui_layer.add_child(popup)
	
	if popup is Control:
		popup.set_anchors_preset(Control.PRESET_FULL_RECT)
		popup.offset_left = 0
		popup.offset_top = 0
		popup.offset_right = 0
		popup.offset_bottom = 0
	
	# Popup'ı başlat
	if popup.has_method("show_result"):
		popup.show_result(is_victory, current_score)
	
	if popup.has_signal("restart_requested"):
		popup.restart_requested.connect(reload_game)

func reload_game() -> void:
	# En basit reset yöntemi: Sahne dosyasını baştan yükle
	get_tree().reload_current_scene()
		
func update_player_ui() -> void:
	if player_max_hp > 0:
		player_hp_bar.value = (float(player_current_hp) / player_max_hp) * 100
	player_hp_text.text = str(player_current_hp) + " / " + str(player_max_hp)

func _on_player_damage_dealt(amount: int, type: String) -> void:
	if is_level_transitioning: return
	if not is_instance_valid(enemy):
		return
	
	# DYNAMIC DAMAGE SCALING (GAME ECONOMY)
	# Formula: 1.0 + (Total Team Level * 0.1)
	var team_level = GameEconomy.get_team_total_level()
	var multiplier = 1.0 + (team_level * 0.1) 
	
	var final_damage = int(amount * multiplier)
		
	enemy.take_damage(final_damage, type)
	
	current_score += final_damage
	Audio.play_sfx("playerAttack")
	await get_tree().create_timer(0.2).timeout
	Audio.play_sfx("enemyHit")
	
		
func _on_mana_gained(amount: int, color_type: String) -> void:
	if color_type == "blue":
		current_mana += amount
		current_mana = min(current_mana, max_mana)
		update_mana_ui()

		var tween = create_tween()
		tween.tween_property(mana_bar, "modulate", Color("#80c2ff"), 0.1)
		tween.tween_property(mana_bar, "modulate", Color("#4da6ff"), 0.1)    # Normal mavi

func _on_skill_activated() -> void:
	if current_mana < max_mana: return
	
	if is_level_transitioning: return
	if not is_instance_valid(enemy): return
	
	print("ULTIMATE YETENEK KULLANILDI!")
	
	current_mana = 0
	update_mana_ui()
	Audio.play_sfx("combo", 0.5)
	if enemy.vfx_hit_scene:
		var vfx = enemy.vfx_hit_scene.instantiate()
		enemy.add_child(vfx)
		vfx.scale = Vector2(3.0, 3.0)
		vfx.setup(Vector2.ZERO, Color.CYAN)
		enemy.take_damage(250, "magic")
	var camera = $Camera2D
	if camera:
		var tween = create_tween()
		for i in range(20):
			tween.tween_property(camera, "offset", Vector2(randf_range(-10,10), randf_range(-10,10)), 0.02)
		tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

func update_mana_ui() -> void:
	mana_bar.value = current_mana
	
	if current_mana >= max_mana:
		skill_button.disabled = false
		skill_button.text = "HAZIR!"
		
		if not skill_button.is_inside_tree(): return
	else:
		skill_button.disabled = true
		skill_button.text = str(current_mana) + "%"

func _process(delta: float) -> void:
	# Eğer mana doluysa butonu nefes alıp verdir
	if current_mana >= max_mana:
		var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.1 # 0 ile 0.2 arası
		skill_button.scale = Vector2(1.0 + pulse, 1.0 + pulse)
		skill_button.modulate = Color(1.5, 1.5, 2.0) # Hafif parlak
	else:
		skill_button.scale = Vector2(1.0, 1.0)
		skill_button.modulate = Color.WHITE
	if fog_layer:
		pass

func _on_enemy_died() -> void:
	is_level_transitioning = true
	print("Düşman Öldü! Seviye Atlanıyor...")
	Audio.play_sfx("victory") # Zafer sesi (kısa)
	
	# 1. ÖDÜL: Altın Kazan (GAME ECONOMY)
	var gold_reward = 100 * current_level
	gold_earned_this_session += gold_reward
	
	GameEconomy.add_gold(gold_reward) # Direct GameEconomy call
	print(">>> Gold Reward Added: ", gold_reward)
	
	# 2. ÖDÜL: Oyuncuyu biraz iyileştir (%20)
	var heal_amount = int(player_max_hp * 0.2)
	player_current_hp = min(player_current_hp + heal_amount, player_max_hp)
	update_player_ui()
	
	# 3. ZORLUK ARTIRMA
	current_level += 1
	
	# Yeni düşman yaratmak için kısa bir bekleme
	board_manager.is_processing_move = true # Oyuncu hamle yapamasın
	await get_tree().create_timer(1.0).timeout
	
	spawn_next_enemy()

func spawn_next_enemy() -> void:
	# Eski düşmanı temizle (Eğer hala sahnedeyse)
	if is_instance_valid(enemy):
		enemy.queue_free()
	
	# Düşman sahnesini yeniden yükle
	var new_enemy = load("res://00_Game/Scenes/Enemy.tscn").instantiate()
	add_child(new_enemy)
	new_enemy.position = Vector2(360, 250)
	
	# --- STATLARI GÜÇLENDİR (SCALING) ---
	# Matematik: Her level %20 daha zor
	var multiplier = 1.0 + ((current_level - 1) * 0.2)
	
	new_enemy.max_hp = int(1000 * multiplier)
	new_enemy.current_hp = new_enemy.max_hp
	new_enemy.update_ui()
	
	# Düşmanın rengini değiştir (Görsel Çeşitlilik)
	var hue_shift = (current_level * 0.1) 
	new_enemy.modulate = Color.from_hsv(hue_shift, 1.0, 1.0)
	
	# BAĞLANTILARI TEKRAR YAP
	enemy = new_enemy # Global değişkeni güncelle
	enemy.attack_finished.connect(_on_enemy_attack_finished)
	enemy.died.connect(_on_enemy_died)
	
	# Oyuncunun kilidini aç
	board_manager.is_processing_move = false
	start_player_turn()
	
	print("Yeni Düşman Geldi! Seviye: ", current_level, " | Can: ", new_enemy.max_hp)
	is_level_transitioning = false
