class_name MatchDetector

# Static helper class for match detection logic
# Extracted from BoardManager.gd for better separation of concerns

# Find all 3+ matches on the board (marks pieces as matched)
static func find_matches(all_pieces: Array, width: int, height: int) -> bool:
	var matches_found: bool = false
	
	# Horizontal matches
	for x in range(width):
		for y in range(height):
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

	# Vertical matches
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

# Get a connected cluster of matched pieces using flood-fill
static func get_match_cluster(start_x: int, start_y: int, all_pieces: Array, visited_mask: Array, width: int, height: int) -> Array[GamePiece]:
	var cluster: Array[GamePiece] = []
	
	# SAFETY: Guard against null start piece
	if all_pieces[start_x][start_y] == null:
		return cluster
		
	var queue: Array[Vector2i] = [Vector2i(start_x, start_y)]
	var target_type = all_pieces[start_x][start_y].type
	
	visited_mask[start_x][start_y] = true
	
	while not queue.is_empty():
		var current_pos = queue.pop_front()
		var x = current_pos.x
		var y = current_pos.y
		var piece = all_pieces[x][y]
		
		if piece and piece.matched and piece.type == target_type:
			cluster.append(piece)
			
			var neighbors = [
				Vector2i(x + 1, y), Vector2i(x - 1, y),
				Vector2i(x, y + 1), Vector2i(x, y - 1)
			]
			
			for n in neighbors:
				if n.x >= 0 and n.x < width and n.y >= 0 and n.y < height:
					if not visited_mask[n.x][n.y] and all_pieces[n.x][n.y] != null:
						if all_pieces[n.x][n.y].matched and all_pieces[n.x][n.y].type == target_type:
							visited_mask[n.x][n.y] = true
							queue.append(n)
							
	return cluster

# Check if a specific position would create a match
static func check_match_at(x: int, y: int, all_pieces: Array, width: int, height: int) -> bool:
	var current = all_pieces[x][y]
	if not current: return false
	var t = current.type
	
	# Horizontal
	if x > 0 and x < width - 1:
		var left = all_pieces[x-1][y]
		var right = all_pieces[x+1][y]
		if left and right and left.type == t and right.type == t: return true
	if x < width - 2:
		var right1 = all_pieces[x+1][y]
		var right2 = all_pieces[x+2][y]
		if right1 and right2 and right1.type == t and right2.type == t: return true
	if x > 1:
		var left1 = all_pieces[x-1][y]
		var left2 = all_pieces[x-2][y]
		if left1 and left2 and left1.type == t and left2.type == t: return true
		
	# Vertical
	if y > 0 and y < height - 1:
		var up = all_pieces[x][y-1]
		var down = all_pieces[x][y+1]
		if up and down and up.type == t and down.type == t: return true
	if y < height - 2:
		var down1 = all_pieces[x][y+1]
		var down2 = all_pieces[x][y+2]
		if down1 and down2 and down1.type == t and down2.type == t: return true
	if y > 1:
		var up1 = all_pieces[x][y-1]
		var up2 = all_pieces[x][y-2]
		if up1 and up2 and up1.type == t and up2.type == t: return true
		
	return false

# Simulate a swap and check if it would create a match
static func simulate_swap(p1: GamePiece, p2: GamePiece, x1: int, y1: int, x2: int, y2: int, all_pieces: Array, width: int, height: int) -> bool:
	if not p1 or not p2: return false
	
	# Swap
	all_pieces[x1][y1] = p2
	all_pieces[x2][y2] = p1
	
	var has_match = check_match_at(x1, y1, all_pieces, width, height) or check_match_at(x2, y2, all_pieces, width, height)
	
	# Undo
	all_pieces[x1][y1] = p1
	all_pieces[x2][y2] = p2
	
	return has_match

# Determine special gem type based on cluster size and shape
static func determine_special_type(cluster: Array[GamePiece]) -> GamePiece.SpecialType:
	var size = cluster.size()
	
	if size >= 5:
		return GamePiece.SpecialType.RAINBOW
	elif size == 4:
		# Check orientation
		var ys = []
		for p in cluster: 
			ys.append(p.grid_position.y)
		
		var min_y = ys.min()
		var max_y = ys.max()
		
		if min_y == max_y:
			return GamePiece.SpecialType.ROW_BLAST
		else:
			return GamePiece.SpecialType.COL_BLAST
	
	return GamePiece.SpecialType.NONE
