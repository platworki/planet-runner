extends Area2D

@export var boss_scene: PackedScene # Drag PortalBoss.tscn here in Inspector

@onready var left_arena_boundary: StaticBody2D = $"../LeftArenaBoundary"
@onready var invisible_wall: CollisionShape2D = $"../LeftArenaBoundary/CollisionShape2D"
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_ui: Node2D = $InteractUI
@onready var laser_sfx: AudioStreamPlayer = $Laser
@onready var boss_music: AudioStreamPlayer = $"../../Audio/Boss music"
@onready var bg_music: AudioStreamPlayer = $"../../Audio/World background music"

var player: CharacterBody2D
var is_active = false
var boss_defeated = false

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		interact_ui.show_ui()
		player = body

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		interact_ui.hide_ui()
		player = null

func _input(event: InputEvent) -> void:	
	if player and event.is_action_pressed("pickup"):
		# IF BOSS IS DEAD: Transition to next level
		if boss_defeated:
			exit_level()
			return
		
		# IF BOSS IS NOT STARTED: Start sequence
		if not is_active:
			player.z_index = 14
			start_boss_sequence()

func start_boss_sequence() -> void:
	is_active = true
	# 2. Door Animation
	interact_ui.lock_and_hide()
	animated_sprite.play("BossActivate")
	laser_sfx.play(0.85)
	await animated_sprite.animation_finished
	animated_sprite.play("Idle")
	# 3. Camera and Wall Lockdown
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.limit_left = int(left_arena_boundary.global_position.x)
	
	fade_out_music(bg_music, 2)
	boss_music.volume_db = -80
	boss_music.play()
	fade_in_music(boss_music, 0.5)
	
	invisible_wall.set_deferred("disabled", false)
	spawn_boss()

func fade_out_music(audio_player: AudioStreamPlayer, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(audio_player, "volume_db", -80, duration)
	tween.tween_callback(audio_player.stop)

func fade_in_music(audio_player: AudioStreamPlayer, duration: float) -> void:
	audio_player.volume_db = -80
	audio_player.play()
	var tween = create_tween()
	tween.tween_property(audio_player, "volume_db", 0.0, duration)

# Inside boss_arena_manager.gd
func spawn_boss() -> void:
	var ripple_spawner = get_tree().get_first_node_in_group("RippleSpawner")
	if ripple_spawner:
		ripple_spawner.spawn_frequency_multiplier = 0.3
		ripple_spawner.set_enabled(true)
	
	var boss = boss_scene.instantiate()
	boss.global_position = left_arena_boundary.global_position + Vector2(300, 0)
	boss.boss_died.connect(_on_boss_defeated)
	# Get the UI and register the boss
	# Adjust this path depending on where your UI node lives
	var ui = get_tree().get_first_node_in_group("UI") 
	if ui:
		ui.register_boss(boss)
		
	await get_tree().create_timer(2.0).timeout
	get_parent().get_parent().add_child(boss)
	

func _on_boss_defeated() -> void:
	boss_defeated = true
	var ripple_spawner = get_tree().get_first_node_in_group("RippleSpawner")
	if ripple_spawner:
		ripple_spawner.set_enabled(false)
	
	fade_out_music(boss_music, 2)
	fade_in_music(bg_music, 2)
	interact_ui.unlock()
	
	await get_tree().create_timer(3.0).timeout
	animated_sprite.play("EndOpen")
	invisible_wall.set_deferred("disabled", true)
	
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.limit_left = -120

func exit_level():
	# Prevent double-clicks during fade
	set_process_input(false)
	set_physics_process(false)
	
	player.input_enabled = false
	SceneTransitions.fade_to_scene_black("res://scenes/menu.tscn")
	GameManager.reset_game()
