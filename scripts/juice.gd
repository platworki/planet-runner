extends CanvasLayer

var flash_tweens = {}
@onready var screen_flash_rect: ColorRect = $ColorRect

func play_hit_flash(target_node: CanvasItem, color: Color = Color(10, 10, 10, 1), duration: float = 0.3):
	if not target_node: 
		return
	
	var node_id = target_node.get_instance_id()
	
	# Kill existing tween for this specific node
	if flash_tweens.has(node_id) and flash_tweens[node_id].is_valid():
		flash_tweens[node_id].kill()

	target_node.self_modulate = color
	
	var tween = create_tween()
	flash_tweens[node_id] = tween
	# Transition back to pure white (normal)
	tween.tween_property(target_node, "self_modulate", Color(1, 1, 1, 1), duration).set_trans(Tween.TRANS_CIRC)
	tween.finished.connect(func(): flash_tweens.erase(node_id))
	
func hit_stop(time_scale: float, duration: float):
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration * time_scale).timeout
	Engine.time_scale = 1.0

func play_screen_flash(duration: float = 0.3, max_alpha: float = 0.6):
	var tween = create_tween()
	# Ensure the rect is white
	screen_flash_rect.self_modulate = Color(1, 1, 1, max_alpha)
	tween.tween_property(screen_flash_rect, "self_modulate:a", 0.0, duration).set_trans(Tween.TRANS_CUBIC)

# Change 'audio' to 'stream' so we pass the file, not the node
func play_sound(stream: AudioStream, pitch_range: float = 0.0):
	if not stream: 
		return
	
	# Create a brand new, temporary audio player
	var new_player = AudioStreamPlayer.new()
	new_player.stream = stream
	
	if pitch_range > 0:
		new_player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	new_player.volume_db = -15.5
	get_tree().current_scene.add_child(new_player)
	new_player.play()
	
	# Clean up when done
	new_player.finished.connect(new_player.queue_free)
