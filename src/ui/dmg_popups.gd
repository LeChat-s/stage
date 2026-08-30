class_name DmgPopups
extends Label

func start(amount: int, start_position: Vector2) -> void:
	text = str(amount)
	z_index = 100
	force_update_transform()
	reset_size() 
	global_position = start_position - (size / 2.0) 
	var random_x = randf_range(-30.0, 30.0)
	var target_position = global_position + Vector2(random_x, -80.0) 
	scale = Vector2.ZERO
	modulate.a = 1.0
	pivot_offset = size / 2.0 
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", target_position, 0.6)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)\
		.set_delay(0.2) 
	var scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.15)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	tween.chain().tween_callback(queue_free)
