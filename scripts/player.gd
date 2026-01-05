extends CharacterBody2D

# ======================
# === CONFIGURATION ====
# ======================

const SPEED = 140.0
const JUMP_VELOCITY = -230.0
const GRAVITY_RISING = 365.0
const GRAVITY_FALLING = 600.0
const JUMP_CUT_MULTIPLIER = 0.2
const DASH_SPEED = 330.0
const DASH_DECAY = 900.0
const MAX_VELOCITY = 250.0
# INFO Determines how slow vertical movement must be to trigger "RiseToFall"
const JUMP_PEAK_THRESHOLD = 60.0

enum State {
	NORMAL,
	DASHING,
	KNOCKED_BACK,
	ATTACKING
}

var current_state = State.NORMAL

var DAMAGE = 10
var HEALTH = 100
var knockback_force = 200
var up_knockback_velocity = -160
var attack_combo_count = 0  # INFO Tracks which attack in combo
var has_air_dash = true
var has_double_jump = true
var was_on_floor = true

# ======================
# === NODE REFERENCES ==
# ======================

@onready var flip: Node2D = $Position
@onready var torso_animation: AnimatedSprite2D = $Position/Torso
@onready var legs_animation: AnimatedSprite2D = $Position/Legs
@onready var attack_cooldown: Timer = $Position/PlayerAttack/AttackCooldown
@onready var attack_hit_animation: AnimationPlayer = $Position/PlayerAttack/AttackHit
@onready var attack1_hitbox: CollisionShape2D = $Position/PlayerAttack/Attack1Hitbox
@onready var attack2_hitbox: CollisionShape2D = $Position/PlayerAttack/Attack2Hitbox
@onready var coyote_time: Timer = $Position/CoyoteTime
@onready var jump_buffer: Timer = $Position/JumpBuffer
@onready var dash_timer: Timer = $Position/DashTimer
@onready var dash_cooldown_timer: Timer = $Position/DashCooldown
@onready var knockback_time: Timer = $Position/KnockbackTime
@onready var invincibility: Timer = $Position/Invincibility
@onready var player_body: CollisionShape2D = $PlayerBody
@onready var dash_jump_buffer: Timer = $Position/DashJumpBuffer
@onready var pogo_hitbox: CollisionShape2D = $Position/PlayerAttack/PogoHitbox
@onready var attack_2_window: Timer = $Position/PlayerAttack/Attack2Window
@onready var pogo_cooldown: Timer = $Position/PlayerAttack/PogoCooldown

# ======================
# ===== MAIN LOOP ======
# ======================

#func _ready() -> void:
	#Engine.time_scale = 0.1

func _physics_process(delta: float) -> void:
	# INFO Check if at the beginning of the frame the players on the floor
	was_on_floor = is_on_floor()
	
	if current_state != State.KNOCKED_BACK:
		# INFO If player stops holding space during a jump and going up, cut their jump velocity
		if Input.is_action_just_released("jump") and velocity.y < 0:
			velocity.y *= JUMP_CUT_MULTIPLIER
			if not is_torso_attacking() and not is_torso_transitioning():
				torso_animation.play("RiseToFall")
				torso_animation.offset = Vector2(0,0)
			if legs_animation.animation not in ["StartJump", "Landing", "DoubleJump"]:
				legs_animation.play("RiseToFall")
	
	match current_state:
		State.NORMAL:
			if Input.is_action_just_pressed("dash") and has_air_dash and dash_cooldown_timer.is_stopped():
				current_state = State.DASHING
			if Input.is_action_just_pressed("attack"):
				if attack_cooldown.is_stopped() and (is_on_floor() or not Input.is_action_pressed("down")):
					current_state = State.ATTACKING
				elif pogo_cooldown.is_stopped() and Input.is_action_pressed("down") and not is_on_floor():
					current_state = State.ATTACKING
			handle_jump()
			handle_horizontal_movement()
			gravity(delta)
		State.DASHING:
			# INFO Only dash if not already dashing
			if dash_timer.is_stopped():
				dash()
			# INFO If you press jump during a dash, start the dash jump buffer
			if Input.is_action_just_pressed("jump"):
				dash_jump_buffer.start()
			velocity.x = move_toward(velocity.x, 0, DASH_DECAY * delta)
		State.ATTACKING:
			attack()
			handle_jump()
			# INFO Return back to normal immediately which allows for movement
			current_state = State.NORMAL
		State.KNOCKED_BACK:
			handle_knockback(delta)
	move_and_slide()
	
	# INFO If after body collision the player is now on the floor after not being on it
	# AND is not knocked back/dashing
	if not was_on_floor and is_on_floor() and current_state == State.NORMAL:
		var direction = Input.get_axis("move_left", "move_right")
		
		# INFO If torso isn't locked by attacking, play landing animations
		if not is_torso_attacking():
			if direction == 0:
				torso_animation.play("Landing")
			else:
				torso_animation.play("Walk")
				torso_animation.frame = 5
		
		# INFO Always play legs landing
		if direction == 0:
			legs_animation.play("Landing")
		else:
			legs_animation.play("Walk")
			legs_animation.frame = 5
# ======================
# ====== JUMPING =======
# ======================

func handle_jump() -> void:
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

func jump() -> void:
	coyote_time.stop()
	has_double_jump = true
	dash_cooldown_timer.stop()
	jump_buffer.stop()
	velocity.y = JUMP_VELOCITY
	
	# INFO If not currently attack animation, play start jump on torso
	if not is_torso_attacking():
		torso_animation.play("StartJump")
	legs_animation.play("StartJump") # INFO Legs always update
	
func double_jump() -> void:
	has_double_jump = false
	dash_cooldown_timer.stop()
	velocity.y = JUMP_VELOCITY*0.95
	
	# INFO If not currently attack animation, play start jump on torso
	if not is_torso_attacking():
		torso_animation.play("DoubleJump")
	legs_animation.play("DoubleJump")  # INFO Legs always update

# ======================
# ===== HORIZONTAL =====
# ======================

# INFO Is player currently attacking
func is_torso_attacking() -> bool:
	var current_anim = torso_animation.animation
	return current_anim in ["Attack 1", "Attack 2", "Pogo"]

# INFO Is player currently starting jump or landing
func is_torso_transitioning() -> bool:
	var current_anim = torso_animation.animation
	return current_anim in ["StartJump", "Landing", "DoubleJump"]

func handle_air_animations() -> void:
	if is_torso_transitioning():
		return
	# INFO TORSO UPDATE - Only if player is not attacking
	if not is_torso_attacking():
		if velocity.y < -JUMP_PEAK_THRESHOLD:
			torso_animation.play("Rising")
		elif velocity.y < JUMP_PEAK_THRESHOLD:
			torso_animation.play("RiseToFall")
		else:
			torso_animation.play("Falling")
	if legs_animation.animation in ["StartJump", "Landing", "DoubleJump"]:
		return
	# INFO LEGS UPDATE - ALWAYS UPDATE
	if velocity.y < -JUMP_PEAK_THRESHOLD:
		legs_animation.play("Rising")
	elif velocity.y < JUMP_PEAK_THRESHOLD:
		legs_animation.play("RiseToFall")
	else:
		legs_animation.play("Falling")

func handle_horizontal_movement() -> void:
	var direction = Input.get_axis("move_left", "move_right")
	
	if direction > 0:
		flip.scale.x = 1
	elif direction < 0:
		flip.scale.x = -1
	
	# INFO GENERAL MOVEMENT ANIMATIONS
	# ON GROUND
	if is_on_floor():
		# INFO TORSO animations (respect attacks and transitions)
		if not is_torso_attacking() and not is_torso_transitioning():
			if direction == 0:
				torso_animation.play("Idle")
			else:
				torso_animation.play("Walk")
		# INFO If player is currently landing but moving, walk
		elif torso_animation.animation == "Landing" and direction != 0:
			torso_animation.play("Walk")
		
		# INFO LEGS animations - ALWAYS UPDATE
		if legs_animation.animation not in ["StartJump", "Landing"]:
			if direction == 0:
				legs_animation.play("Idle")
			else:
				legs_animation.play("Walk")
		elif legs_animation.animation == "Landing" and direction != 0:
			legs_animation.play("Walk")
	
	# IN AIR
	else:
		handle_air_animations()
	
	# INFO If players pressing left or right, move, otherwise smooth-ish stop
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
# ======================
# ====== GRAVITY =======
# ======================

func gravity(delta: float) -> void:
	# INFO If the player is falling at max velocity, keep it like that
	if velocity.y >= MAX_VELOCITY:
		velocity.y = MAX_VELOCITY
		
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
	torso_animation.play("Dash")
	legs_animation.play("Dash")
	velocity.x = DASH_SPEED * flip.scale.x * 1.2
	velocity.y = 0
	
	cancel_attack()
	attack_cooldown.stop()
	
	dash_timer.start()
	dash_cooldown_timer.start()
	if not is_on_floor():
		has_air_dash = false

# ======================
# ====== TIMEOUTS ======
# ======================

func _on_dash_timeout():
	# INFO If the dash jump buffer is active and the player is holding jump
	if not dash_jump_buffer.is_stopped() and Input.is_action_pressed("jump"):
		if is_on_floor():
			jump() # INFO Do a normal jump
		elif has_double_jump:
			double_jump() # INFO Do a double jump
		dash_jump_buffer.stop()

	if current_state != State.KNOCKED_BACK:
		current_state = State.NORMAL

func _on_torso_animation_finished() -> void:
	var current_anim = torso_animation.animation
	
	# INFO Handle attack animations finishing
	if current_anim in ["Attack 1", "Attack 2", "Pogo"]:
		# INFO If pogo finished, bring back the offset to normal
		if current_anim == "Pogo":
			torso_animation.offset = Vector2(0,0)
		# INFO When attack finishes, resume appropriate animation based on state
		if is_on_floor():
			var direction = Input.get_axis("move_left", "move_right")
			if direction == 0:
				torso_animation.play("Idle")
			else:
				torso_animation.play("Walk")
		else:
			# INFO Don't call handle_air_animations because it checks is_torso_attacking
			if velocity.y < -JUMP_PEAK_THRESHOLD:
				torso_animation.play("Rising")
			elif velocity.y < JUMP_PEAK_THRESHOLD:
				torso_animation.play("RiseToFall")
			else:
				torso_animation.play("Falling")
		# INFO Stops any further checks
		return
	
	# INFO Handle transition animations finishing
	if current_anim == "Landing" or current_anim == "StartJump" or current_anim == "DoubleJump":
		if is_on_floor():
			torso_animation.play("Idle")
			legs_animation.play("Idle")
		else:
			if velocity.y < -JUMP_PEAK_THRESHOLD:
				torso_animation.play("Rising")
			elif velocity.y < JUMP_PEAK_THRESHOLD:
				torso_animation.play("RiseToFall")
			else:
				torso_animation.play("Falling")

func _on_legs_animation_finished() -> void:
	var current_anim = legs_animation.animation
	
	# INFO Handle transition animations finishing
	if current_anim == "Landing" or current_anim == "StartJump" or current_anim == "DoubleJump":
		if is_on_floor():
			var direction = Input.get_axis("move_left", "move_right")
			if direction == 0:
				legs_animation.play("Idle")
			else:
				legs_animation.play("Walk")
		else:
			if velocity.y < -JUMP_PEAK_THRESHOLD:
				legs_animation.play("Rising")
			elif velocity.y < JUMP_PEAK_THRESHOLD:
				legs_animation.play("RiseToFall")
			else:
				legs_animation.play("Falling")

func _on_attack_cooldown_timeout() -> void:
	if attack_combo_count == 2:
		attack_combo_count = 0

func _on_knockback_time_timeout() -> void:
	current_state = State.NORMAL

func _on_attack_2_window_timeout() -> void:
	# INFO Player didn't attack again in time
	if attack_combo_count == 1:
		attack_combo_count = 0

# INFO Call when the PlayerAttack Area hits an enemy; 'enemy' is the Node I passed
func _on_player_attack_hit_enemy(_enemy: Variant) -> void:
	# INFO Only add a different behaviour if we are pogoing
	if attack_hit_animation.current_animation == "Pogo":
		velocity.y = JUMP_VELOCITY * 0.65
		has_double_jump = true
		has_air_dash = true
		dash_cooldown_timer.stop()
		
# ======================
# ====== ATTACKS =======
# ======================

func attack() -> void:
	if not invincibility.is_stopped():
		invincibility.stop()
			
	if Input.is_action_pressed("down") and not is_on_floor():
		attack_combo_count = 0  # INFO Reset combo
		attack_hit_animation.play("Pogo")
		torso_animation.play("Pogo")
		# INFO Pogo animation is too high, using offset to lower it
		torso_animation.offset = Vector2(0,7)
		attack_cooldown.start(0.4)  # INFO Short cooldown after pogo
		pogo_cooldown.start(0.4)
		return
	
	# INFO Main attacks - combo system
	if attack_combo_count == 0:
		# INFO First attack
		attack_combo_count = 1
		attack_hit_animation.play("Attack 1")
		torso_animation.play("Attack 1")
		attack_2_window.start()  # INFO Window to do second attack
		attack_cooldown.start(0.2)
		
	elif attack_combo_count == 1 and not attack_2_window.is_stopped():
		attack_combo_count = 2
		attack_2_window.stop()
		attack_hit_animation.play("Attack 2")
		torso_animation.play("Attack 2")
		attack_cooldown.start(0.5)  # INFO Long cooldown after combo finishes

func cancel_attack() -> void:
	if attack_combo_count == 1:
		attack_2_window.stop()
	attack_combo_count = 0
	attack_hit_animation.stop()
	torso_animation.offset = Vector2(0,0)
	pogo_hitbox.disabled = true
	attack1_hitbox.disabled = true
	attack2_hitbox.disabled = true

func get_current_attack_damage() -> int:
	var base_damage = DAMAGE
	var current_anim = attack_hit_animation.current_animation
	
	if current_anim == "Attack 2":
		return base_damage*1.5
	else:
		return base_damage

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
	if not invincibility.is_stopped():
		return
		
	HEALTH -= enemy_damage
	if HEALTH <= 0:
		die()
		return

	print("You have ", HEALTH, " left!")
	torso_animation.play("Damage")
	legs_animation.play("Damage")
	# INFO Calculate the hit direction, then add the non-smoothed value for knockback distance
	var knock_dir = sign(global_position.x - enemy_position.x)
	velocity.x = knock_dir * knockback_force
	velocity.y = up_knockback_velocity
	# INFO Pass the knockback smoothing to the State methods
	current_state = State.KNOCKED_BACK
	
	torso_animation.offset = Vector2(0,0)
	invincibility.start()
	has_air_dash = true
	has_double_jump = true
	knockback_time.start()
	
func die():
	print("You died!")
	Engine.time_scale = 0.5
	set_physics_process(false)
	torso_animation.play("Death")
	legs_animation.play("Death")
	player_body.set_deferred("disabled", true)
	await get_tree().create_timer(2.0).timeout
	Engine.time_scale = 1
	get_tree().reload_current_scene()
	
