extends Area2D

var damage = 5
var already_hit = []

func trigger(origin: Vector2):
	global_position = origin
	$AnimatedSprite2D.play("explode")
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	$AudioStreamPlayer2D.play()  # ← must match node name exactly

	await get_tree().physics_frame
	await get_tree().physics_frame

	for body in get_overlapping_bodies():
		if body in already_hit:
			continue
		if body.has_method("take_damage") and body != GameManager.player_node:
			already_hit.append(body)
			body.take_damage(damage, global_position, 1.0, true)
			body.apply_status_effect("burn")

func _on_animation_finished():
	queue_free()
