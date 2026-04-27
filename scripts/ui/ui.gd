extends CanvasLayer

const ITEM_SLOT_SIZE = 32  # Pixel size of each item slot

@onready var currency_label: Label = $UIcontainer/HPcontainer/CurrencyLabel
@onready var health_bar: TextureProgressBar = $UIcontainer/HPcontainer/HealthBar
@onready var hp_label: Label = $UIcontainer/HPcontainer/HPlabel
@onready var item_grid: GridContainer = $UIcontainer/ItemBar/TextureRect/ItemGrid
@onready var boss_container: Control = $UIcontainer/BossContainer
@onready var boss_hp_label: Label = $UIcontainer/BossContainer/BossHPLabel
@onready var boss_health_bar: TextureProgressBar = $UIcontainer/BossContainer/BossHealthBar

var player_node = null
var current_boss = null

func _ready() -> void:
	await get_tree().process_frame

func _process(_delta: float) -> void:
	if player_node == null:
		var players = get_tree().get_nodes_in_group("Player")
		if not players.is_empty():
			player_node = players[0]
		return
	update_health_bar()
	update_currency()
	
	if current_boss != null and is_instance_valid(current_boss):
		update_boss_bar()
	elif boss_container.visible:
		boss_container.visible = false
# Call this from your Boss Manager or the Boss's _ready()

func register_boss(boss_node):
	current_boss = boss_node
	
	boss_container.modulate.a = 0
	boss_container.visible = true
	
	var tween = create_tween()
	tween.tween_property(boss_container, "modulate:a", 1.0, 1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(boss_hp_label, "self_modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	# Optional: Animate the bar filling up from 0 to full
	boss_health_bar.value = 0
	tween.parallel().tween_property(boss_health_bar, "value", 100, 2).set_trans(Tween.TRANS_QUINT)
	
func update_boss_bar():
	# Using the HEALTH and MAX_HEALTH variables from your boss script
	var health_ratio = float(current_boss.HEALTH) / current_boss.MAX_HEALTH
	boss_health_bar.value = health_ratio * 100
	boss_hp_label.text = str(current_boss.HEALTH) + "/" + str(current_boss.MAX_HEALTH)
	# Optional: Hide if dead
	if current_boss.HEALTH <= 0:
		await get_tree().create_timer(3.0).timeout
		current_boss = null
		boss_container.visible = false

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
