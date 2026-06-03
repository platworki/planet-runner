extends CharacterBody2D

enum State {
	PATROL,
	CHASE,
	ATTACK,
	EDGE_LOOK
}

var current_state = State.PATROL
var player_target = null
var is_boss = false
var is_dying: bool = false

const MAX_HEALTH = 75
const SPEED = 65
const CHASE_SPEED = 90
const GRAVITY = 500.0
const JUMP_KNOCKBACK = -65  
const LUNGE_SPEED = 245
const LUNGE_FRICTION = 600  

var HEALTH = 75
var DAMAGE = 12
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

@export var effect_scene: PackedScene
@onready var status_effect_point: Marker2D = $StatusEffectPoint

var active_effects: Dictionary = {}  
var speed_multiplier: float = 1.0        

func _physics_process(delta: float) -> void:
	if HEALTH <= 0:
		if animated_sprite.animation != "death":
			animated_sprite.play("death")
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
		velocity.x = direction * SPEED * speed_multiplier
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
		velocity.x = direction * CHASE_SPEED * speed_multiplier
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

func take_damage(damage: int, attacker_position: Vector2, kb_multiplier: float = 1.0, from_effect: bool = false):
	if is_invincible and not from_effect:
		return
	
	HEALTH -= damage
	animated_sprite.play("damage")
	print("Slime has ", HEALTH, " HP left!")
	
	slime_hit_sfx.pitch_scale = randf_range(0.8,1.1)
	slime_hit_sfx.play()
	
	
	
	
	if not from_effect:
		var P_roll = randf()
		var S_roll = randf()
		var Bu_roll = randf()
		var Bl_roll = randf()
		
		if GameManager.player_stats.bleed_chance > Bl_roll:
			apply_status_effect("bleed")
			
		if GameManager.player_stats.poison_chance > P_roll:
			apply_status_effect("poison")
		if GameManager.player_stats.slow_chance > S_roll:
			apply_status_effect("slow")
		if GameManager.player_stats.burn_chance > Bu_roll:
			apply_status_effect("burn")
		invincibility.start()
		is_invincible = true

	if attacker_position != Vector2.ZERO:
		var knock_dir = sign(global_position.x - attacker_position.x)
		velocity.x = knock_dir * knockback_force * kb_multiplier
		velocity.y = JUMP_KNOCKBACK * kb_multiplier
		is_knocked_back = true
		current_state = State.CHASE
		
	Effects.play_hit_flash(animated_sprite,Color(0.546, 0.78, 0.581, 1.0),0.25)
	
	if HEALTH <= 0:
		die()
	else:
		await get_tree().create_timer(invincibility.wait_time).timeout
		if HEALTH > 0 and animated_sprite.animation == "damage":
			animated_sprite.play("walk")
			
func erase_from_reality():
	HEALTH = -100
	# 1. Visual: Pure White Flash (Over-exposed)
	Effects.play_hit_flash(animated_sprite, Color(10, 10, 10, 1.0), 3)
	die() # Calls your existing death logic (particles, sound, etc.)

func die():
	if is_dying:
		return
	is_dying = true
	GameManager.on_enemy_died()
	GameManager.add_currency(5)
	print("5 currency added.")
	slime_hitbox.set_deferred("disabled", true)
	animated_sprite.play("death")
	direction = 0
	await animated_sprite.animation_finished
	queue_free()

# ======================
# ==== STATUS EFFECTS ==
# ======================

func apply_status_effect(effect_name: String, stacks: int = 1) -> void:
	var info = GameManager.status_effects_info[effect_name]
	var max_stacks = info["max_stacks"]
	if effect_name in active_effects:
		var current = active_effects[effect_name]
		if effect_name == "bleed":
			current["stacks"] += stacks
			print("Slime started bleeding")
		else:
			current["stacks"] = min(current["stacks"] + stacks, max_stacks)
		# Increment generation so old timers know they're stale
		current["generation"] += 1
		var gen = current["generation"]
		var new_timer = get_tree().create_timer(info["duration"])
		new_timer.timeout.connect(_remove_status_effect.bind(effect_name, gen))
		current["timer"] = new_timer
		_on_stack_change(effect_name, current["stacks"])
		return
	var node = effect_scene.instantiate()
	add_child(node)
	node.global_position = status_effect_point.global_position
	node.play_effect(effect_name)
	var timer = get_tree().create_timer(info["duration"])
	active_effects[effect_name] = {
		"timer": timer,
		"node": node,
		"stacks": stacks,
		"generation": 0
	}
	timer.timeout.connect(_remove_status_effect.bind(effect_name, 0))
	_on_stack_change(effect_name, stacks)
	_start_damage_tick(effect_name)

func _start_damage_tick(effect_name: String) -> void:
	var info = GameManager.status_effects_info[effect_name]
	if info["damage_per_tick"] == 0:
		return
	while effect_name in active_effects and HEALTH > 0 and not is_dying:
		await get_tree().create_timer(0.5).timeout
		if not effect_name in active_effects or is_dying:
			break
		var stacks = active_effects[effect_name]["stacks"]
		var dmg = info["damage_per_tick"]
		if effect_name == "poison":
			dmg = int(MAX_HEALTH * dmg) * stacks
		elif effect_name == "bleed":
			dmg = int(dmg * stacks)  # scales directly with stacks, no cap
		else:
			dmg = int(dmg * stacks)
		take_damage(dmg, Vector2.ZERO, 1.0, true)


func _remove_status_effect(effect_name: String, generation: int) -> void:
	if not effect_name in active_effects:
		return
	# If a newer timer has been created, this is a stale callback — ignore it
	if active_effects[effect_name]["generation"] != generation:
		return
	active_effects[effect_name]["node"].queue_free()
	active_effects.erase(effect_name)
	if effect_name == "slow":
		speed_multiplier = 1.0
	print("Slime had effect removed")

func _on_stack_change(effect_name: String, stacks: int) -> void:
	if effect_name == "slow":
		speed_multiplier = 0.5
