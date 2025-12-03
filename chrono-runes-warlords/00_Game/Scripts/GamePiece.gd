class_name GamePiece extends Area2D

# Sinyaller: Dış dünyaya (Board Manager) haber verme
signal piece_selected(piece: GamePiece)
signal swipe_detected(piece: GamePiece, direction: Vector2i)

var type: String = ""  # Örn: "red", "blue", "green"
var matched: bool = false # Patlamaya hazır mı?
var grid_position: Vector2i = Vector2i.ZERO

# Dokunma değişkenleri
var is_dragging: bool = false
var start_touch_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 32.0 # "Ölü Bölge" mesafesi (Piksel)

func _ready() -> void:
	# Area2D'nin kendi sinyalini kendine bağla
	# Bu, parçanın üzerine tıklandığını algılar.
	input_event.connect(_on_input_event)

# Görseli değiştirmek için yardımcı fonksiyon
func set_visual(texture: Texture2D, color_tint: Color, symbol: String) -> void:
	$Sprite2D.texture = texture
	$Sprite2D.modulate = color_tint
	$Label.text = symbol

# Bir yere gitmesi emredildiğinde (Tween ile kayarak)
func move_to_grid(target_pos: Vector2) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, 0.3)

# --- DOKUNMA MANTIĞI ---

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Sadece dokunmatik ekran veya fare sol tık olaylarına bak
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 1. AŞAMA: Dokunma Başladı
				_start_drag(get_global_mouse_position())
			else:
				# 3. AŞAMA: Dokunma Bitti (Parmağı kaldırdı)
				_end_drag()
				
	elif event is InputEventScreenTouch: # Mobil için
		if event.pressed:
			_start_drag(event.position)
		else:
			_end_drag()

func _start_drag(pos: Vector2) -> void:
	if is_dragging: return # Zaten sürükleniyorsa işlem yapma
	
	is_dragging = true
	start_touch_pos = pos
	piece_selected.emit(self) # Board'a "Bana dokundular" de.
	print("Dokunuldu: ", grid_position)
	
	# JUICE: Dokunulduğunda hafifçe parlasın veya büyüsün
	var tween = create_tween()
	tween.tween_property($Sprite2D, "scale", Vector2(0.6, 0.6), 0.1)

func _end_drag() -> void:
	if not is_dragging: return
	
	is_dragging = false
	# JUICE: Bırakıldığında eski boyutuna dönsün
	var tween = create_tween()
	tween.tween_property($Sprite2D, "scale", Vector2(0.5, 0.5), 0.1)

# Her karede sürükleme devam ediyor mu diye kontrol et (2. AŞAMA: Sürükleme)
func _process(_delta: float) -> void:
	if is_dragging:
		var current_pos = get_global_mouse_position()
		var difference = current_pos - start_touch_pos
		
		# Eğer hareket, Ölü Bölgeyi (DRAG_THRESHOLD) aştıysa
		if difference.length() > DRAG_THRESHOLD:
			_calculate_swipe_direction(difference)
			_end_drag() # Sürükleme işlemini bitir (tek bir hareket algıla)

func _calculate_swipe_direction(difference: Vector2) -> void:
	# Yatay hareket mi daha büyük, dikey mi? (Mutlak değer alarak karşılaştır)
	var direction: Vector2i = Vector2i.ZERO
	
	if abs(difference.x) > abs(difference.y):
		# Yatay hareket (Sağ veya Sol)
		direction.x = sign(difference.x) # +1 (Sağ) veya -1 (Sol)
		direction.y = 0
	else:
		# Dikey hareket (Aşağı veya Yukarı)
		direction.x = 0
		direction.y = sign(difference.y) # +1 (Aşağı) veya -1 (Yukarı)
		
	print("Sürükleme Algılandı. Yön: ", direction, " | Kimden: ", grid_position)
	# BoardManager'a sinyal gönder: "Ben bu yöne gitmek istiyorum"
	swipe_detected.emit(self, direction)
