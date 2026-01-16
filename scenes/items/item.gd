extends Area2D

var item_data = {}
var player_in_range = false

@onready var sprite_default: Sprite2D = $SpriteDefault
@onready var sprite_highlight: Sprite2D = $SpriteHighlight

func _ready() -> void:
	# Load sprites from item data
	if item_data.has("sprite_default"):
		sprite_default.texture = load(item_data.sprite_default)
	if item_data.has("sprite_highlight"):
		sprite_highlight.texture = load(item_data.sprite_highlight)
	
	# Start with default visible
	sprite_default.visible = true
	sprite_highlight.visible = false

func _process(_delta):
	# Check for pickup input
	if player_in_range and Input.is_action_just_pressed("pickup"):
		pickup()
	
func _on_body_entered(body: Node2D):
	if body.name == "Player":
		player_in_range = true
		sprite_default.visible = false
		sprite_highlight.visible = true
	
func _on_body_exited(body: Node2D):
	if body.name == "Player":
		player_in_range = false
		sprite_default.visible = true
		sprite_highlight.visible = false
	
func pickup():
	GameManager.add_item(item_data)
	queue_free()
