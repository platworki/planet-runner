extends CharacterBody2D

# ======================
# === CONFIGURATION ====
# ======================
const SPEED = 100.0
const JUMP_VELOCITY = -175.0
const GRAVITY_RISING = 330.0
const GRAVITY_FALLING = 500.0
const JUMP_CUT_MULTIPLIER = 0.2
const DASH_SPEED = 190.0
const DASH_DECAY = 200.0
const MAX_VELOCITY = 250

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
@onready var attack_delay: Timer = $Position/PlayerAttack/AttackDelay
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
	if is_knocked_back:
		handle_knockback(delta)
		return

	handle_dash(delta)
	handle_attack()
	handle_jump_and_gravity(delta)
	handle_horizontal_movement()
	apply_velocity()

# ======================
# ====== ATTACKS =======
# ======================
func handle_attack() -> void:
	if Input.is_action_just_pressed("attack") and attack_delay.is_stopped() and not is_dashing and not is_knocked_back:
		attack()

func attack() -> void:
	if is_invincible:
		is_invincible = false
	attack_delay.start()
	attack_hit_animation.play("Attack")

func cancel_attack() -> void:
	attack_hit_animation.stop()
	attack_delay.stop()
	side_attack_hitbox.disabled = true
	attack_sprite.visible = false
	

# ======================
# ======== DASH ========
# ======================
func handle_dash(delta: float) -> void:
	if is_knocked_back:
		return

	# Only allow dash if on ground OR have air dash available
	if Input.is_action_just_pressed("dash") and not is_dashing and not dash_cooldown_active:
		if is_on_floor() or has_air_dash:
			start_dash()

	if is_dashing:
		animated_sprite.play("Jumping")
		move_and_slide()
		velocity.x = move_toward(velocity.x, 0, DASH_DECAY * delta)


func start_dash() -> void:
	cancel_attack()
	velocity.x = DASH_SPEED * flip.scale.x * 1.2
	velocity.y = 0
	is_dashing = true
	dash_cooldown_active = true
	dash_timer.start()
	dash_cooldown_timer.start()
	
	# Consume air dash if used in air
	if not is_on_floor():
		has_air_dash = false
		
func _on_dash_timeout() -> void:
	is_dashing = false
	if dash_jump_buffer_active:
		if Input.is_action_pressed("jump"):
			velocity.y = JUMP_VELOCITY
		dash_jump_buffer_active = false
		dash_jump_buffer.stop()

func _on_dash_cooldown_timeout() -> void:
	dash_cooldown_active = false
	
func _on_knockback_time_timeout() -> void:
	is_knocked_back = false

func _on_invincibility_timeout() -> void:
	is_invincible = false
	
func _on_dash_jump_buffer_timeout() -> void:
	dash_jump_buffer_active = false

# ======================
# === JUMP & GRAVITY ===
# ======================
func handle_jump_and_gravity(delta: float) -> void:
	if velocity.y >= MAX_VELOCITY:
		velocity.y = MAX_VELOCITY
	# Reset air dash AND dash cooldown when landing
	if is_on_floor():
		if not has_air_dash:
			has_air_dash = true
	# Gravity
	if not is_on_floor() and not is_dashing:
		if velocity.y < 0:
			velocity.y += GRAVITY_RISING * delta
		else:
			velocity.y += GRAVITY_FALLING * delta
	elif is_on_floor():
		coyote_time.start()

	# Jump pressed
	if Input.is_action_just_pressed("jump"):
		if is_knocked_back:
			return
		# If pressing jump during dash, set jump buffer
		if is_dashing and is_on_floor():
			dash_jump_buffer_active = true
			dash_jump_buffer.start()
			return
		if is_on_floor() or not coyote_time.is_stopped():
			dash_cooldown_timer.stop()
			dash_cooldown_active = false
			velocity.y = JUMP_VELOCITY
			coyote_time.stop()
			jump_buffer.stop()
		else:
			jump_buffer.start()

	# Buffered jump
	if not jump_buffer.is_stopped() and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_buffer.stop()
		coyote_time.stop()

	# Short hop
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER

# ======================
# ===== HORIZONTAL =====
# ======================
func handle_horizontal_movement() -> void:
	if is_dashing or is_knocked_back:
		return

	var direction = Input.get_axis("move_left", "move_right")

	if direction > 0:
		flip.scale.x = 1
	elif direction < 0:
		flip.scale.x = -1

	if is_on_floor():
		if direction == 0:
			animated_sprite.play("Idle")
		else:
			animated_sprite.play("Run")
	else:
		animated_sprite.play("Jumping")

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

# ======================
# ==== KNOCKBACK =======
# ======================
func handle_knockback(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 400 * delta)
	velocity.y += GRAVITY_FALLING * delta
	move_and_slide()

# ======================
# ===== APPLY MOVE =====
# ======================
func apply_velocity() -> void:
	if not is_dashing:
		move_and_slide()

# ======================
# ===== DAMAGE =========
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
