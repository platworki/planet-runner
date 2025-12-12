extends CharacterBody2D

# ======================
# === CONFIGURATION ====
# ======================

const SPEED = 140.0
const JUMP_VELOCITY = -230.0
const GRAVITY_RISING = 365.0
const GRAVITY_FALLING = 600.0
const JUMP_CUT_MULTIPLIER = 0.2
const DASH_SPEED = 300.0
const DASH_DECAY = 900.0
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
var attack_combo_count = 0  # Tracks which attack in combo

var is_dashing = false
var dash_cooldown_active = false
var is_knocked_back = false
var is_invincible = false
var has_air_dash = true
var has_double_jump = true
var is_attacking = false
var is_playing_attack_anim = false

# ======================
# === NODE REFERENCES ==
# ======================

@onready var flip: Node2D = $Position
@onready var torso_animation: AnimatedSprite2D = $Position/Torso
@onready var legs_animation: AnimatedSprite2D = $Position/Legs
@onready var attack_cooldown: Timer = $Position/PlayerAttack/AttackCooldown
@onready var attack_hit_animation: AnimationPlayer = $Position/PlayerAttack/AttackHit
@onready var side_attack_hitbox: CollisionShape2D = $Position/PlayerAttack/SideAttackHitbox
@onready var coyote_time: Timer = $Position/CoyoteTime
@onready var jump_buffer: Timer = $Position/JumpBuffer
@onready var dash_timer: Timer = $Position/DashTimer
@onready var dash_cooldown_timer: Timer = $Position/DashCooldown
@onready var knockback_time: Timer = $Position/KnockbackTime
@onready var invincibility: Timer = $Position/Invincibility
@onready var player_body: CollisionShape2D = $PlayerBody
@onready var dash_jump_buffer: Timer = $Position/DashJumpBuffer
@onready var pogo_sprite: Sprite2D = $Position/PlayerAttack/PogoSprite
@onready var pogo_hitbox: CollisionShape2D = $Position/PlayerAttack/PogoHitbox
@onready var attack_2_window: Timer = $Position/PlayerAttack/Attack2Window

# ======================
# ===== MAIN LOOP ======
# ======================

func _physics_process(delta: float) -> void:
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
			# INFO If you press jump during a dash, start the dash jump buffer
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
	if is_on_floor():
		if not has_air_dash:
			has_air_dash = true
		if not has_double_jump:
			has_double_jump = true
		
	if Input.is_action_just_pressed("jump"):
		# INFO If the player is on the floor OR the player is during coyote time 
		# and IS EXPLICITLY falling, jump
		if is_on_floor() or (not coyote_time.is_stopped() and velocity.y >= 0):
			jump()
		# INFO If the player has a double jump, is not on the floor
		# and coyote time isn't running (prevents short hop), double jump
		elif has_double_jump and not is_on_floor() and coyote_time.is_stopped():
			double_jump()
		# INFO If the player is not on the floor and doesn't have a double jump,
		# turn on the jump buffer
		else:
			jump_buffer.start()
			
	# INFO If the jump buffer is running and you reach the floor, jump
	if not jump_buffer.is_stopped() and is_on_floor():
		jump()
	# INFO If player stops holding space during a jump and going up, cut their jump velocity
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER

# INFO Reset all the booleans that depend on hitting the floor and then jump
func jump() -> void:
	coyote_time.stop()
	velocity.y = JUMP_VELOCITY
	has_double_jump = true
	dash_cooldown_timer.stop()
	dash_cooldown_active = false
	jump_buffer.stop()
	
func double_jump() -> void:
	has_double_jump = false
	dash_cooldown_timer.stop()
	dash_cooldown_active = false
	velocity.y = JUMP_VELOCITY*0.95

# ======================
# ===== HORIZONTAL =====
# ======================

func handle_horizontal_movement() -> void:
	var direction = Input.get_axis("move_left", "move_right")

	if direction > 0:
		# INFO If the player is facing the other direction and changes it, cancel the attack
		if flip.scale == Vector2(-1,1) and (torso_animation.animation == "Attack 1" or torso_animation.animation == "Attack 2"):
			cancel_attack()
		flip.scale.x = 1
	elif direction < 0:
		if flip.scale == Vector2(1,1) and (torso_animation.animation == "Attack 1" or torso_animation.animation == "Attack 2"):
			cancel_attack()
		flip.scale.x = -1
		
	# INFO If the player is on floor, play idle or running, if the player is jumping or falling play jump
	if is_on_floor():
		if direction == 0:
			# INFO If the attack anim is playing don't replace it with idle or walk to not stop abruptly
			if not is_playing_attack_anim:
				torso_animation.play("Idle")
			legs_animation.play("Idle")
		else:
			if not is_playing_attack_anim:
				torso_animation.play("Walk")
			legs_animation.play("Walk")
	else:
		# TODO TEMPORARY WAITING FOR JUMP ANIMS
		if not is_playing_attack_anim:
			torso_animation.play("Walk")
		legs_animation.play("Walk")
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
	# TODO TEMPORARY WAITING FOR DASH ANIMS
	torso_animation.play("Walk")
	legs_animation.play("Walk")
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

# ======================
# ====== TIMEOUTS ======
# ======================	
	
func _on_dash_timeout():
	is_dashing = false
	# INFO If the dash jump buffer is active and the player is holding jump
	if not dash_jump_buffer.is_stopped() and Input.is_action_pressed("jump"):
		if is_on_floor():
			jump() # INFO Do a normal jump
		elif has_double_jump:
			double_jump() # INFO Do a double jump
		dash_jump_buffer.stop()

	if not is_knocked_back:
		current_state = State.NORMAL

func _on_dash_cooldown_timeout() -> void:
	dash_cooldown_active = false

func _on_attack_cooldown_timeout() -> void:
	if attack_combo_count == 2:
		attack_combo_count = 0

func _on_knockback_time_timeout() -> void:
	is_knocked_back = false
	current_state = State.NORMAL

func _on_invincibility_timeout() -> void:
	is_invincible = false
	
func _on_attack_2_window_timeout() -> void:
	# Player didn't attack again in time
	if attack_combo_count == 1:
		attack_combo_count = 0

# INFO Call when the PlayerAttack Area hits an enemy; 'enemy' is the Node I passed
func _on_player_attack_hit_enemy(_enemy: Variant) -> void:
	# INFO Only add a different behaviour if we are pogoing
	if attack_hit_animation.current_animation == "Pogo":
		velocity.y = JUMP_VELOCITY * 0.65
		has_double_jump = true
		has_air_dash = true
		dash_cooldown_active = false
		dash_cooldown_timer.stop()
		dash_cooldown_active = false

func _on_torso_animation_finished() -> void:
	if torso_animation.animation == "Attack 1" or torso_animation.animation == "Attack 2":
		is_attacking = false
		is_playing_attack_anim = false
		
# ======================
# ====== ATTACKS =======
# ======================

func attack() -> void:
	if is_invincible:
		is_invincible = false
			
	if Input.is_action_pressed("down") and not is_on_floor():
		is_attacking = true
		attack_combo_count = 0  # Reset combo
		attack_hit_animation.play("Pogo")
		# TODO: Make pogo animation
		torso_animation.play("Idle")
		attack_cooldown.start(0.25)  # Short cooldown after pogo
		return
	
	# Ground attacks - combo system
	if attack_combo_count == 0:
		# First attack
		is_attacking = true
		is_playing_attack_anim = true
		attack_combo_count = 1
		attack_hit_animation.play("Attack1")
		torso_animation.play("Attack 1")
		attack_2_window.start()  # Window to do second attack
		
	elif attack_combo_count == 1 and not attack_2_window.is_stopped():
		attack_combo_count = 2
		is_playing_attack_anim = true
		attack_2_window.stop()  # Close window
		attack_hit_animation.play("Attack2")
		torso_animation.play("Attack 2")
		attack_cooldown.start()  # Long cooldown after combo finishes

func cancel_attack() -> void:
	is_attacking = false
	
	if attack_combo_count == 1:
		attack_2_window.stop()
	
	attack_combo_count = 0  # Reset combo
	attack_hit_animation.stop()
	pogo_sprite.visible = false
	pogo_hitbox.disabled = true
	side_attack_hitbox.disabled = true
	
# ======================
# ===== KNOCKBACK ======
# ======================

func handle_knockback(delta: float) -> void:
	# INFO Smooth out the knockback easing in on 0
	velocity.x = move_toward(velocity.x, 0, 400 * delta)
	# INFO Go up smoothly instead of a fixed elevator up
	velocity.y += GRAVITY_FALLING * delta

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
	# TODO TEMPORARY WAITING FOR DAMAGE ANIMS
	torso_animation.play("Walk")
	legs_animation.play("Walk")
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
	has_double_jump = true
	
	invincibility.start()
	knockback_time.start()
	
func die():
	print("You died!")
	Engine.time_scale = 0.5
	set_physics_process(false)
	# TODO TEMPORARY, WAITING FOR DEATH ANIMS
	torso_animation.play("Death")
	player_body.set_deferred("disabled", true)
	await get_tree().create_timer(1.0).timeout
	Engine.time_scale = 1
	get_tree().reload_current_scene()
