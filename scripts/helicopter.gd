extends CharacterBody2D

enum State {
	IDLE,
	FOLLOW,
	ATTACK,
}

var current_state = State.IDLE
var player_target = null

const SPEED = 80
const ACCELERATION = 230
const FRICTION = 400
# How close horizontally it needs to be to shoot
const ATTACK_X_RANGE = 10

var HEALTH = 40
var DAMAGE = 10
var LASER_DAMAGE = 30
var knockback_force = 100.0
var is_invincible = false
var is_knocked_back = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var helicopter_hitbox: CollisionShape2D = $HelicopterHitbox/CollisionShape2D
@onready var invincibility: Timer = $Invincibility
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var heli_hit_sfx: AudioStreamPlayer = $HeliHit
@onready var heli_attack_sfx: AudioStreamPlayer = $HeliAttack
@onready var heli_noise_sfx: AudioStreamPlayer = $HeliNoise
@onready var laser_collision: CollisionShape2D = $AttackRadius/LaserCollision

func _physics_process(delta: float) -> void:
	if HEALTH <= 0:
		return
		
	if is_knocked_back:
		velocity = velocity.move_toward(Vector2.ZERO, 200 * delta)
		if velocity.length() < 5:
			is_knocked_back = false
		move_and_slide()
		return
		
	match current_state:
		State.IDLE:
			idle(delta)
		State.FOLLOW:
			follow_player(delta)
		State.ATTACK:
			attack_logic(delta)
			
	move_and_slide()

# ======================
# ====== STATES ========
# ======================

func idle(delta):
	# Smooth stop
	velocity = velocity.move_toward(Vector2.ZERO, (FRICTION/10.0 * delta))
	
	if animated_sprite.animation != "move":
		animated_sprite.play("move")
		
func follow_player(delta):
	if player_target == null:
		current_state = State.IDLE
		return
		
	if animated_sprite.animation != "move":
		animated_sprite.play("move")
		
	# 1. Target the exact hover position
	var target_position = Vector2(player_target.global_position.x, player_target.global_position.y)
	
	# 2. Check for Attack conditions
	var x_dist = abs(global_position.x - target_position.x)
	var y_dist = abs(global_position.y - target_position.y)
	
	# 3. Smooth Diagonal Movement
	var dir_to_target = global_position.direction_to(target_position)
	if x_dist > 5:
		velocity = velocity.move_toward(dir_to_target * SPEED, ACCELERATION * delta)
	
	# Face the correct direction
	if dir_to_target.x != 0:
		animated_sprite.flip_h = dir_to_target.x > 0
	
	# If we are aligned horizontally AND at the exact right height...
	if x_dist <= ATTACK_X_RANGE and y_dist < 0.4 and attack_cooldown.is_stopped():
		# Only attack if the player is actually on the ground so the laser doesn't clip!
		if player_target.has_method("is_on_floor") and player_target.is_on_floor():
			current_state = State.ATTACK

func attack_logic(delta):
	# Stay perfectly still while attacking
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	
	# Ensure the animation and await only trigger once per cycle
	if animated_sprite.animation != "attack":
		animated_sprite.play("attack")
		
		await animated_sprite.animation_finished
		if HEALTH <= 0: return
		
		# FORCE DISABLE at end of animation just in case
		laser_collision.disabled = true
		
		attack_cooldown.start()
		current_state = State.FOLLOW

# ======================
# ====== SIGNALS =======
# ======================

func _on_animated_sprite_2d_frame_changed() -> void:
	if animated_sprite.animation == "attack":
		if animated_sprite.frame >= 3 and animated_sprite.frame <= 7:
			if not heli_attack_sfx.playing:
				heli_attack_sfx.pitch_scale = randf_range(0.9,1.8)
				heli_attack_sfx.play(0.1)
			# Use set_deferred to ensure the physics engine sees the change
			laser_collision.set_deferred("disabled", false)
		else:
			laser_collision.set_deferred("disabled", true)
	else:
		laser_collision.set_deferred("disabled", true)

# Keep the FOLLOW radius, but DELETE the ATTACK radius Area2D. We don't need it anymore.
func _on_follow_radius_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_target = body
		current_state = State.FOLLOW

func _on_follow_radius_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_target = null
		current_state = State.IDLE

func _on_invincibility_timeout() -> void:
	is_invincible = false

# ======================
# ====== DAMAGE ========
# ======================

func take_damage(damage: int, attacker_position: Vector2):
	if is_invincible: 
		return
	
	HEALTH -= damage
	heli_hit_sfx.pitch_scale = randf_range(0.8, 1.0)
	heli_hit_sfx.play()
	
	invincibility.start()
	is_invincible = true
	if attacker_position != Vector2.ZERO:
		var knock_dir = (helicopter_hitbox.global_position - attacker_position).normalized()
		# Apply knockback in both axes
		velocity = knock_dir * knockback_force
		is_knocked_back = true
	if HEALTH <= 0:
		die()

func die():
	GameManager.add_currency(5)
	helicopter_hitbox.set_deferred("disabled", true)
	animated_sprite.play("death")
	
	await get_tree().create_timer(1.0).timeout
	queue_free()
