class_name BoardManager extends Node2D

# Ayarlar
@export var width: int = 7
@export var height: int = 8
@export var tile_size: int = 80
@export var piece_scene: PackedScene
@export var floating_text_scene: PackedScene
@export var vfx_explosion_scene: PackedScene

var piece_types: Array[String] = ["red", "blue", "green", "yellow", "purple"]

signal turn_finished 
signal damage_dealt(total_damage: int, damage_type: String, match_count: int, combo_count: int)
signal mana_gained(amount: int, color_type: String)

var current_combo: int = 0

# Setter for managing input and hint timer combined
var is_processing_move: bool = false:
	set(value):
		is_processing_move = value
		if not is_processing_move:
			_start_hint_timer()
		else:
			_stop_hint_timer()

var start_pos: Vector2
var all_pieces: Array = [] 

# Hint System
var hint_timer: Timer
var active_hint_pieces: Array[GamePiece] = []
var active_hint_tweens: Array[Tween] = []

func _ready() -> void:
	if not piece_scene:
		push_error("UYARI: BoardManager'a 'piece_scene' atanmadı!")
		return
		
	var total_w = width * tile_size
	var total_h = height * tile_size
	start_pos = Vector2(
		(720 - total_w) / 2 + (tile_size / 2), 
		(1280 - total_h) / 2 + (tile_size / 2)
	)
	
	# Hint Timer Setup
	hint_timer = Timer.new()
	hint_timer.name = "HintTimer"
	hint_timer.wait_time = 5.0
	hint_timer.one_shot = true
	hint_timer.timeout.connect(_on_hint_timer_timeout)
	add_child(hint_timer)
	
	# Initial array setup (Don't spawn here if MainGame handles loading)
	all_pieces = []
	for x in range(width):
		all_pieces.append([])
		for y in range(height):
			all_pieces[x].append(null)

func spawn_board() -> void:
	_clear_board_visuals()
	
	for x in range(width):
		for y in range(height):
			var piece = piece_scene.instantiate() as GamePiece
			add_child(piece)
			
			piece.grid_position = Vector2i(x, y)
			all_pieces[x][y] = piece
			piece.swipe_detected.connect(_on_piece_swipe_detected)
			
			# No-Match Spawn Logic
			var possible_types = piece_types.duplicate()
			
			if x > 1:
				if all_pieces[x-1][y].type == all_pieces[x-2][y].type:
					possible_types.erase(all_pieces[x-1][y].type)
			if y > 1:
				if all_pieces[x][y-1].type == all_pieces[x][y-2].type:
					possible_types.erase(all_pieces[x][y-1].type)
			
			if possible_types.is_empty():
				piece.type = piece_types.pick_random() 
			else:
				piece.type = possible_types.pick_random()
			
			_update_piece_visual(piece)
			
			var target_pos = grid_to_pixel(x, y)
			piece.position = Vector2(target_pos.x, target_pos.y - 1000)
			var delay = y * 0.05 + x * 0.05
			var tween = create_tween()
			tween.tween_interval(delay)
			tween.tween_property(piece, "position", target_pos, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	_start_hint_timer()

func _clear_board_visuals() -> void:
	# Clear existing children that are GamePieces
	for child in get_children():
		if child is GamePiece:
			child.queue_free()
	
	all_pieces = []
	for x in range(width):
		all_pieces.append([])
		for y in range(height):
			all_pieces[x].append(null)

# --- SERIALIZATION ---

func get_board_data() -> Array:
	var data = []
	for x in range(width):
		var col_data = []
		for y in range(height):
			if all_pieces[x][y] != null:
				col_data.append(all_pieces[x][y].type)
			else:
				col_data.append("") # Empty slot
		data.append(col_data)
	return data

func load_board_data(data: Array) -> void:
	_clear_board_visuals()
	
	for x in range(width):
		if x >= data.size(): break
		for y in range(height):
			if y >= data[x].size(): break
			
			var type = data[x][y]
			if type != "":
				var piece = piece_scene.instantiate() as GamePiece
				add_child(piece)
				piece.grid_position = Vector2i(x, y)
				all_pieces[x][y] = piece
				piece.swipe_detected.connect(_on_piece_swipe_detected)
				piece.type = type
				_update_piece_visual(piece)
				piece.position = grid_to_pixel(x, y)
	
	_start_hint_timer()

# --- CORE LOGIC ---

func _update_piece_visual(piece: GamePiece) -> void:
	match piece.type:
		"red": 
			piece.set_visual(preload("res://icon.svg"), Color("#ff4d4d"), "⚔️") 
		"blue": 
			piece.set_visual(preload("res://icon.svg"), Color("#4da6ff"), "💧") 
		"green": 
			piece.set_visual(preload("res://icon.svg"), Color("#5cd65c"), "🌿") 
		"yellow": 
			piece.set_visual(preload("res://icon.svg"), Color("#ffd11a"), "⚡") 
		"purple": 
			piece.set_visual(preload("res://icon.svg"), Color("#ac00e6"), "💀")

func grid_to_pixel(x: int, y: int) -> Vector2:
	return Vector2(
		start_pos.x + (x * tile_size),
		start_pos.y + (y * tile_size)
	)
	
func _on_piece_swipe_detected(source_piece: GamePiece, direction: Vector2i) -> void:
	_clear_hints()

	if is_processing_move:
		return

	var start_coords = source_piece.grid_position
	var target_coords = start_coords + direction
	
	if target_coords.x < 0 or target_coords.x >= width or target_coords.y < 0 or target_coords.y >= height:
		return
		
	var target_piece = all_pieces[target_coords.x][target_coords.y]
	
	if target_piece:
		swap_pieces(source_piece, target_piece)
	
func swap_pieces(piece_1: GamePiece, piece_2: GamePiece) -> void:
	is_processing_move = true
	Audio.play_sfx("swap")
	
	current_combo = 0
	
	var pos_1 = piece_1.grid_position
	var pos_2 = piece_2.grid_position
	
	# Swap Data
	all_pieces[pos_1.x][pos_1.y] = piece_2
	all_pieces[pos_2.x][pos_2.y] = piece_1
	
	piece_1.grid_position = pos_2
	piece_2.grid_position = pos_1
	
	# Visual Swap
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
	piece_1.z_index = 10
	piece_2.z_index = 10
	tween.tween_property(piece_1, "position", grid_to_pixel(pos_2.x, pos_2.y), 0.3)
	tween.tween_property(piece_2, "position", grid_to_pixel(pos_1.x, pos_1.y), 0.3)
	await tween.finished
	
	if not is_instance_valid(piece_1) or not is_instance_valid(piece_2):
		is_processing_move = false
		return
	
	piece_1.z_index = 0
	piece_2.z_index = 0
	
	# Check Matches
	if find_matches():
		print("Eşleşme Bulundu!")
		destroy_matched_pieces() 
	else:
		print("Eşleşme YOK! Geri alınıyor...")
		Audio.play_sfx("error")
		
		# Revert Data
		all_pieces[pos_1.x][pos_1.y] = piece_1
		all_pieces[pos_2.x][pos_2.y] = piece_2
		
		piece_1.grid_position = pos_1
		piece_2.grid_position = pos_2
		
		# Revert Visual
		var rev_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
		rev_tween.tween_property(piece_1, "position", grid_to_pixel(pos_1.x, pos_1.y), 0.3)
		rev_tween.tween_property(piece_2, "position", grid_to_pixel(pos_2.x, pos_2.y), 0.3)
		await rev_tween.finished
		
		is_processing_move = false 

func destroy_matched_pieces() -> void:
	var was_match_found = false
	var visited_mask = []
	for i in range(width):
		var col = []
		col.resize(height)
		col.fill(false)
		visited_mask.append(col)
		
	# Find independent clusters
	for x in range(width):
		for y in range(height):
			if all_pieces[x][y] != null and all_pieces[x][y].matched and not visited_mask[x][y]:
				# Found a new cluster
				was_match_found = true
				var cluster = get_match_cluster(x, y, visited_mask)
				
				# Process this specific cluster
				if not cluster.is_empty():
					var type = cluster[0].type
					var count = cluster.size()
					var damage_amount = count * 10
					
					# Emit EXACTLY for this cluster
					damage_dealt.emit(damage_amount, type, count, current_combo)
					mana_gained.emit(count * 5, type) # Adjusted mana gain logic slightly per cluster
					
					# Destroy pieces in this cluster
					for piece in cluster:
						damage_piece(piece)
						all_pieces[piece.grid_position.x][piece.grid_position.y] = null
					
	if was_match_found:
		Audio.play_sfx("match", randf_range(0.9, 1.1))
		await get_tree().create_timer(0.3).timeout
		refill_board()

func get_match_cluster(start_x: int, start_y: int, visited_mask: Array) -> Array[GamePiece]:
	var cluster: Array[GamePiece] = []
	var queue: Array[Vector2i] = [Vector2i(start_x, start_y)]
	var target_type = all_pieces[start_x][start_y].type
	
	visited_mask[start_x][start_y] = true
	
	while not queue.is_empty():
		var current_pos = queue.pop_front()
		var x = current_pos.x
		var y = current_pos.y
		var piece = all_pieces[x][y]
		
		# Validation (Existence + Match Status + Type)
		if piece and piece.matched and piece.type == target_type:
			cluster.append(piece)
			
			# Check Neighbors (Up, Down, Left, Right)
			var neighbors = [
				Vector2i(x + 1, y), Vector2i(x - 1, y),
				Vector2i(x, y + 1), Vector2i(x, y - 1)
			]
			
			for n in neighbors:
				if n.x >= 0 and n.x < width and n.y >= 0 and n.y < height:
					if not visited_mask[n.x][n.y] and all_pieces[n.x][n.y] != null:
						# Only add to queue if it matches criteria TO BE VISITED
						# Optimistic check here saves queue size
						if all_pieces[n.x][n.y].matched and all_pieces[n.x][n.y].type == target_type:
							visited_mask[n.x][n.y] = true
							queue.append(n)
							
	return cluster

func damage_piece(piece: GamePiece) -> void:
	if vfx_explosion_scene:
		var vfx = vfx_explosion_scene.instantiate() as VFX_Explosion
		add_child(vfx)
		vfx.z_index = 20
		vfx.setup(piece.position, piece.get_node("Sprite2D").modulate)

	var tween = create_tween()
	tween.tween_property(piece, "scale", Vector2.ZERO, 0.2)
	tween.finished.connect(piece.queue_free)
	
func find_matches() -> bool:
	var matches_found: bool = false
	
	for x in range(width):
		for y in range(height):
			if all_pieces[x][y]:
				all_pieces[x][y].matched = false

	for y in range(height):
		for x in range(width):
			var current_piece = all_pieces[x][y]
			if not current_piece: continue
			
			if x < width - 2:
				var piece_right_1 = all_pieces[x + 1][y]
				var piece_right_2 = all_pieces[x + 2][y]
				if piece_right_1 and piece_right_2:
					if current_piece.type == piece_right_1.type and current_piece.type == piece_right_2.type:
						current_piece.matched = true
						piece_right_1.matched = true
						piece_right_2.matched = true
						matches_found = true

	for x in range(width):
		for y in range(height):
			var current_piece = all_pieces[x][y]
			if not current_piece: continue
			
			if y < height - 2:
				var piece_down_1 = all_pieces[x][y + 1]
				var piece_down_2 = all_pieces[x][y + 2]
				if piece_down_1 and piece_down_2:
					if current_piece.type == piece_down_1.type and current_piece.type == piece_down_2.type:
						current_piece.matched = true
						piece_down_1.matched = true
						piece_down_2.matched = true
						matches_found = true
						
	return matches_found

func refill_board() -> void:
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	for x in range(width):
		for y in range(height - 1, -1, -1):
			if all_pieces[x][y] == null:
				for k in range(y - 1, -1, -1):
					if all_pieces[x][k] != null:
						move_piece(x, k, x, y, tween)
						break
				
				if all_pieces[x][y] == null:
					spawn_new_piece(x, y, tween)
					
	await tween.finished
	
	if find_matches():
		current_combo += 1
		destroy_matched_pieces()
	else:
		_check_for_deadlock_and_finish()

func _check_for_deadlock_and_finish() -> void:
	var possible_move = find_possible_move()
	if not possible_move.is_empty():
		turn_finished.emit() 
	else:
		print("DEADLOCK DETECTED! Shuffling...")
		await shuffle_board()
		
		# Recursive check after shuffle
		if find_matches():
			destroy_matched_pieces()
		else:
			_check_for_deadlock_and_finish()

func move_piece(from_x: int, from_y: int, to_x: int, to_y: int, tween: Tween) -> void:
	var piece = all_pieces[from_x][from_y]
	all_pieces[to_x][to_y] = piece
	all_pieces[from_x][from_y] = null
	piece.grid_position = Vector2i(to_x, to_y)
	tween.tween_property(piece, "position", grid_to_pixel(to_x, to_y), 0.4)

func spawn_new_piece(x: int, y: int, tween: Tween) -> void:
	var piece = piece_scene.instantiate() as GamePiece
	add_child(piece)
	piece.grid_position = Vector2i(x, y)
	all_pieces[x][y] = piece
	piece.swipe_detected.connect(_on_piece_swipe_detected)
	piece.type = piece_types.pick_random()
	_update_piece_visual(piece)
	
	var target_pos = grid_to_pixel(x, y)
	piece.position = Vector2(target_pos.x, target_pos.y - 600) 
	tween.tween_property(piece, "position", target_pos, 0.4)

# --- FEATURE: DEADLOCK SHUFFLE ---

func shuffle_board() -> void:
	spawn_floating_text("SHUFFLING!", 0, "red", get_viewport_rect().get_center())
	Audio.play_sfx("combo")
	
	var pieces: Array[GamePiece] = []
	for x in range(width):
		for y in range(height):
			if all_pieces[x][y]:
				pieces.append(all_pieces[x][y])
	
	for p in pieces:
		p.type = piece_types.pick_random()
		_update_piece_visual(p)
		var t = create_tween()
		t.tween_property(p, "scale", Vector2(1.2, 1.2), 0.1)
		t.tween_property(p, "scale", Vector2.ONE, 0.1)
		
	await get_tree().create_timer(0.3).timeout

# --- FEATURE: HINT SYSTEM ---

func find_possible_move() -> Array[GamePiece]:
	for x in range(width):
		for y in range(height):
			var current = all_pieces[x][y]
			if not current: continue
			
			if x < width - 1:
				var neighbor = all_pieces[x+1][y]
				if _simulate_swap(current, neighbor, x, y, x+1, y):
					return [current, neighbor]
			
			if y < height - 1:
				var neighbor = all_pieces[x][y+1]
				if _simulate_swap(current, neighbor, x, y, x, y+1):
					return [current, neighbor]
	return []

func _simulate_swap(p1: GamePiece, p2: GamePiece, x1: int, y1: int, x2: int, y2: int) -> bool:
	if not p1 or not p2: return false
	
	all_pieces[x1][y1] = p2
	all_pieces[x2][y2] = p1
	
	var has_match = _check_match_at(x1, y1) or _check_match_at(x2, y2)
	
	all_pieces[x1][y1] = p1
	all_pieces[x2][y2] = p2
	
	return has_match

func _check_match_at(x: int, y: int) -> bool:
	var current = all_pieces[x][y]
	if not current: return false
	var t = current.type
	
	if x > 0 and x < width - 1:
		if all_pieces[x-1][y].type == t and all_pieces[x+1][y].type == t: return true
	if x < width - 2:
		if all_pieces[x+1][y].type == t and all_pieces[x+2][y].type == t: return true
	if x > 1:
		if all_pieces[x-1][y].type == t and all_pieces[x-2][y].type == t: return true
		
	if y > 0 and y < height - 1:
		if all_pieces[x][y-1].type == t and all_pieces[x][y+1].type == t: return true
	if y < height - 2:
		if all_pieces[x][y+1].type == t and all_pieces[x][y+2].type == t: return true
	if y > 1:
		if all_pieces[x][y-1].type == t and all_pieces[x][y-2].type == t: return true
		
	return false

func _start_hint_timer() -> void:
	if hint_timer.is_stopped():
		hint_timer.start()

func _stop_hint_timer() -> void:
	hint_timer.stop()
	_clear_hints()

func _on_hint_timer_timeout() -> void:
	if is_processing_move: return
	
	var moves = find_possible_move()
	if not moves.is_empty():
		_animate_hint(moves)

func _animate_hint(pieces: Array[GamePiece]) -> void:
	_clear_hints()
	
	for p in pieces:
		if is_instance_valid(p):
			active_hint_pieces.append(p)
			var t = create_tween().set_loops()
			active_hint_tweens.append(t)
			t.tween_property(p, "scale", Vector2(1.15, 1.15), 0.6).set_trans(Tween.TRANS_SINE)
			t.tween_property(p, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
			p.modulate = Color.MAGENTA

func _clear_hints() -> void:
	for t in active_hint_tweens:
		if t and t.is_valid():
			t.kill()
	active_hint_tweens.clear()
	
	for p in active_hint_pieces:
		if is_instance_valid(p):
			p.modulate = Color.WHITE
			p.scale = Vector2.ONE
	active_hint_pieces.clear()

func spawn_floating_text(text: String, val: int, color_name: String, pos: Vector2) -> void:
	if not floating_text_scene: return
	var ft = floating_text_scene.instantiate()
	add_child(ft)
	ft.global_position = pos
	
	var c = Color.WHITE
	match color_name:
		"red": c = Color("#ff4d4d")
		"blue": c = Color("#4da6ff")
		"green": c = Color("#5cd65c")
		"yellow": c = Color("#ffd11a")
		"purple": c = Color("#ac00e6")
		_: c = Color.WHITE
		
	if ft.has_method("start_animation"):
		ft.start_animation(text, c)
