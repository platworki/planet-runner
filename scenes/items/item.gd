extends CharacterBody2D

var item_data = {}
var player_in_range = false
var can_pickup = false

@onready var sprite_default: Sprite2D = $SpriteDefault
@onready var sprite_highlight: Sprite2D = $SpriteHighlight
@onready var pickup_area: Area2D = $PickupArea

func _ready() -> void:
	if item_data.has("sprite_default"):
		sprite_default.texture = load(item_data.sprite_default)
	if item_data.has("sprite_highlight"):
		sprite_highlight.texture = load(item_data.sprite_highlight)
	
	sprite_default.visible = true
	sprite_highlight.visible = false
	
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 500 * delta
		if velocity.y > 0:
			z_index = 6
	else:
		velocity = Vector2(0,0)
		can_pickup = true
	move_and_slide()
	
	if player_in_range and Input.is_action_just_pressed("pickup") and can_pickup:
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
