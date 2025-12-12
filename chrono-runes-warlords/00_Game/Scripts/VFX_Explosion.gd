class_name VFX_Explosion extends GPUParticles2D

func setup(pos: Vector2, color: Color) -> void:
	global_position = pos
	modulate = color * 1.5 # GLOW EFFECT (HDR)
	one_shot = true
	emitting = true
	
	# İş bitince kendini yok et
	await finished
	queue_free()
