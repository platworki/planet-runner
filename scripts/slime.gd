extends CharacterBody2D

const SPEED = 30
var HEALTH = 60
var DAMAGE = 10
var direction = 1
var knockback_force = 60.0
var is_knocked_back = false
var is_invincible = false

@onready var ray_cast_right_wall: RayCast2D = $Raycasts/RayCastRightWall
@onready var ray_cast_left_wall: RayCast2D = $Raycasts/RayCastLeftWall
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slime_hitbox: CollisionShape2D = $SlimeHitbox/CollisionShape2D
@onready var invincibility: Timer = $Invincibility

func _physics_process(delta: float) -> void:
	if HEALTH <= 0:
		direction = 0
		return
	# If currently in knockback, slowly reduce it
	if is_knocked_back:
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		if abs(velocity.x) < 5:
			is_knocked_back = false
	else:
		# Normal patrol logic
		if ray_cast_right_wall.is_colliding():
			direction = -1
			animated_sprite.flip_h = true
		elif ray_cast_left_wall.is_colliding():
			direction = 1
			animated_sprite.flip_h = false
		velocity.x = direction * SPEED

	move_and_slide()
func _on_invincibility_timeout() -> void:
	is_invincible = false

func take_damage(damage: int, attacker_position: Vector2):
	if is_invincible:
		return
	HEALTH -= damage
	print("Slime has ", HEALTH, " HP left!")

	# Play damage animation
	animated_sprite.play("damage")
	invincibility.start()
	is_invincible = true
	# Compute knockback direction (opposite to attacker)
	if attacker_position != Vector2.ZERO:
		var knock_dir = sign(global_position.x - attacker_position.x)
		velocity.x = knock_dir * knockback_force
		is_knocked_back = true

	if HEALTH <= 0:
		die()
	else:
		await get_tree().create_timer(0.2).timeout
		animated_sprite.play("default")

func die():
	slime_hitbox.set_deferred("disabled", true)
	animated_sprite.play("death")
	direction = 0
	await get_tree().create_timer(1.0).timeout
	queue_free()
