extends Control

@onready var panel_background: TextureRect = $PanelBackground
@onready var icon: TextureRect = $PanelBackground/ItemSprite
@onready var item_name: Label = $PanelBackground/ItemName
@onready var description: Label = $PanelBackground/Description

var active_tween: Tween
var hidden_pos: Vector2
var visible_pos: Vector2

# Load your textures here
const TEX_COMMON = preload("res://assets/sprites/item_description_GREEN.png")
const TEX_RARE = preload("res://assets/sprites/item_description_blue.png")
const TEX_SUPER_RARE = preload("res://assets/sprites/item_description_gold.png")

# Define your rarity colors
const COLOR_COMMON_TITLE = Color("#9aeb4d")
const COLOR_COMMON_DESC = Color("#6ee933")  
const COLOR_RARE_TITLE = Color("8ff0fbff")
const COLOR_RARE_DESC = Color("1bb7d7ff")
const COLOR_SUPER_RARE_TITLE = Color("ffea4bff")
const COLOR_SUPER_RARE_DESC = Color("f0c200ff")  

func _ready():
	# Wait for layout to settle
	await get_tree().process_frame
	
	# Position logic: 
	# hidden_pos is below the screen, visible_pos is just inside the frame
	visible_pos = panel_background.position
	hidden_pos = visible_pos + Vector2(0, 300) 
	
	panel_background.position = hidden_pos
	modulate.a = 0

func display_item(item_data: Dictionary):
	item_name.text = item_data.name
	description.text = item_data.description
	icon.texture = load(item_data.sprite_default)
	var rarity = item_data.get("rarity", "common")
	match rarity:
		"common":
			panel_background.texture = TEX_COMMON
			set_ui_colors(COLOR_COMMON_TITLE,COLOR_COMMON_DESC)
		"rare":
			panel_background.texture = TEX_RARE
			set_ui_colors(COLOR_RARE_TITLE,COLOR_RARE_DESC)
		"super_rare":
			panel_background.texture = TEX_SUPER_RARE
			set_ui_colors(COLOR_SUPER_RARE_TITLE,COLOR_SUPER_RARE_DESC)
		
	if active_tween:
		active_tween.kill()
	
	active_tween = create_tween()
	
	# PHASE 1: Move Up & Fade In
	# The first property starts the tween. 
	# The second property uses .parallel() to bind to the first.
	active_tween.tween_property(panel_background, "position", visible_pos, 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# PHASE 2: The Wait
	# .chain() forces this interval to wait for Phase 1 to finish.
	active_tween.chain().tween_interval(1.5)
	
	# PHASE 3: Move Down & Fade Out
	# .chain() here forces the exit to wait for the 3.0s interval to finish.
	active_tween.chain().tween_property(panel_background, "position", hidden_pos, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	active_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)

func set_ui_colors(color_title: Color, color_desc: Color):
	item_name.label_settings.font_color = color_title
	description.label_settings.font_color = color_desc
