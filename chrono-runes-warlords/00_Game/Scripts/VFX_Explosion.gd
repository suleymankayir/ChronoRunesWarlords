class_name VFX_Explosion extends GPUParticles2D

func setup(pos: Vector2, color: Color) -> void:
	global_position = pos
	modulate = color # Partikülü taşın rengine boya!
	emitting = true
	
	# İş bitince kendini yok et
	await finished
	queue_free()
