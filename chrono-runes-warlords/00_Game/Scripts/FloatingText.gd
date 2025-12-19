class_name FloatingText extends Marker2D

func start_animation(text_value: String, color: Color) -> void:
	$Label.text = text_value
	$Label.modulate = color
	
	# Random left/right drift feel (Like critical hit)
	var random_x = randf_range(-50, 50)
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 1. UPWARD MOVEMENT (Floating)
	tween.tween_property(self, "position", position + Vector2(random_x, -100), 0.8)
	
	# 2. SCALE UP AND DOWN (Pop effect)
	scale = Vector2(0.5, 0.5)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3) # Scale up first
	tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.5) # Then settle
	
	# 3. SLOW FADE OUT
	# Reduce Label alpha to 0
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	
	# Destroy self when animation finishes
	await tween.finished
	queue_free()
