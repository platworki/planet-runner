extends Area2D

const SPEED = 350
var direction = Vector2.ZERO
var damage = 25
var is_flying = false
var hit_detected = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:	
	if not hit_detected:
		is_flying = true
		animated_sprite.play("projectileFlight")

func _physics_process(delta: float) -> void:
	if is_flying and not hit_detected:
		position += direction * SPEED * delta

func _on_body_entered(body: Node2D) -> void:
	if hit_detected: 
		return
	if body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		trigger_hit()
	elif body.is_in_group("Environment"):
		trigger_hit()

func trigger_hit():
	# Stop moving, play hit animation, then delete
	hit_detected = true
	is_flying = false
	animated_sprite.play("projectileHit")
	await animated_sprite.animation_finished
	queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	print("projectile removed")
	queue_free()
