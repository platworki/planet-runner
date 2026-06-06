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
var is_player_dead = false
var is_dying = false

@onready var position_node: Node2D = $Position
@onready var main_hitbox: CollisionShape2D = $Position/BodyHitboxArea/BodyHitbox
@onready var melee_hitbox: CollisionShape2D = $Position/MeleeHitboxArea/MeleeHitbox
@onready var parry_hitbox: CollisionShape2D = $Position/ParryHitboxArea/ParryHitbox
@onready var parry_check_hitbox: CollisionShape2D = $Position/ParryCheckArea/CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $Position/AnimatedSprite2D
@onready var parry_check_area: Area2D = $Position/ParryCheckArea
@onready var body_hitbox_area: Area2D = $Position/BodyHitboxArea
@onready var state_timer: Timer = $StateTimer
@onready var p3_timer: Timer = $P3Timer
@onready var invincibility: Timer = $Invincibility
@onready var parry_sfx: AudioStreamPlayer = $Audio/Parry
@onready var portal_sfx: AudioStreamPlayer = $Audio/Portal
@onready var melee_sfx: AudioStreamPlayer = $Audio/Melee
@onready var shield_crack_sfx: AudioStreamPlayer = $Audio/ShieldCrack

var last_state = State.HIDDEN
var repeat_count = 0
const MAX_REPEATS = 3

@export var effect_scene: PackedScene
@onready var status_effect_point: Marker2D = $StatusEffectPoint

var active_effects: Dictionary = {}  
var speed_multiplier: float = 1.0       

@export var cloud_scene: PackedScene # Drag spawner_cloud.tscn here in Inspector

var player = null

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	if player:
		player.player_died.connect(_on_player_died)
	# Metadata for regular damage
	body_hitbox_area.set_meta("entity",self)
	# Metadata for parry check
	parry_check_area.set_meta("entity", self)
	parry_check_area.set_meta("is_parry", true)
	
	enter_hidden()

func enter_hidden():
	current_state = State.HIDDEN
	visible = false
	# Reset position far away just in case of ghost frames
	global_position = Vector2(-1000, -1000) 
	main_hitbox.set_deferred("disabled", true)
	if not is_player_dead:
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
		if hp_ratio > 0.85:
			if roll < 0.4:
				next_move = State.RANGED
			else:
				next_move =  State.MELEE
		
		# --- Phase 2 ---
		elif hp_ratio > 0.5:
			if roll < 0.3: 
				next_move = State.RANGED
			elif roll < 0.6: 
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
		cloud.global_position = point.global_position
		get_parent().add_child(cloud)
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
	
	await get_tree().physics_frame
	var space_state = get_world_2d().direct_space_state
	var player_y = player.global_position.y
	
	# Ray starts just above the player's feet and only goes DOWNWARD.
	# This means the first surface it can ever find is the one the player
	# is standing on, or something below it — never a platform above.
	var q = PhysicsRayQueryParameters2D.create(
		Vector2(target_x, player_y - 20),
		Vector2(target_x, player_y + 1200)
	)
	q.exclude = [self.get_rid(), player.get_rid()]
	var result = space_state.intersect_ray(q)
	
	if result:
		global_position = result.position
	else:
		_fallback_to_nearest_spawn(player_y)


# Finds the BossPSpawn point with the closest X to target_x and teleports there.
func _fallback_to_nearest_spawn(player_y: float) -> void:
	var spawn_points = get_tree().get_nodes_in_group("BossPSpawn")
	if spawn_points.is_empty():
		push_warning("Boss: No BossPSpawn nodes found and raycast missed!")
		return
	
	# Filter to only spawn points at or below the player's elevation.
	# In Godot 2D, larger Y = lower on screen.
	var valid_points = spawn_points.filter(
		func(p): return p.global_position.y >= player_y - 50
	)
	
	# If somehow every spawn is above the player, use all as a last resort.
	if valid_points.is_empty():
		valid_points = spawn_points
	
	# Among valid points, pick the one closest in Y to the player.
	var nearest: Node2D = valid_points[0]
	for point in valid_points.slice(1):
		if abs(point.global_position.y - player_y) < abs(nearest.global_position.y - player_y):
			nearest = point
	
	global_position = nearest.global_position
	
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
	portal_sfx.pitch_scale = randf_range(0.6,0.8)
	portal_sfx.play()
	# Small yield to ensure position is set before drawing
	await get_tree().process_frame 
	visible = true

func _on_p_3_timer_timeout() -> void:
	if HEALTH <= 0 or float(HEALTH) / MAX_HEALTH > 0.5:
		p3_timer.stop()
		return

	spawn_cloud_logic()
	
	p3_timer.start(randf_range(2.5, 4.0))
	
func _on_player_died():
	# 1. Set the flag so we know the player is gone
	is_player_dead = true
	
	# 2. Stop the Phase 3 chaotic spawns immediately
	p3_timer.stop()
	
	# 3. Stop the state timer so no NEW moves are chosen
	state_timer.stop()
	
	# Note: We do NOT call disappear() here. 
	# We let the current animation finish its natural course.
	print("Player died. Boss is finishing current move and idling.")

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
			if not is_dying:  # Add this guard
				_on_attack_finished()
				enter_hidden()
		"EnterParry":
			current_state = State.STUNNED
			shield_crack_sfx.pitch_scale = randf_range(0.6,0.9)
			shield_crack_sfx.play()
			animated_sprite.play("ParryStagger")

func _on_animated_sprite_2d_frame_changed() -> void:
	var anim = animated_sprite.animation
	var frame = animated_sprite.frame
	
	# --- MELEE HITBOX ---
	if anim == "Melee":
		if frame == 6:
			melee_sfx.pitch_scale = randf_range(0.75,1.2)
			melee_sfx.play()
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
	parry_sfx.pitch_scale = randf_range(0.8,1.1)
	parry_sfx.play()
	animated_sprite.play("EnterParry")

func _on_invincibility_timeout() -> void:
	is_invincible = false

# --- COMBAT ---

func _on_attack_finished():
	if is_player_dead:
		return
	
	var hp_ratio = float(HEALTH) / MAX_HEALTH
	var cooldown_time = 1.0 # Base cooldown
	
	if hp_ratio > 0.5:
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
	portal_sfx.pitch_scale = randf_range(1.0,1.2)
	portal_sfx.play()

func take_damage(amount: int, _attacker_pos: Vector2, _kb: float = 1.0, from_effect: bool = false):
	if animated_sprite.animation == "EnterParry" and animated_sprite.frame and not from_effect:
		print("Damage blocked by Parry Stance!")
		# We still call the parry logic just in case the area detection missed it
		trigger_parry_hit() 
		return
		
	if is_invincible || State.HIDDEN:
		return
		
	HEALTH -= amount
	
	Effects.play_hit_flash(animated_sprite,Color(0.164, 0.164, 0.164, 1.0),0.3)
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
	
	
	
	if HEALTH <= 0:
		die()
	
	print("Boss has ", HEALTH, " HP left!")

func die():
	is_dying = true
	state_timer.stop()
	p3_timer.stop()
	
	# If hidden or in the middle of disappearing, force the boss visible
	# so the death animation can actually be seen
	if current_state == State.HIDDEN or current_state == State.DISAPPEARING:
		# Teleport to the player's location before appearing
		await setup_position(80)
		look_at_player()
		visible = true
		main_hitbox.set_deferred("disabled", true)
		melee_hitbox.set_deferred("disabled", true)
		parry_hitbox.set_deferred("disabled", true)
		parry_check_hitbox.set_deferred("disabled", true)
		
		if animated_sprite.sprite_frames.has_animation("Death"):
			animated_sprite.play("Death")
		
		boss_died.emit()
		await animated_sprite.animation_finished
		queue_free()
		return
	
	# Already visible — just disable hitboxes and die normally
	main_hitbox.set_deferred("disabled", true)
	melee_hitbox.set_deferred("disabled", true)
	parry_hitbox.set_deferred("disabled", true)
	parry_check_hitbox.set_deferred("disabled", true)
	
	if animated_sprite.sprite_frames.has_animation("Death"):
		animated_sprite.play("Death")
	
	boss_died.emit()
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
