extends CharacterBody2D

var item_data = {}
var is_display_only = false
var player_in_range = false
var can_pickup = false
var item_id = ""

@onready var sprite_default: Sprite2D = $SpriteDefault
@onready var sprite_highlight: Sprite2D = $SpriteHighlight
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_sfx: AudioStreamPlayer = $Pickup
@onready var item: CharacterBody2D = $"."

func _ready() -> void:
	# FIXED: Grab the "id" instead of the "name"
	if item_data.has("id"):
		item_id = item_data["id"]
	
	if item_data.has("sprite_default"):
		sprite_default.texture = load(item_data.sprite_default)
	if item_data.has("sprite_highlight"):
		sprite_highlight.texture = load(item_data.sprite_highlight)
	
	sprite_default.visible = true
	sprite_highlight.visible = false

func _physics_process(delta: float) -> void:
	if is_display_only:
		return
	if not is_on_floor():
		velocity.y += 500 * delta
		if velocity.y > 0:
			z_index = 8
	else:
		velocity = Vector2(0,0)
		can_pickup = true
	move_and_slide()
	
	if player_in_range and Input.is_action_just_pressed("pickup") and can_pickup and not is_display_only:
		if GameManager.is_item_maxed(item_id):
			print("Cannot pickup: Already reached max stacks for ", item_id)
			# Optional: Add a 'locked' sound effect here
			return
		
		pickup()
		set_physics_process(false)
	
func _on_body_entered(body: Node2D):
	if body.name == "Player":
		player_in_range = true
		if not is_display_only:
			set_highlight(true)
	
func _on_body_exited(body: Node2D):
	if body.name == "Player":
		player_in_range = false
		if not is_display_only:
			set_highlight(false)
		
func set_highlight(state: bool):
	sprite_default.visible = not state
	sprite_highlight.visible = state

func pickup():
	GameManager.add_item(item_id)
	pickup_sfx.pitch_scale = randf_range(0.7,0.9)
	pickup_sfx.play()
	item.visible = false
	await pickup_sfx.finished
	queue_free()
