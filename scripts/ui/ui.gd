extends CanvasLayer

var MAX_BAR_WIDTH = 0
const ITEM_SLOT_SIZE = 32  # Pixel size of each item slot

@onready var currency_label: Label = $UIcontainer/HPcontainer/CurrencyLabel
@onready var health_bar: TextureProgressBar = $UIcontainer/HPcontainer/HealthBar
@onready var hp_label: Label = $UIcontainer/HPcontainer/HPlabel
@onready var item_grid: GridContainer = $UIcontainer/ItemBar/TextureRect/ItemGrid


var player_node = null

func _ready() -> void:
	await get_tree().process_frame
	MAX_BAR_WIDTH = health_bar.max_value
	var player = get_tree().get_nodes_in_group("Player")
	player_node = player[0]

func _process(_delta: float) -> void:
	update_health_bar()
	update_currency()

func update_health_bar() -> void:
	var current_health = player_node.HEALTH
	var max_health = player_node.BASE_HEALTH + GameManager.player_stats.health_bonus
	
	# Update bar width
	health_bar.value = (float(current_health) / float(max_health)) * 100
	hp_label.text = str(current_health) + "/" + str(max_health)

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
		
		var slot = Control.new()  # Change this line
		slot.custom_minimum_size = Vector2(ITEM_SLOT_SIZE, ITEM_SLOT_SIZE)

		if item.has("sprite_default"):
			var icon = TextureRect.new()
			icon.texture = load(item.sprite_default)
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			slot.add_child(icon)
			
		if count > 1:
			var count_label = Label.new()
			count_label.text = "x" + str(count)
			count_label.add_theme_font_size_override("font_size", 14)
			count_label.position = Vector2(ITEM_SLOT_SIZE - 12, ITEM_SLOT_SIZE - 12)
			slot.add_child(count_label)
		
		item_grid.add_child(slot)
