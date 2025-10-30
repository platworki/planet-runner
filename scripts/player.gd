extends CharacterBody2D

# ======================
# === CONFIGURATION ====
# ======================
const SPEED = 100.0
const JUMP_VELOCITY = -175.0
const GRAVITY_RISING = 330.0
const GRAVITY_FALLING = 500.0
const JUMP_CUT_MULTIPLIER = 0.2
const DASH_SPEED = 250.0
const DASH_DECAY = 800.0
const MAX_VELOCITY = 250.0

enum State {
	NORMAL,
	DASHING,
	KNOCKED_BACK,
	ATTACKING
}

var current_state = State.NORMAL

var DAMAGE = 10
var HEALTH = 100
var knockback_force = 150
var up_knockback_velocity = -120

var is_dashing = false
var dash_cooldown_active = false
var is_knocked_back = false
var is_invincible = false
var has_air_dash = true
var dash_jump_buffer_active = false

# ======================
# === NODE REFERENCES ==
# ======================
@onready var flip: Node2D = $Position
@onready var animated_sprite: AnimatedSprite2D = $Position/AnimatedSprite2D
@onready var attack_cooldown: Timer = $Position/PlayerAttack/AttackCooldown
@onready var attack_hit_animation: AnimationPlayer = $Position/PlayerAttack/AttackHit
@onready var side_attack_hitbox: CollisionShape2D = $Position/PlayerAttack/SideAttackHitbox
@onready var attack_sprite: Sprite2D = $Position/PlayerAttack/AttackSprite
@onready var coyote_time: Timer = $Position/CoyoteTime
@onready var jump_buffer: Timer = $Position/JumpBuffer
@onready var dash_timer: Timer = $Position/DashTimer
@onready var dash_cooldown_timer: Timer = $Position/DashCooldown
@onready var knockback_time: Timer = $Position/KnockbackTime
@onready var invincibility: Timer = $Position/Invincibility
@onready var player_body: CollisionShape2D = $PlayerBody
@onready var dash_jump_buffer: Timer = $Position/DashJumpBuffer

# ======================
# ===== MAIN LOOP ======
# ======================

func _physics_process(delta: float) -> void:
	# DEPRECATED 
	#	if is_knocked_back:
		#handle_knockback(delta)
		#return
#
	#handle_dash(delta)
	#handle_attack()
	#handle_jump_and_gravity(delta)
	#handle_horizontal_movement()
	#apply_velocity()
	
	match current_state:
		State.NORMAL:
			# INFO If the player presses dash and can dash, go into dashing
			if Input.is_action_just_pressed("dash") and has_air_dash and not dash_cooldown_active:
				current_state = State.DASHING
			if Input.is_action_just_pressed("attack") and attack_cooldown.is_stopped():
				current_state = State.ATTACKING
			handle_jump()
			handle_horizontal_movement()
			gravity(delta)
		State.DASHING:
			# INFO If the player is dashing right now, don't start a dash again
			if not is_dashing:
				dash()
			# INFO If you press jump during a dash, start the jump buffer
			if Input.is_action_just_pressed("jump"):
				dash_jump_buffer.start()
			# INFO Smoothly move towards a stop for a DASH_DECAY * delta amount of time
			velocity.x = move_toward(velocity.x, 0, DASH_DECAY * delta)
		State.ATTACKING:
			# INFO Turn on the hitboxes and sprite
			attack()
			# INFO Return back to normal immediately which allows for movement
			current_state = State.NORMAL
		State.KNOCKED_BACK:
			handle_knockback(delta)
	move_and_slide()
	
# ======================
# ====== JUMPING =======
# ======================

func handle_jump() -> void:
	# INFO If the player is falling at max velocity, keep it like that
	if velocity.y >= MAX_VELOCITY:
		velocity.y = MAX_VELOCITY
	# INFO Reset air dash when the player is on the floor
	if is_on_floor() and not has_air_dash:
		has_air_dash = true
		
	if Input.is_action_just_pressed("jump"):
		# TODO If pressing jump during dash, set dash jump buffer
		#if is_dashing and is_on_floor():
			#dash_jump_buffer_active = true
			#dash_jump_buffer.start()
			#return
		# INFO If the player is either on the floor or during coyote time, allow them to jump
		if is_on_floor() or not coyote_time.is_stopped():
			dash_cooldown_timer.stop()
			dash_cooldown_active = false
			velocity.y = JUMP_VELOCITY
			coyote_time.stop()
			jump_buffer.stop()
		else:
			jump_buffer.start()
			
	# INFO If the jump buffer is running and you reach the floor, jump
	if not jump_buffer.is_stopped() and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_buffer.stop()
		coyote_time.stop()

	# INFO If player stops holding space during a jump and going up, cut their jump velocity
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER
	
# ======================
# ===== HORIZONTAL =====
# ======================

func handle_horizontal_movement() -> void:
	var direction = Input.get_axis("move_left", "move_right")

	if direction > 0:
		flip.scale.x = 1
	elif direction < 0:
		flip.scale.x = -1
	# INFO If the player is on floor, play idle or running, if the player is jumping or falling play jump
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("Idle")
		else:
			animated_sprite.play("Run")
	else:
		animated_sprite.play("Jumping")
	# INFO If the input is either A or D, move, otherwise stop smoothly
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
# ======================
# ====== GRAVITY =======
# ======================

func gravity(delta: float) -> void:
	# INFO If the player is not on the floor, add gravity
	if not is_on_floor():
		# INFO If player is going up, slowly decrease the players velocity
		if velocity.y < 0:
			velocity.y += GRAVITY_RISING * delta
		# INFO If the player is going down, slowly increase the players velocity
		else:
			velocity.y += GRAVITY_FALLING * delta
	# INFO If the player is on the floor, repeatedly start coyote time so when eventually
	# going off the platform they get the full coyote timer
	else:
		coyote_time.start()
		

# ======================
# ======== DASH ========
# ======================	

func dash() -> void:
	is_dashing = true
	animated_sprite.play("Jumping")
	# INFO Stop any ongoing attack
	cancel_attack()
	# INFO Actually dash
	velocity.x = DASH_SPEED * flip.scale.x * 1.2
	velocity.y = 0
	dash_cooldown_active = true
	dash_timer.start()
	dash_cooldown_timer.start()
	# INFO Consume air dash if used in air
	if not is_on_floor():
		has_air_dash = false
		
func _on_dash_timeout() -> void:
	is_dashing = false
	# INFO If the player has pressed jump during a dash beforehand and is still holding it, jump
	if not dash_jump_buffer.is_stopped() and is_on_floor():
		if Input.is_action_pressed("jump"):
			velocity.y = JUMP_VELOCITY
		dash_jump_buffer.stop()
	# INFO When dash ends, return back to the normal state
	if not is_knocked_back:
		current_state = State.NORMAL

func _on_dash_cooldown_timeout() -> void:
	dash_cooldown_active = false
	
func _on_knockback_time_timeout() -> void:
	is_knocked_back = false
	current_state = State.NORMAL

func _on_invincibility_timeout() -> void:
	is_invincible = false
	
func _on_dash_jump_buffer_timeout() -> void:
	dash_jump_buffer_active = false

# ======================
# ====== ATTACKS =======
# ======================

# DEPRECATED 
# func handle_attack() -> void:
	#if Input.is_action_just_pressed("attack") and attack_delay.is_stopped() and not is_dashing and not is_knocked_back:
		#attack()

func attack() -> void:
	# INFO If you attack during invincibility, turn invincibility off to prevent enemy tanking
	if is_invincible:
		is_invincible = false
	attack_cooldown.start()
	attack_hit_animation.play("Attack")

func cancel_attack() -> void:
	attack_hit_animation.stop()
	attack_cooldown.stop()
	side_attack_hitbox.disabled = true
	attack_sprite.visible = false

# ======================
# ===== KNOCKBACK ======
# ======================

func handle_knockback(delta: float) -> void:
	# INFO Smooth out the knockback easing in on 0
	velocity.x = move_toward(velocity.x, 0, 400 * delta)
	# INFO Go up smoothly instead of a fixed elevator up
	velocity.y += GRAVITY_FALLING * delta
	
# DEPRECATED
# ======================
# ===== APPLY MOVE =====
# ======================

#func apply_velocity() -> void:
	#if not is_dashing:
		#move_and_slide()

# ======================
# ====== DAMAGE ========
# ======================

func take_damage(enemy_damage: int, enemy_position: Vector2):
	if is_invincible:
		return
		
	HEALTH -= enemy_damage
	if HEALTH <= 0:
		die()
		return

	print("You have ", HEALTH, " left!")
	animated_sprite.play("Damage")
	# INFO Pass the knockback smoothing to the State methods
	current_state = State.KNOCKED_BACK
	# INFO Calculate the hit direction, then add the non-smoothed value for knockback distance
	var knock_dir = sign(global_position.x - enemy_position.x)
	velocity.x = knock_dir * knockback_force
	velocity.y = up_knockback_velocity
	
	is_dashing = false
	is_knocked_back = true
	is_invincible = true
	has_air_dash = true
	
	invincibility.start()
	knockback_time.start()
	
func die():
	print("You died!")
	Engine.time_scale = 0.5
	set_physics_process(false)
	animated_sprite.play("Death")
	player_body.set_deferred("disabled", true)
	await get_tree().create_timer(1.0).timeout
	Engine.time_scale = 1
	is_dashing = false
	is_knocked_back = false
	is_invincible = false
	dash_cooldown_active = false
	has_air_dash = true
	get_tree().reload_current_scene()
