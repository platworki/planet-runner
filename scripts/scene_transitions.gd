extends CanvasLayer

var fade_rect: ColorRect
var music_bus = AudioServer.get_bus_index("Music")
var is_transitioning = false

func _ready():
	# Renders above all other CanvasLayers
	layer = 100
	fade_rect = ColorRect.new()
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0
	fade_rect.z_index = 100
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade_rect)

func fade_to_scene_white(scene_path: String):
	if is_transitioning: 
		return # Safety check
	
	is_transitioning = true
	fade_rect.color = Color.WHITE
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(fade_rect, "modulate:a", 1.0, 4).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(set_volume, 0.0, -40.0, 4).set_trans(Tween.TRANS_CIRC)
	
	await tween.finished
	
	get_tree().change_scene_to_file(scene_path)
	
	# Fade back in
	var tween_in = create_tween().set_parallel(true)
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, 3).set_trans(Tween.TRANS_QUART)
	tween_in.tween_method(set_volume, -80.0, 0.0, 0.15).set_trans(Tween.TRANS_EXPO)
	
	# NEW: Wait for the second tween to finish before allowing input again
	await tween_in.finished
	is_transitioning = false
	
func set_volume(value: float):
	AudioServer.set_bus_volume_db(music_bus, value)
	
func fade_to_scene_black(scene_path: String):
	if is_transitioning: 
		return # Safety check
	
	is_transitioning = true
	fade_rect.color = Color.BLACK
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(fade_rect, "modulate:a", 1.0, 5).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(set_volume, 0.0, -40.0, 5).set_trans(Tween.TRANS_CIRC)
	
	await tween.finished
	
	get_tree().change_scene_to_file(scene_path)
	
	# Fade back in
	var tween_in = create_tween().set_parallel(true)
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, 4.0).set_trans(Tween.TRANS_QUART)
	tween_in.tween_method(set_volume, -80.0, 0.0, 0.1).set_trans(Tween.TRANS_EXPO)
	
	# NEW: Wait for the second tween to finish before allowing input again
	await tween_in.finished
	is_transitioning = false
