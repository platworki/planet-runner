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

const MAX_HEALTH = 400
var HEALTH = MAX_HEALTH
var DAMAGE = 15
var MELEE_DAMAGE = 30
var PARRY_DAMAGE = 25

var current_state = State.HIDDEN
var is_boss = true # For reality eraser immunity
var is_invincible = false

@onready var position_node: Node2D = $Position
@onready var body_hitbox_area: Area2D = $Position/BodyHitboxArea
@onready var main_hitbox: CollisionShape2D = $Position/BodyHitboxArea/BodyHitbox
@onready var melee_hitbox: CollisionShape2D = $Position/MeleeHitboxArea/MeleeHitbox
@onready var state_timer: Timer = $StateTimer
@onready var parry_hitbox: CollisionShape2D = $Position/ParryHitboxArea/ParryHitbox
@onready var animated_sprite: AnimatedSprite2D = $Position/AnimatedSprite2D
@onready var invincibility: Timer = $Invincibility
@onready var parry_check_area: Area2D = $Position/ParryCheckArea
@onready var parry_check_hitbox: CollisionShape2D = $Position/ParryCheckArea/CollisionShape2D
@onready var p3_timer: Timer = $P3Timer

var last_state = State.HIDDEN
var repeat_count = 0
const MAX_REPEATS = 3

@export var cloud_scene: PackedScene # Drag spawner_cloud.tscn here in Inspector

var player = null

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	
	# Metadata for regular damage
	body_hitbox_area.set_meta("entity",self)
	# Metadata for parry check
	parry_check_area.set_meta("entity", self)
	parry_check_area.set_meta("is_parry", true)
	
	enter_hidden()
	player.z_index = 14

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
	var next_move = State.HIDDEN
	
	# Keep rolling until we find a move that hasn't been repeated 3 times
	while true:
		var roll = randf()
		
		# --- Phase 1 ---
		if hp_ratio > 0.7:
			if roll < 0.4:
				next_move = State.RANGED
			else:
				next_move =  State.MELEE
		
		# --- Phase 2 ---
		elif hp_ratio > 0.4:
			if roll < 0.3: 
				next_move = State.RANGED
			elif roll < 0.7: 
				next_move = State.MELEE
			else: 
				next_move = State.PARRY
		
		# --- Phase 3 ---
		else:
			if p3_timer.is_stopped(): 
				p3_timer.start()
			if roll < 0.5:
				next_move = State.MELEE
			else:
				next_move = State.PARRY

		# CHECK REPEAT RULE:
		# If this move is different from the last, OR we haven't hit the limit, it's legal!
		if next_move != last_state or repeat_count < MAX_REPEATS:
			break # Exit the while loop
	
	# Update repeat tracking
	if next_move == last_state:
		repeat_count += 1
	else:
		repeat_count = 1
		last_state = next_move	
	# Execute the legal move
	match next_move:
		State.MELEE: 
			start_melee_sequence()
		State.RANGED: 
			start_ranged_sequence()
		State.PARRY: 
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

func get_nearby_spawn_points(max_dist: float) -> Array:
	if not player: 
		return []
	
	var all_points = get_tree().get_nodes_in_group("BossPSpawn")
	var valid_points = []
	
	for point in all_points:
		# Calculate horizontal distance only
		var x_dist = abs(point.global_position.x - player.global_position.x)
		# Only add to the list if it's within range
		if x_dist <= max_dist:
			valid_points.append(point)
	return valid_points

func spawn_cloud_logic():
	# Get points within 300px of the player
	var nearby_points = get_nearby_spawn_points(300.0)
	if nearby_points.is_empty():
		nearby_points = get_tree().get_nodes_in_group("BossPSpawn")
		
	if nearby_points.size() > 0:
		var point = nearby_points.pick_random()
		var cloud = cloud_scene.instantiate()
		get_parent().add_child(cloud)
		cloud.global_position = point.global_position
		return cloud # Return it so we can connect signals if needed
	return null

func start_ranged_sequence():
	current_state = State.RANGED
	var cloud = spawn_cloud_logic()
	if cloud:
		cloud.cloud_finished.connect(_on_attack_finished)
	
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
	else:
		position_node.scale.x = -1.0
		
func appear():
	# Ensure animation starts at Frame 0 to prevent "frame skipping"
	animated_sprite.frame = 0
	animated_sprite.play("ExitPortal")
	# Small yield to ensure position is set before drawing
	await get_tree().process_frame 
	visible = true

func _on_p_3_timer_timeout() -> void:
	if HEALTH <= 0 or float(HEALTH) / MAX_HEALTH > 0.4:
		p3_timer.stop()
		return

	spawn_cloud_logic()
	
	p3_timer.start(randf_range(2.5, 4.0))

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
		"EnterParry":
			current_state = State.STUNNED
			animated_sprite.play("ParryStagger")

func _on_animated_sprite_2d_frame_changed() -> void:
	var anim = animated_sprite.animation
	var frame = animated_sprite.frame
	
	# --- MELEE HITBOX ---
	if anim == "Melee":
		if frame == 6:
			melee_hitbox.set_deferred("disabled", false)
		if frame == 9:
			melee_hitbox.set_deferred("disabled", true)
	
		# When starting the parry window
	if anim == "EnterParry":
		parry_check_hitbox.set_deferred("disabled", false)
	
	# --- EXIT PORTAL: enable main hitbox ---
	if anim == "ExitPortal" and frame == 15:
		main_hitbox.set_deferred("disabled", false)
	
	if anim == "ParryStagger":
		parry_check_hitbox.set_deferred("disabled", true)
	
	# --- ENTER PORTAL: disable main hitbox ---
	if anim == "EnterPortal":
		parry_check_hitbox.set_deferred("disabled", true)
		if frame == 5:
			main_hitbox.set_deferred("disabled", true)

# --- THE PARRY SYSTEM ---

func start_parry_window():
	animated_sprite.play("EnterParry")

func _on_invincibility_timeout() -> void:
	is_invincible = false

# --- COMBAT ---

func _on_attack_finished():
	var hp_ratio = float(HEALTH) / MAX_HEALTH
	var cooldown_time = 1.0 # Base cooldown
	
	if hp_ratio > 0.4:
		match current_state:
			State.RANGED:
				cooldown_time = 1 # Faster reset after ranged?
			State.MELEE:
				cooldown_time = 1 # Give player more air after melee
			State.PARRY:
				cooldown_time = 2 # Longest break after parry sequences
	else:
		cooldown_time = 0.8 # Almost no break between teleports in P3!	
	
	state_timer.start(cooldown_time)

func trigger_parry_hit():
	# Safety check: Only parry if the animation is right
	if animated_sprite.animation == "EnterParry":
			trigger_counter_attack()

func trigger_counter_attack():
	Effects.hit_stop(0.3, 0.3)
	Effects.play_screen_flash()
	
	look_at_player()
	animated_sprite.play("ParryAttack")
	await animated_sprite.frame_changed
	parry_hitbox.set_deferred("disabled",false)
	
	await animated_sprite.animation_finished
	parry_hitbox.set_deferred("disabled",true)

func disappear():
	animated_sprite.play("EnterPortal")

func take_damage(amount: int, _attacker_pos: Vector2, _kb: float = 1.0):
	if animated_sprite.animation == "EnterParry" and animated_sprite.frame:
		print("Damage blocked by Parry Stance!")
		# We still call the parry logic just in case the area detection missed it
		trigger_parry_hit() 
		return
		
	if is_invincible:
		return
	
	Effects.play_hit_flash(animated_sprite,Color(10,0,0,1),0.3)
	
	invincibility.start()
	HEALTH -= amount
	is_invincible = true
	if HEALTH <= 0:
		die()
		
	print("Boss has ", HEALTH, " HP left!")

func die():
	state_timer.stop()
	p3_timer.stop()
	# Disable all hitboxes so he doesn't hit you while dying
	main_hitbox.set_deferred("disabled", true)
	melee_hitbox.set_deferred("disabled", true)
	
	# Play a specific death animation, or just delete him
	if animated_sprite.sprite_frames.has_animation("Death"):
		animated_sprite.play("Death")
		
	boss_died.emit()
	await animated_sprite.animation_finished
	queue_free()
