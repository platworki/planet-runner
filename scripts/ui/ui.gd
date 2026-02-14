extends CanvasLayer

var MAX_BAR_WIDTH = 0
const ITEM_SLOT_SIZE = 16  # Pixel size of each item slot

@onready var health_bar_fill: ColorRect = $UIcontainer/LeftPanel/HPcontainer/HPfill
@onready var health_label: Label = $UIcontainer/LeftPanel/HPcontainer/HPlabel
@onready var currency_label: Label = $UIcontainer/LeftPanel/CurrencyContainer/CurrencyLabel
@onready var item_grid: GridContainer = $UIcontainer/ItemBar/ItemGrid

var player_node = null

func _ready() -> void:
	await get_tree().process_frame
	MAX_BAR_WIDTH = health_bar_fill.size.x
	var player = get_tree().get_nodes_in_group("Player")
	player_node = player[0]

func _process(_delta: float) -> void:
	update_health_bar()
	update_currency()

func update_health_bar() -> void:
	var current_health = player_node.HEALTH
	var max_health = player_node.BASE_HEALTH + GameManager.player_stats.health_bonus
	
	# Update bar width
	var health_percent = clamp(float(current_health) / float(max_health), 0.0, 1.0)
	health_bar_fill.size.x = MAX_BAR_WIDTH * health_percent
	
	# Update label
	health_label.text = str(current_health) + " / " + str(max_health)

func update_currency() -> void:
	currency_label.text = str(GameManager.currency)

func update_item_display() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	
	# Stack items by name
	var stacked_items = {}
	for item in GameManager.inventory:
		if stacked_items.has(item.name):
			stacked_items[item.name].count += 1
		else:
			stacked_items[item.name] = { "data": item, "count": 1 }
	
	for item_name in stacked_items:
		var stack = stacked_items[item_name]
		var item = stack.data
		var count = stack.count
		
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(ITEM_SLOT_SIZE, ITEM_SLOT_SIZE)
		
		var style = StyleBoxFlat.new()
		match item.rarity:
			"common":     style.bg_color = Color(0.5, 0.855, 0.5, 1.0)
			"rare":       style.bg_color = Color(0.5, 0.683, 1.0, 1.0)
			"super_rare": style.bg_color = Color(0.802, 0.602, 0.0, 1.0)
			
		style.set_corner_radius_all(16)# Full radius = circle
		slot.add_theme_stylebox_override("panel", style)  # THIS LINE IS MISSING

		if item.has("sprite_default"):
			var icon = TextureRect.new()
			icon.texture = load(item.sprite_default)
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 2
			icon.offset_top = 2
			icon.offset_right = -2
			icon.offset_bottom = -2
			slot.add_child(icon)
			
		if count > 1:
			var count_label = Label.new()
			count_label.text = "x" + str(count)
			count_label.add_theme_font_size_override("font_size", 6)
			count_label.position = Vector2(ITEM_SLOT_SIZE - 6, ITEM_SLOT_SIZE - 6)
			slot.add_child(count_label)
		
		item_grid.add_child(slot)
