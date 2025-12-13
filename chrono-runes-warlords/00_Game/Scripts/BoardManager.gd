class_name BoardManager extends Node2D

# Ayarlar
@export var width: int = 7  # Sütun sayısı
@export var height: int = 8 # Satır sayısı
@export var tile_size: int = 80 # Her karenin piksel boyutu
@export var piece_scene: PackedScene # GamePiece.tscn buraya atanacak
@export var floating_text_scene: PackedScene
@export var vfx_explosion_scene: PackedScene

var piece_types: Array[String] = ["red", "blue", "green", "yellow", "purple"]

signal turn_finished # İşlemler bitti sinyali
signal damage_dealt(total_damage: int, damage_type: String, match_count: int, combo_count: int)
signal mana_gained(amount: int, color_type: String)

var current_combo: int = 0

var is_processing_move: bool = false # Oyuncu hamle yaparken girişi kilitlemek için

# Tahtanın sol üst köşesinin başlangıç noktası (Ortalamak için)
var start_pos: Vector2

# Grid verisini tutan 2D Array (Aslında Array içinde Array)
var all_pieces: Array = [] 

func _ready() -> void:
	# Eğer sahneye GamePiece atamayı unuttuysan hata ver
	if not piece_scene:
		push_error("UYARI: BoardManager'a 'piece_scene' atanmadı!")
		return
		
	# Tahtayı ekranın ortasına hizala
	var total_w = width * tile_size
	var total_h = height * tile_size
	# Ekran 720x1280. Ortalamak için basit matematik:
	start_pos = Vector2(
		(720 - total_w) / 2 + (tile_size / 2), 
		(1280 - total_h) / 2 + (tile_size / 2)
	)
	
	# Veri tablosunu (Array) boşluklarla doldur (Initialize)
	all_pieces = []
	for x in range(width):
		all_pieces.append([])
		for y in range(height):
			all_pieces[x].append(null)
	
	# Oyunu başlat
	spawn_board()

func spawn_board() -> void:
	# Listeyi temizle ve hazırla
	all_pieces = []
	for x in range(width):
		all_pieces.append([])
		for y in range(height):
			all_pieces[x].append(null)

	for x in range(width):
		for y in range(height):
			var piece = piece_scene.instantiate() as GamePiece
			add_child(piece)
			
			piece.grid_position = Vector2i(x, y)
			all_pieces[x][y] = piece
			piece.swipe_detected.connect(_on_piece_swipe_detected)
			
			# --- GÜNCELLENEN KISIM: AKILLI RENK SEÇİMİ ---
			
			# Tüm olası renkleri bir listeye al
			var possible_types = piece_types.duplicate()
			
			# KONTROL 1: Sol tarafta (x-1 ve x-2) aynı renkten iki tane var mı?
			if x > 1:
				var left_piece_1 = all_pieces[x-1][y]
				var left_piece_2 = all_pieces[x-2][y]
				if left_piece_1.type == left_piece_2.type:
					# Eğer varsa, o rengi ihtimallerden çıkar
					possible_types.erase(left_piece_1.type)
			
			# KONTROL 2: Yukarıda (y-1 ve y-2) aynı renkten iki tane var mı?
			if y > 1:
				var up_piece_1 = all_pieces[x][y-1]
				var up_piece_2 = all_pieces[x][y-2]
				if up_piece_1.type == up_piece_2.type:
					# Eğer varsa, o rengi de ihtimallerden çıkar
					possible_types.erase(up_piece_1.type)
			
			# Kalan güvenli renklerden rastgele birini seç
			piece.type = possible_types.pick_random()
			
			# ---------------------------------------------

			# Görseli ata
			match piece.type:
				"red": 
					# Kılıç (Saldırı) - Ateş Kırmızısı
					piece.set_visual(preload("res://icon.svg"), Color("#ff4d4d"), "⚔️") 
				"blue": 
					# Su Damlası (Mana) - Okyanus Mavisi
					piece.set_visual(preload("res://icon.svg"), Color("#4da6ff"), "💧") 
				"green": 
					# Yaprak (Can) - Orman Yeşili
					piece.set_visual(preload("res://icon.svg"), Color("#5cd65c"), "🌿") 
				"yellow": 
					# Yıldırım (Enerji) - Altın Sarısı
					piece.set_visual(preload("res://icon.svg"), Color("#ffd11a"), "⚡") 
				"purple": 
					# Kurukafa (Zehir/Karanlık) - Ametist Moru
					piece.set_visual(preload("res://icon.svg"), Color("#ac00e6"), "💀")
			
			# (Animasyon kodları aynı kalıyor...)
			var target_pos = grid_to_pixel(x, y)
			piece.position = Vector2(target_pos.x, target_pos.y - 1000)
			var delay = y * 0.05 + x * 0.05
			var tween = create_tween()
			tween.tween_interval(delay)
			tween.tween_property(piece, "position", target_pos, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

# Grid koordinatını (3, 2) Piksel koordinatına (250, 400) çevirir
func grid_to_pixel(x: int, y: int) -> Vector2:
	return Vector2(
		start_pos.x + (x * tile_size),
		start_pos.y + (y * tile_size)
	)
	
func _on_piece_swipe_detected(source_piece: GamePiece, direction: Vector2i) -> void:
	# 1. KONTROL: Eğer zaten taşlar hareket ediyorsa, yeni emri REDDET.
	if is_processing_move:
		return

	var start_coords = source_piece.grid_position
	var target_coords = start_coords + direction
	
	# Tahta sınır kontrolü
	if target_coords.x < 0 or target_coords.x >= width or target_coords.y < 0 or target_coords.y >= height:
		return
		
	var target_piece = all_pieces[target_coords.x][target_coords.y]
	
	# Eğer hedef karede bir parça varsa (ki olmalı), değişimi başlat
	if target_piece:
		swap_pieces(source_piece, target_piece)
	
func swap_pieces(piece_1: GamePiece, piece_2: GamePiece) -> void:
	# Girişleri kilitle
	Audio.play_sfx("swap")
	is_processing_move = true
	
	# Yeni hamle, comboyu sıfırla
	current_combo = 0
	
	# 1. DATA SWAP (İleri)
	var pos_1 = piece_1.grid_position
	var pos_2 = piece_2.grid_position
	
	all_pieces[pos_1.x][pos_1.y] = piece_2
	all_pieces[pos_2.x][pos_2.y] = piece_1
	
	# Parçalar hala hayatta mı? (İlk Kontrol)
	if is_instance_valid(piece_1): piece_1.grid_position = pos_2
	if is_instance_valid(piece_2): piece_2.grid_position = pos_1
	
	# 2. VISUAL SWAP (İleri)
	# Burada da kontrol yapıyoruz, çünkü animasyon başlamadan ölmüş olabilirler
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
	
	if is_instance_valid(piece_1):
		piece_1.z_index = 10
		tween.tween_property(piece_1, "position", grid_to_pixel(pos_2.x, pos_2.y), 0.3)
		
	if is_instance_valid(piece_2):
		piece_2.z_index = 10
		tween.tween_property(piece_2, "position", grid_to_pixel(pos_1.x, pos_1.y), 0.3)
	
	# Animasyonun bitmesini bekle
	if tween: await tween.finished
	
	# --- KRİTİK KORUMA BÖLGESİ ---
	# Animasyon bitti. Peki taşlar hala yaşıyor mu?
	# Eğer biri bile öldüyse işlemi iptal et ve kilidi aç.
	if not is_instance_valid(piece_1) or not is_instance_valid(piece_2):
		is_processing_move = false
		return
	
	# Z-Indexleri normale döndür
	piece_1.z_index = 0
	piece_2.z_index = 0
	
	# 3. KONTROL ANI! Eşleşme var mı?
	if find_matches():
		print("Eşleşme Bulundu! Patlatılıyor...")
		destroy_matched_pieces() 
	else:
		print("Eşleşme YOK! Geri alınıyor...")
		Audio.play_sfx("error")
		
		# --- GERİ ALMA (REVERT) ---
		# Data Swap (Geri)
		all_pieces[pos_1.x][pos_1.y] = piece_1
		all_pieces[pos_2.x][pos_2.y] = piece_2
		
		# HATA ALDIĞIN YER BURASIYDI:
		# Artık is_instance_valid kontrolümüz olduğu için buraya güvenle girebiliriz.
		piece_1.grid_position = pos_1
		piece_2.grid_position = pos_2
		
		# Visual Swap (Geri)
		var rev_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
		rev_tween.tween_property(piece_1, "position", grid_to_pixel(pos_1.x, pos_1.y), 0.3)
		rev_tween.tween_property(piece_2, "position", grid_to_pixel(pos_2.x, pos_2.y), 0.3)
		await rev_tween.finished
		
		is_processing_move = false # Şimdi tekrar hamle yapılabilir

func destroy_matched_pieces() -> void:
	var was_match_found = false
	var damage_report = {}
	
	for x in range(width):
		for y in range(height):
			if all_pieces[x][y] != null:
				if all_pieces[x][y].matched:
					var type = all_pieces[x][y].type
					var pos = all_pieces[x][y].position
					
					mana_gained.emit(10, type)
					
					if damage_report.has(type):
						damage_report[type] += 1
					else:
						damage_report[type] = 1
						
					damage_piece(all_pieces[x][y])
					all_pieces[x][y] = null # Datadan sil
					was_match_found = true
					
					
	
	
	if was_match_found:
		# match found kısmına:
		
		Audio.play_sfx("match", randf_range(0.9, 1.1))
		
		if not damage_report.is_empty():
			for type in damage_report:
				var count = damage_report[type]
				var damage_amount = count * 10
				# Emit signal with Count and Combo
				damage_dealt.emit(damage_amount, type, count, current_combo)
				
		print("Hasar Raporu: ", damage_report)
			
		# Animasyonların bitmesi için kısa bir süre bekle
		await get_tree().create_timer(0.3).timeout
		# Boşlukları doldurmaya başla
		refill_board()

func spawn_floating_text(amount: int, type: String, world_pos: Vector2) -> void:
	if not floating_text_scene: return
	
	var ftext = floating_text_scene.instantiate() as FloatingText
	add_child(ftext)
	ftext.position = world_pos
	
	# Renge göre metin rengi ayarla
	var text_color = Color.WHITE
	match type:
		"red": text_color = Color("#ff4d4d")
		"blue": text_color = Color("#4da6ff")
		"green": text_color = Color("#5cd65c")
		"yellow": text_color = Color("#ffd11a")
		"purple": text_color = Color("#ac00e6")
		
	ftext.start_animation(str(amount), text_color)


func damage_piece(piece: GamePiece) -> void:
	# 1. PARTİKÜL EFEKTİ YARAT
	if vfx_explosion_scene:
		var vfx = vfx_explosion_scene.instantiate() as VFX_Explosion
		add_child(vfx) # BoardManager'a çocuk olarak ekle
		vfx.z_index = 20 # TAŞLARIN ÜZERİNDE PATLASIN
		
		# Taşın rengini alıp efekte veriyoruz!
		# Not: Sembol sistemine geçmiştik ama 'modulate' rengi hala tutuyor.
		vfx.setup(piece.position, piece.get_node("Sprite2D").modulate)
	

	var tween = create_tween()
	tween.tween_property(piece, "scale", Vector2.ZERO, 0.2)
	tween.finished.connect(piece.queue_free)
	
func find_matches() -> bool:
	var matches_found: bool = false
	
	# Tüm patlama etiketlerini sıfırla (Temizlik)
	for x in range(width):
		for y in range(height):
			if all_pieces[x][y]:
				all_pieces[x][y].matched = false

	# 1. YATAY KONTROL (Horizontal)
	for y in range(height):
		for x in range(width):
			var current_piece = all_pieces[x][y]
			if not current_piece: continue
			
			# Sağa doğru 2 parça daha var mı?
			if x < width - 2:
				var piece_right_1 = all_pieces[x + 1][y]
				var piece_right_2 = all_pieces[x + 2][y]
				
				# Üçü de aynı tipte mi?
				if piece_right_1 and piece_right_2:
					if current_piece.type == piece_right_1.type and current_piece.type == piece_right_2.type:
						current_piece.matched = true
						piece_right_1.matched = true
						piece_right_2.matched = true
						matches_found = true

	# 2. DİKEY KONTROL (Vertical)
	for x in range(width):
		for y in range(height):
			var current_piece = all_pieces[x][y]
			if not current_piece: continue
			
			# Aşağı doğru 2 parça daha var mı?
			if y < height - 2:
				var piece_down_1 = all_pieces[x][y + 1]
				var piece_down_2 = all_pieces[x][y + 2]
				
				# Üçü de aynı tipte mi?
				if piece_down_1 and piece_down_2:
					if current_piece.type == piece_down_1.type and current_piece.type == piece_down_2.type:
						current_piece.matched = true
						piece_down_1.matched = true
						piece_down_2.matched = true
						matches_found = true
						
	return matches_found


func refill_board() -> void:
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Her sütun için (X)
	for x in range(width):
		# Aşağıdan yukarıya doğru tara (Y)
		# Neden? Çünkü alttaki boşluğu doldurmak daha önceliklidir.
		for y in range(height - 1, -1, -1):
			
			# Eğer bu kare boşsa (null)
			if all_pieces[x][y] == null:
				# Yukarıdaki İLK dolu taşı bul
				for k in range(y - 1, -1, -1):
					if all_pieces[x][k] != null:
						# Bulduk! O taşı şimdiki boşluğa (y) taşı.
						move_piece(x, k, x, y, tween)
						break
				
				# Eğer yukarıda hiç taş yoksa? (Sütunun tepesi boşalmış demektir)
				# O zaman YENİ TAŞ yarat.
				if all_pieces[x][y] == null:
					spawn_new_piece(x, y, tween)
					
	# Tüm taşlar yerine oturduğunda tekrar kontrol et
	await tween.finished
	
	# ZİNCİRLEME REAKSİYON KONTROLÜ
	# Yeni gelen taşlar da eşleşme yaptı mı?
	if find_matches():
		print("Zincirleme Patlama!")
		current_combo += 1 # Zincirleme olduğu için combo artır
		destroy_matched_pieces() # Fonksiyon kendini tekrar çağırır (Recursion)
	else:
		print("Tahta duruldu. Sıra oyuncuda.")
		turn_finished.emit()

# Yardımcı: Mevcut taşı kaydır
func move_piece(from_x: int, from_y: int, to_x: int, to_y: int, tween: Tween) -> void:
	var piece = all_pieces[from_x][from_y]
	
	# Datayı güncelle
	all_pieces[to_x][to_y] = piece
	all_pieces[from_x][from_y] = null # Eski yeri boşalt
	piece.grid_position = Vector2i(to_x, to_y)
	
	# Görseli kaydır
	tween.tween_property(piece, "position", grid_to_pixel(to_x, to_y), 0.4)

# Yardımcı: Yeni taş yarat
func spawn_new_piece(x: int, y: int, tween: Tween) -> void:
	var piece = piece_scene.instantiate() as GamePiece
	add_child(piece)
	
	piece.grid_position = Vector2i(x, y)
	all_pieces[x][y] = piece
	piece.swipe_detected.connect(_on_piece_swipe_detected)
	
	# Rastgele tip seç (Burada güvenli seçime gerek yok, patlarsa patlasın, eğlencesi orada)
	piece.type = piece_types.pick_random()
	
	# Görseli ayarla
	match piece.type:
		"red": piece.set_visual(preload("res://icon.svg"), Color("#ff4d4d"), "⚔️") 
		"blue": piece.set_visual(preload("res://icon.svg"), Color("#4da6ff"), "💧") 
		"green": piece.set_visual(preload("res://icon.svg"), Color("#5cd65c"), "🌿") 
		"yellow": piece.set_visual(preload("res://icon.svg"), Color("#ffd11a"), "⚡") 
		"purple": piece.set_visual(preload("res://icon.svg"), Color("#ac00e6"), "💀")
	
	# Animasyon: Ekranın üstünden düşsün
	var target_pos = grid_to_pixel(x, y)
	# Başlangıç pozisyonu (Ekranın üstü)
	piece.position = Vector2(target_pos.x, target_pos.y - 600) 
	
	tween.tween_property(piece, "position", target_pos, 0.4)
