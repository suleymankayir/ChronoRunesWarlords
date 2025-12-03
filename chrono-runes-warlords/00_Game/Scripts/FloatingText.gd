class_name FloatingText extends Marker2D

func start_animation(text_value: String, color: Color) -> void:
	$Label.text = text_value
	$Label.modulate = color
	
	# Rastgele sağa sola savrulma hissi (Kritik vuruş gibi)
	var random_x = randf_range(-50, 50)
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 1. YUKARI HAREKET (Süzülme)
	tween.tween_property(self, "position", position + Vector2(random_x, -100), 0.8)
	
	# 2. BÜYÜME VE KÜÇÜLME (Pop efekti)
	scale = Vector2(0.5, 0.5)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3) # Önce büyür
	tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.5) # Sonra oturur
	
	# 3. YAVAŞÇA YOK OLMA (Fade Out)
	# Label'ın şeffaflığını (alpha) 0'a indir
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	
	# Animasyon bitince kendini yok et
	await tween.finished
	queue_free()
