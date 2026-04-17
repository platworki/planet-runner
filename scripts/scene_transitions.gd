extends CanvasLayer

var fade_rect: ColorRect

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
	fade_rect.color = Color.WHITE
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 2.5).set_trans(Tween.TRANS_QUART)
	await tween.finished
	
	# Change scene while white
	get_tree().change_scene_to_file(scene_path)
	
	# Fade in from white
	tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 3).set_trans(Tween.TRANS_QUART)

func fade_to_scene_black(scene_path: String):
	fade_rect.color = Color.BLACK
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 2).set_trans(Tween.TRANS_QUART)
	await tween.finished
	
	# Change scene while white
	get_tree().change_scene_to_file(scene_path)
	
	# Fade in from white
	tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 3).set_trans(Tween.TRANS_QUART)
