extends CharacterBody2D

enum State {
	PATROL,
	CHASE,
	ATTACK,
	EDGE_LOOK
}

var current_state = State.PATROL
var player_target = null

const SPEED = 50
const CHASE_SPEED = 80
const GRAVITY = 500.0
const JUMP_KNOCKBACK = -65  
const LUNGE_SPEED = 245
const LUNGE_FRICTION = 600  

var HEALTH = 60
var DAMAGE = 10
var direction = 1
var knockback_force = 85.0
var is_knocked_back = false
var is_invincible = false

@onready var raycast_right_wall: RayCast2D = $Raycasts/RaycastRightWall
@onready var raycast_left_wall: RayCast2D = $Raycasts/RaycastLeftWall
@onready var raycast_left_air: RayCast2D = $Raycasts/RaycastLeftAir
@onready var raycast_right_air: RayCast2D = $Raycasts/RaycastRightAir
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slime_hitbox: CollisionShape2D = $SlimeHitbox/CollisionShape2D
@onready var invincibility: Timer = $Invincibility
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var ignore_player_timer: Timer = $IgnorePlayerTimer

@onready var slime_hit_sfx: AudioStreamPlayer = $SFX

func _physics_process(delta: float) -> void:
	if HEALTH <= 0:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if is_knocked_back:
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		if abs(velocity.x) < 5 and is_on_floor():
			is_knocked_back = false
		move_and_slide()
		return

	match current_state:
		State.PATROL:
			patrol()
			if ignore_player_timer.is_stopped() and player_target != null:
				current_state = State.CHASE
		State.CHASE:
			chase_player()
		State.ATTACK:
			# Friction
			velocity.x = move_toward(velocity.x, 0, LUNGE_FRICTION * delta)
		State.EDGE_LOOK:
			velocity.x = 0 # Stand completely still
			# If the player moves behind the slime, snap back to Chase!
			if player_target != null:
				var dir_to_player = sign(player_target.global_position.x - global_position.x)
				if dir_to_player != direction: # 'direction' is where the slime is looking
					current_state = State.CHASE
	move_and_slide()

# ======================
# ====== STATES ========
# ======================

func patrol():
	animated_sprite.speed_scale = 1.0
	if animated_sprite.animation != "walk":
		animated_sprite.play("walk")
		
	if animated_sprite.frame >= 3 and animated_sprite.frame <= 6:
		velocity.x = direction * SPEED
	else:
		velocity.x = 0
		# Turn around logic only happens here
		if raycast_right_wall.is_colliding() or not raycast_right_air.is_colliding():
			direction = -1
		elif raycast_left_wall.is_colliding() or not raycast_left_air.is_colliding():
			direction = 1
		
		# Update the visual flip only while standing still
		animated_sprite.flip_h = (direction > 0)
		
func chase_player():
	animated_sprite.speed_scale = 1.2
	if player_target == null:
		current_state = State.PATROL
		return
	
	# Determine where the player is
	var direction_to_player = sign(player_target.global_position.x - global_position.x)
	
	# MOVING PHASE
	if animated_sprite.frame >= 3 and animated_sprite.frame <= 6:
		velocity.x = direction * CHASE_SPEED
	# STATIONARY PHASE
	else:
		velocity.x = 0
		# Only update 'direction' and 'flip' while stationary
		direction = direction_to_player
		animated_sprite.flip_h = (direction > 0)
		
		var edge_detected = false
		if direction > 0 and not raycast_right_air.is_colliding():
			edge_detected = true
		elif direction < 0 and not raycast_left_air.is_colliding():
			edge_detected = true

		if edge_detected:
			start_edge_look()
			return

	if animated_sprite.animation != "walk":
		animated_sprite.play("walk")
	
	# Attack check can stay outside since it transitions states entirely
	var distance = global_position.distance_to(player_target.global_position)
	if distance < 50 and attack_cooldown.is_stopped() and is_on_floor():
		start_attack()

# ======================
# ====== ACTIONS =======
# ======================

func start_edge_look():
	animated_sprite.speed_scale = 1.0
	current_state = State.EDGE_LOOK
	animated_sprite.play("walk")
	
	# Wait for 1.5 seconds looking at the edge
	await get_tree().create_timer(1.5).timeout
	if current_state != State.EDGE_LOOK:
		return # If the player leaves the range, return out of edge

	await animated_sprite.animation_looped
	# Turn around, walk away, and ignore the player for 1.5 seconds
	direction *= -1
	ignore_player_timer.start(1.5)
	current_state = State.PATROL

func start_attack():
	animated_sprite.speed_scale = 1.0
	current_state = State.ATTACK
	velocity.x = 0

	await get_tree().create_timer(0.3).timeout
	if current_state != State.ATTACK: 
		return
	
	# LUNGE BURST! (_physics_process handles the sliding friction)
	animated_sprite.play("attack") 
	velocity.x = direction * LUNGE_SPEED
	
	attack_cooldown.start()
	if HEALTH <= 0: return
	
	await animated_sprite.animation_finished
	# After attack, look around: is the player still here?
	if player_target != null:
		current_state = State.CHASE
	else:
		current_state = State.PATROL

# ======================
# ====== SIGNALS =======
# ======================

func _on_detection_range_body_entered(body):
	if body.name == "Player":
		player_target = body
		# Instantly chase unless we are currently walking away from an edge
		if ignore_player_timer.is_stopped() and current_state == State.PATROL:
			current_state = State.CHASE

func _on_detection_range_body_exited(body):
	if body.name == "Player":
		player_target = null

func _on_invincibility_timeout() -> void:
	is_invincible = false

# ======================
# ====== DAMAGE ========
# ======================

func take_damage(damage: int, attacker_position: Vector2):
	if is_invincible: return
	
	HEALTH -= damage
	animated_sprite.play("damage")
	print("Slime has ", HEALTH, " HP left!")
	
	slime_hit_sfx.pitch_scale = randf_range(0.8,1.1)
	slime_hit_sfx.play()
	
	invincibility.start()
	is_invincible = true

	if attacker_position != Vector2.ZERO:
		var knock_dir = sign(global_position.x - attacker_position.x)
		velocity.x = knock_dir * knockback_force
		velocity.y = JUMP_KNOCKBACK 
		is_knocked_back = true

		current_state = State.CHASE

	if HEALTH <= 0:
		die()
	else:
		await get_tree().create_timer(invincibility.wait_time).timeout
		if HEALTH > 0 and animated_sprite.animation == "damage":
			animated_sprite.play("walk")

func die():
	GameManager.add_currency(5)
	print("5 currency added.")
	slime_hitbox.set_deferred("disabled", true)
	animated_sprite.play("death")
	direction = 0
	await get_tree().create_timer(1.0).timeout
	queue_free()
