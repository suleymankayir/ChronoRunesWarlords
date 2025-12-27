class_name SpecialGems

# Static helper class for special gem logic
# Extracted from BoardManager.gd for better separation of concerns

# Determine the spawn position for a special gem within a cluster
static func get_spawn_position(cluster: Array[GamePiece]) -> Vector2i:
	if cluster.size() > 1:
		return cluster[1].grid_position
	return cluster[0].grid_position

# Apply special gem visual modifiers
static func apply_special_visuals(piece: GamePiece) -> void:
	# BUG FIX #5: Guard against null/freed piece
	if not is_instance_valid(piece): return
	
	piece.modulate = Color.WHITE
	var label = piece.get_node_or_null("Label")
	if label: label.text = ""
	
	match piece.special_type:
		GamePiece.SpecialType.ROW_BLAST:
			piece.modulate = Color(1.5, 1.2, 1.2)
			if label: label.text = "↔"
		GamePiece.SpecialType.COL_BLAST:
			piece.modulate = Color(1.2, 1.2, 1.5)
			if label: label.text = "↕"
		GamePiece.SpecialType.AREA_BOMB:
			piece.modulate = Color(1.4, 1.4, 1.0)  # Yellow glow
			if label: label.text = "✦"
		GamePiece.SpecialType.RAINBOW:
			piece.modulate = Color(2.0, 2.0, 2.0)
			if label: label.text = "★"

# Execute row blast effect - returns array of positions to clear
static func get_row_blast_targets(piece: GamePiece, all_pieces: Array, width: int) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	var y = piece.grid_position.y
	
	for i in range(width):
		var target = all_pieces[i][y]
		if target and target != piece:
			targets.append(Vector2i(i, y))
	
	return targets

# Execute column blast effect - returns array of positions to clear
static func get_col_blast_targets(piece: GamePiece, all_pieces: Array, height: int) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	var x = piece.grid_position.x
	
	for j in range(height):
		var target = all_pieces[x][j]
		if target and target != piece:
			targets.append(Vector2i(x, j))
	
	return targets

# Get all pieces of a specific color
static func get_pieces_by_color(target_color: String, all_pieces: Array, width: int, height: int) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	
	for x in range(width):
		for y in range(height):
			var piece = all_pieces[x][y]
			if piece and piece.type == target_color:
				targets.append(Vector2i(x, y))
	
	return targets
