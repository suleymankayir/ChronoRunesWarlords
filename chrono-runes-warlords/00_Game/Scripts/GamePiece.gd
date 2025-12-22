class_name GamePiece extends Area2D

# Signals: Notify outside world (Board Manager)
signal piece_selected(piece: GamePiece)
signal swipe_detected(piece: GamePiece, direction: Vector2i)

var type: String = ""  # E.g., "red", "blue", "green"
var matched: bool = false # Ready to explode?
var grid_position: Vector2i = Vector2i.ZERO

# Touch variables
var is_dragging: bool = false
var start_touch_pos: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 32.0 # "Dead Zone" distance (Pixels)
var initial_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	# Store the initial scale for juice calculations
	initial_scale = $Sprite.scale
	
	# Connect Area2D's own signal to itself
	# This detects clicks on the piece.
	input_event.connect(_on_input_event)

# Helper function to change visual
func set_visual(texture: Texture2D, color_tint: Color, symbol: String) -> void:
	$Sprite.texture = texture
	$Sprite.modulate = color_tint
	$Label.text = symbol

# When ordered to go somewhere (sliding with Tween)
func move_to_grid(target_pos: Vector2) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, 0.3)

# --- TOUCH LOGIC ---

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Check only touch screen or left mouse click events
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# PHASE 1: Touch Started
				_start_drag(get_global_mouse_position())
			else:
				# PHASE 3: Touch Ended (Finger lifted)
				_end_drag()
				
	elif event is InputEventScreenTouch: # For Mobile
		if event.pressed:
			_start_drag(event.position)
		else:
			_end_drag()

func _start_drag(pos: Vector2) -> void:
	if is_dragging: return # Do nothing if already dragging
	
	is_dragging = true
	start_touch_pos = pos
	piece_selected.emit(self) # Tell Board 'I was touched'.
	print("Touched: ", grid_position)
	
	# JUICE: POP UP effect
	z_index = 10
	modulate = Color(1.5, 1.5, 1.5) # HDR Glow
	
	var tween = create_tween()
	# Use relative scale based on initial_scale
	tween.tween_property($Sprite, "scale", initial_scale * 1.2, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _end_drag() -> void:
	if not is_dragging: return
	
	is_dragging = false
	
	# JUICE: Reset
	z_index = 0
	modulate = Color.WHITE
	
	var tween = create_tween()
	# Return to initial storage scale
	tween.tween_property($Sprite, "scale", initial_scale, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Check if dragging continues every frame (PHASE 2: Dragging)
func _process(_delta: float) -> void:
	if is_dragging:
		var current_pos = get_global_mouse_position()
		var difference = current_pos - start_touch_pos
		
		# If movement exceeds Dead Zone (DRAG_THRESHOLD)
		if difference.length() > DRAG_THRESHOLD:
			_calculate_swipe_direction(difference)
			_end_drag() # End drag (detect single gesture)

func _calculate_swipe_direction(difference: Vector2) -> void:
	# Is horizontal movement larger or vertical? (Compare absolute values)
	var direction: Vector2i = Vector2i.ZERO
	
	if abs(difference.x) > abs(difference.y):
		# Horizontal movement (Right or Left)
		direction.x = sign(difference.x) # +1 (Right) or -1 (Left)
		direction.y = 0
	else:
		# Vertical movement (Down or Up)
		direction.x = 0
		direction.y = sign(difference.y) # +1 (Down) or -1 (Up)
		
	print("Swipe Detected. Dir: ", direction, " | From: ", grid_position)
	# Signal BoardManager: 'I want to go this way'
	swipe_detected.emit(self, direction)
