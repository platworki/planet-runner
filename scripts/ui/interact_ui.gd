extends Node2D

@onready var cost_label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D
@onready var error_sfx: AudioStreamPlayer = $Error

var active_tween: Tween
var is_locked = false

func _ready():
	modulate.a = 0 # Start invisible
	hide()

func show_ui(cost: int = 0):
	if is_locked:
		return
	# 1. Kill any existing transition
	if active_tween:
		active_tween.kill()
	
	if cost > 0:
		cost_label.text = str(cost) + "c"
		cost_label.show()
	else:
		cost_label.hide()
	
	show()
	active_tween = create_tween()
	active_tween.tween_property(self, "modulate:a", 1.0, 0.1).set_trans(Tween.TRANS_CUBIC)
	
func flash_ui_red():
	var tween = create_tween()
	tween.parallel().tween_property(self, "modulate:s", 0.8, 0.1).set_trans(Tween.TRANS_QUAD)
	error_sfx.play()
	tween.tween_property(self, "modulate:s", 0, 0.2).set_trans(Tween.TRANS_SINE)

func hide_ui():
	if active_tween:
		active_tween.kill()
		
	active_tween = create_tween()
	active_tween.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC)
	
	# 2. Use a callback instead of await to avoid the "ghost" hide
	active_tween.finished.connect(func(): 
		if modulate.a == 0:
			hide()
	)

func lock_and_hide():
	is_locked = true
	hide_ui()

func unlock():
	is_locked = false
