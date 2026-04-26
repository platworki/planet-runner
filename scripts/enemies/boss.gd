extends CharacterBody2D

signal boss_died

enum State {
	HIDDEN,
	APPEARING,
	MELEE,
	RANGED,
	PARRY,
	STUNNED,
	DISAPPEARING
}

const MAX_HEALTH = 500
var HEALTH = MAX_HEALTH
var DAMAGE = 15
var MELEE_DAMAGE = 30

var current_state = State.HIDDEN
var is_boss = true # For reality eraser immunity
var is_invincible = false

@onready var position_node: Node2D = $Position
@onready var body_hitbox_area: Area2D = $Position/BodyHitboxArea
@onready var main_hitbox: CollisionShape2D = $Position/BodyHitboxArea/BodyHitbox
@onready var melee_hitbox: CollisionShape2D = $Position/MeleeHitboxArea/MeleeHitbox
@onready var state_timer: Timer = $StateTimer
@onready var parry_window: Timer = $ParryWindow
@onready var parry_hitbox: CollisionShape2D = $ParryHitbox
@onready var animated_sprite: AnimatedSprite2D = $Position/AnimatedSprite2D

@export var cloud_scene: PackedScene # Drag spawner_cloud.tscn here in Inspector

var player = null

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	body_hitbox_area.set_meta("entity",self)
	# Start the fight hidden
	enter_hidden()
	player.z_index = 10

func enter_hidden():
	current_state = State.HIDDEN
	visible = false
	# Reset position far away just in case of ghost frames
	global_position = Vector2(-1000, -1000) 
	main_hitbox.set_deferred("disabled", true)
	_on_attack_finished()

func _on_state_timer_timeout() -> void:
	determine_next_move()

func determine_next_move():
	var hp_ratio = float(HEALTH) / MAX_HEALTH
	var roll = randf()
	
	# INFO Phase 1
	if hp_ratio > 0.7:
		if roll < 0.6:
			start_ranged_sequence()
		else: 
			start_melee_sequence()
	# INFO Phase 2
	elif hp_ratio > 0.4:
		if roll < 0.5:
			start_ranged_sequence()
		elif roll < 0.75: 
			start_melee_sequence()
		else: 
			start_parry_sequence()
	# INFO Phase 3
	else:
		if roll < 0.5: 
			start_melee_sequence()
		else: 
			start_parry_sequence()

# --- SEQUENCE TRIGGERS ---

func start_melee_sequence():
	current_state = State.MELEE
	# 1. Teleport first while invisible
	await setup_position(50) 
	# 2. Look at player
	look_at_player()
	# 3. Then appear
	appear()

func start_ranged_sequence():
	current_state = State.RANGED
	# Pick a random marker in the arena
	var points = get_tree().get_nodes_in_group("BossPSpawn")
	if points.size() > 0:
		var point = points.pick_random()
		# Boss doesn't move here! He stays hidden.
		# He just spawns the cloud at that marker.
		spawn_cloud(point.global_position)
	
	# Since Boss didn't "appear", reset the timer to try again
	#state_timer.start()

func start_parry_sequence():
	current_state = State.PARRY
	await setup_position(50)
	look_at_player()
	appear()

# --- ANIMATION HANDLING ---
func setup_position(x_offset: float):
	var dir = 1 if randf() > 0.5 else -1
	var target_x = player.global_position.x + (x_offset * dir)
	
	# Raycast logic: Start at player feet level, look down a bit
	await get_tree().physics_frame
	var space_state = get_world_2d().direct_space_state
	
	var query = PhysicsRayQueryParameters2D.create(
		Vector2(target_x, player.global_position.y - 50), 
		Vector2(target_x, player.global_position.y + 200)
	)
	query.exclude = [self.get_rid(), player.get_rid()]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		global_position = result.position
	else:
		# If no floor immediately below, spawn at player height
		global_position = Vector2(target_x, player.global_position.y)
	
func look_at_player():
	# Calculate the absolute direction. 
	# If player.x is smaller than boss.x, player is on the left.
	var is_player_on_left = player.global_position.x < global_position.x
	
	# Assuming your sprite naturally faces RIGHT:
	if is_player_on_left:
		position_node.scale.x = 1.0
		parry_hitbox.position.x = -abs(parry_hitbox.position.x) # Force negative
	else:
		position_node.scale.x = -1.0
		parry_hitbox.position.x = abs(parry_hitbox.position.x) # Force positive
		
func appear():
	# Ensure animation starts at Frame 0 to prevent "frame skipping"
	animated_sprite.frame = 0
	animated_sprite.play("ExitPortal")
	# Small yield to ensure position is set before drawing
	await get_tree().process_frame 
	visible = true

func _on_animated_sprite_2d_animation_finished() -> void:
	var anim = animated_sprite.animation
	match anim:
		"ExitPortal":
			if current_state == State.MELEE or current_state == State.PARRY:
				animated_sprite.play("Melee")
		"Melee":
			if current_state == State.PARRY:
				start_parry_window()
			else:
				disappear()
		"ParryAttack":
			disappear()
		"ParryStagger":
			disappear()
		"EnterPortal":
			_on_attack_finished()
			enter_hidden()

func _on_animated_sprite_2d_frame_changed() -> void:
	var anim = animated_sprite.animation
	var frame = animated_sprite.frame
	
	# --- MELEE HITBOX ---
	if anim == "Melee":
		if frame == 6:
			melee_hitbox.set_deferred("disabled", false)
		if frame == 9:
			melee_hitbox.set_deferred("disabled", true)
			
	# --- EXIT PORTAL: enable main hitbox ---
	if anim == "ExitPortal" and frame == 15:
		main_hitbox.set_deferred("disabled", false)

	# --- ENTER PORTAL: disable main hitbox ---
	if anim == "EnterPortal" and frame == 5:
		main_hitbox.set_deferred("disabled", true)

# --- THE PARRY SYSTEM ---

func start_parry_window():
	animated_sprite.play("EnterParry")
	parry_window.start() # Player has 1 second to hit

func _on_parry_window_timeout() -> void:
	if animated_sprite.animation == "EnterParry":
		current_state = State.STUNNED
		animated_sprite.play("ParryStagger")

func _on_invincibility_timeout() -> void:
	is_invincible = false

# --- COMBAT ---

func spawn_cloud(pos: Vector2):
	var cloud = cloud_scene.instantiate()
	get_parent().add_child(cloud)
	cloud.global_position = pos
	
	cloud.cloud_finished.connect(_on_attack_finished)

func _on_attack_finished():
	var cooldown_time = state_timer.wait_time # Default
	
	match current_state:
		State.RANGED:
			cooldown_time = 1 # Faster reset after ranged?
		State.MELEE:
			cooldown_time = 1.5 # Give player more air after melee
		State.PARRY:
			cooldown_time = 2.5 # Longest break after parry sequences
			
	state_timer.start(cooldown_time)

func trigger_counter_attack():
	parry_window.stop()
	animated_sprite.play("ParryAttack")
	parry_hitbox.set_deferred("disabled",false)
	# Here you'd trigger a hitbox that hurts the player
	print("COUNTERED!")
	await animated_sprite.animation_finished
	parry_hitbox.set_deferred("disabled",true)

func disappear():
	animated_sprite.play("EnterPortal")

func take_damage(amount: int, _attacker_pos: Vector2, _kb: float = 1.0):
	if is_invincible:
		return
	
	if animated_sprite.animation == "EnterParry" and animated_sprite.frame >= 3:
		trigger_counter_attack()
		return

	HEALTH -= amount
	is_invincible = true
	if HEALTH <= 0:
		die()
		
	print("Boss has ", HEALTH, " HP left!")

func die():
	state_timer.stop()
	parry_window.stop()
	# Disable all hitboxes so he doesn't hit you while dying
	main_hitbox.set_deferred("disabled", true)
	melee_hitbox.set_deferred("disabled", true)
	
	# Play a specific death animation, or just delete him
	if animated_sprite.sprite_frames.has_animation("Death"):
		animated_sprite.play("Death")
		await animated_sprite.animation_finished
	
	boss_died.emit()
	queue_free()
