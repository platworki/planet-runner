extends CharacterBody2D

enum State {
	PATROL,
	CHASE,
	ATTACK,
	EDGE_LOOK # Added this to cleanly handle the 2-second wait
}

var current_state = State.PATROL
var player_target = null

const SPEED = 30
const CHASE_SPEED = 60
const GRAVITY = 500.0
const JUMP_KNOCKBACK = -65  
const LUNGE_SPEED = 220  
const LUNGE_FRICTION = 600  

var HEALTH = 60
var DAMAGE = 10
var direction = 1
var knockback_force = 55.0
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

	# The Actual State Machine
	match current_state:
		State.PATROL:
			patrol()
			# If we are done ignoring the player and they are still here, chase!
			if ignore_player_timer.is_stopped() and player_target != null:
				current_state = State.CHASE
		State.CHASE:
			chase_player()
		State.ATTACK:
			# Just apply friction. The lunge burst happens in start_attack()
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
	if raycast_right_wall.is_colliding() or not raycast_right_air.is_colliding():
		direction = -1
	elif raycast_left_wall.is_colliding() or not raycast_left_air.is_colliding():
		direction = 1

	animated_sprite.flip_h = (direction < 0)
	velocity.x = direction * SPEED
	
	if animated_sprite.animation != "default":
		animated_sprite.play("default")

func chase_player():
	if player_target == null:
		current_state = State.PATROL
		return

	var direction_to_player = sign(player_target.global_position.x - global_position.x)

	# 1. Check for Edges First
	var edge_detected = false
	if direction_to_player > 0 and not raycast_right_air.is_colliding():
		edge_detected = true
	elif direction_to_player < 0 and not raycast_left_air.is_colliding():
		edge_detected = true

	if edge_detected:
		start_edge_look()
		return

	# 2. Normal Chase
	direction = direction_to_player
	animated_sprite.flip_h = (direction < 0)
	velocity.x = direction * CHASE_SPEED
	
	if animated_sprite.animation != "default":
		animated_sprite.play("default")

	# 3. Check for Attack
	var distance = global_position.distance_to(player_target.global_position)
	if distance < 30 and attack_cooldown.is_stopped() and is_on_floor():
		start_attack()

# ======================
# ====== ACTIONS =======
# ======================

func start_edge_look():
	current_state = State.EDGE_LOOK
	animated_sprite.play("default")
	
	# Wait for 1.5 seconds looking at the edge
	await get_tree().create_timer(1.5).timeout
	if current_state != State.EDGE_LOOK:
		return # Safety check

	# Turn around, walk away, and ignore the player for 1.5 seconds
	direction *= -1
	ignore_player_timer.start(1.5)
	current_state = State.PATROL

func start_attack():
	current_state = State.ATTACK
	velocity.x = 0
	animated_sprite.play("damage") # Windup animation
	
	await get_tree().create_timer(0.3).timeout
	if current_state != State.ATTACK: 
		return

	# LUNGE BURST! (_physics_process handles the sliding friction)
	animated_sprite.play("death") 
	velocity.x = direction * LUNGE_SPEED
	
	#can_attack = false
	attack_cooldown.start()

	await animated_sprite.animation_finished
	if HEALTH <= 0: return

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
	# FIX: Clear the target, but DON'T force a state change. 
	# The state machine will naturally go to PATROL when it realizes player_target is null.
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
	print("Slime has ", HEALTH, " HP left!")

	animated_sprite.play("damage")
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
			animated_sprite.play("default")

func die():
	slime_hitbox.set_deferred("disabled", true)
	animated_sprite.play("death")
	direction = 0
	await get_tree().create_timer(1.0).timeout
	queue_free()
