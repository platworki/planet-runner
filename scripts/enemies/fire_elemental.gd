extends CharacterBody2D

enum State {
	PATROL,
	RANGED,
	MELEE
}

var current_state = State.PATROL
var player_target = null

# Sensor variables to fix the "await" lockup bug
var player_in_ranged = false
var player_in_melee = false
var is_attacking = false

const SPEED = 22 # Slow walk
const FRICTION = 400
const GRAVITY = 500.0
const JUMP_KNOCKBACK = -45  

var HEALTH = 100
var DAMAGE = 20
var MELEE_DAMAGE = 25
var direction = 1
var knockback_force = 60.0
var is_knocked_back = false
var is_invincible = false

@export var fireball_scene: PackedScene

# Explicit references. No in-code $ calls.
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var invincibility: Timer = $Invincibility
@onready var fireball_spawn: Marker2D = $FireballSpawn

@onready var ranged_cooldown: Timer = $RangedCooldown
@onready var melee_cooldown: Timer = $MeleeCooldown

@onready var elemental_hitbox: CollisionShape2D = $FireEHitbox/CollisionShape2D
@onready var melee_damage_hitbox: CollisionShape2D = $MeleeArea/MeleeHitbox

@onready var ray_right_wall: RayCast2D = $Raycasts/RaycastRightWall
@onready var ray_left_wall: RayCast2D = $Raycasts/RaycastLeftWall
@onready var ray_right_air: RayCast2D = $Raycasts/RaycastRightAir
@onready var ray_left_air: RayCast2D = $Raycasts/RaycastLeftAir

func _physics_process(delta: float) -> void:
	if HEALTH <= 0: 
		return

	# Slime Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Slime Knockback
	if is_knocked_back:
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		if abs(velocity.x) < 5 and is_on_floor():
			is_knocked_back = false
		#move_and_slide()
		#return

	# HARD LOCK: If an attack animation is currently playing, don't change states or move.
	if is_attacking:
		if not is_knocked_back:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		move_and_slide()
		return

	# CONTINUOUS STATE EVALUATION: No more signal race conditions.
	if player_in_melee:
		current_state = State.MELEE
	elif player_in_ranged:
		current_state = State.RANGED
	else:
		current_state = State.PATROL

	match current_state:
		State.PATROL:
			patrol()
		State.RANGED:
			ranged_attack(delta)
		State.MELEE:
			melee_attack(delta)
			
	move_and_slide()

# ======================
# ====== STATES ========
# ======================
func update_direction_visuals():
	animated_sprite.flip_h = (direction > 0) # Flip if looking left
	# Move the fireball spawn point to the correct side manually
	# Adjust the 20 to whatever the offset of your marker is
	fireball_spawn.position.x = abs(fireball_spawn.position.x) * direction
	
func patrol():
	if animated_sprite.animation != "walk":
		animated_sprite.play("walk")
		
	velocity.x = direction * SPEED
	
	if ray_right_wall.is_colliding() or not ray_right_air.is_colliding():
		direction = -1
	elif ray_left_wall.is_colliding() or not ray_left_air.is_colliding():
		direction = 1
		
	update_direction_visuals()

func ranged_attack(delta):
	# --- 1. HANDLE MOVEMENT BETWEEN SHOTS ---
	if not is_attacking:
		if player_target:
			# Determine direction to player
			var dir_to_player = sign(player_target.global_position.x - global_position.x)
			if dir_to_player != 0:
				direction = dir_to_player
				update_direction_visuals()

			# LEDGE PROTECTION: Only move if there is floor ahead
			var can_move = false
			if direction > 0 and ray_right_air.is_colliding() and not ray_right_wall.is_colliding():
				can_move = true
			elif direction < 0 and ray_left_air.is_colliding() and not ray_left_wall.is_colliding():
				can_move = true

			if can_move and not player_in_melee:
				velocity.x = direction * SPEED*1.3
				if animated_sprite.animation != "walk":
					animated_sprite.play("walk")
			else:
				# Stop at edge or if already in melee range
				velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
				if animated_sprite.animation != "walk":
					animated_sprite.play("walk")
	else:
		# Stay still while actually in the shoot animation
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	# --- 2. SHOOT LOGIC ---
	if ranged_cooldown.is_stopped() and not is_attacking and is_on_floor():
		if player_target: # Double check target exists before locking
			shoot()
			
func shoot():
	is_attacking = true
	animated_sprite.play("shoot")
	ranged_cooldown.start()
	
	# Wait for animation, but check if we should "snap out" of it
	# We use a loop or a specific check to see if target left
	await animated_sprite.animation_finished
	is_attacking = false
	
func melee_attack(delta):
	if player_target:
		var dir_to_player = sign(player_target.global_position.x - global_position.x)
		if dir_to_player != 0:
			direction = dir_to_player
			update_direction_visuals()
	
	velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	if melee_cooldown.is_stopped():
		is_attacking = true # Lock the state machine!
		animated_sprite.play("melee") 
		melee_cooldown.start()
		
		await animated_sprite.animation_finished
		is_attacking = false # Unlock the state machine!

# ======================
# ====== SIGNALS =======
# ======================

func _on_animated_sprite_2d_frame_changed() -> void:
	# --- RANGED ATTACK SPAWN ---
	if animated_sprite.animation == "shoot" and animated_sprite.frame == 11:
		if player_target:
			var fireball = fireball_scene.instantiate()
			fireball.global_position = fireball_spawn.global_position
			
			# Calculate direction vector and rotation
			# (Using your Vector2(0,-20) offset to aim at the chest/head)
			var dir = ((player_target.global_position + Vector2(0, -20)) - fireball_spawn.global_position).normalized()
			fireball.direction = dir
			fireball.rotation = dir.angle()
			get_parent().add_child(fireball)

	# --- MELEE HITBOX LOGIC ---
	if animated_sprite.animation == "melee":
		if animated_sprite.frame >= 8 and animated_sprite.frame <= 10:
			melee_damage_hitbox.set_deferred("disabled", false)
		else:
			melee_damage_hitbox.set_deferred("disabled", true)
	else:
		# Safety: Always disable melee hitbox if not in melee animation
		melee_damage_hitbox.set_deferred("disabled", true)

# Notice how the signals ONLY update the sensors now. No state switching here.
func _on_rangedradius_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_target = body
		player_in_ranged = true

# Update the signal to handle the "Snap to Idle/Walk" logic
func _on_rangedradius_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_ranged = false
		player_target = null
		ranged_cooldown.stop()
		# CANCEL ATTACK: If he was shooting and the player leaves, snap him out of it
		if is_attacking and animated_sprite.animation == "shoot":
			is_attacking = false
			animated_sprite.play("walk") # Snaps to walk/idle visuals immediately

func _on_meleeradius_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_target = body
		player_in_melee = true

func _on_meleeradius_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_melee = false

func _on_invincibility_timeout() -> void:
	is_invincible = false

# ======================
# ====== DAMAGE ========
# ======================

func take_damage(damage: int, attacker_position: Vector2):
	if is_invincible: return
	
	HEALTH -= damage
	if animated_sprite.animation != "melee":
		animated_sprite.play("damage") # Sorry Paul
	
	invincibility.start()
	is_invincible = true

	if attacker_position != Vector2.ZERO:
		var knock_dir = sign(global_position.x - attacker_position.x)
		velocity.x = knock_dir * knockback_force
		velocity.y = JUMP_KNOCKBACK 
		is_knocked_back = true

	if HEALTH <= 0:
		die()

func die():
	GameManager.add_currency(10)
	elemental_hitbox.set_deferred("disabled", true)
	animated_sprite.play("death")
	direction = 0
	await get_tree().create_timer(1.0).timeout
	queue_free()
