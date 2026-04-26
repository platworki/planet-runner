extends Area2D

@export var boss_scene: PackedScene # Drag PortalBoss.tscn here in Inspector

@onready var left_arena_boundary: StaticBody2D = $"../LeftArenaBoundary"
@onready var invisible_wall: CollisionShape2D = $"../LeftArenaBoundary/CollisionShape2D"
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var player: CharacterBody2D
var is_active = false

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player = body

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player = null

func _input(event: InputEvent) -> void:
	if is_active:
		return
		
	if player and event.is_action_pressed("pickup"):
		start_boss_sequence()

func start_boss_sequence() -> void:
	is_active = true
	# 2. Door Animation
	animated_sprite.play("BossActivate")
	await animated_sprite.animation_finished
	animated_sprite.play("Idle")
	# 3. Camera and Wall Lockdown
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.limit_left = int(left_arena_boundary.global_position.x)
	
	invisible_wall.set_deferred("disabled", false)
	spawn_boss()


func spawn_boss() -> void:
	var boss = boss_scene.instantiate()
	boss.global_position = left_arena_boundary.global_position + Vector2(300, 0)
	# Connect the death signal so the door knows when to open
	boss.boss_died.connect(_on_boss_defeated)
	
	get_parent().get_parent().add_child(boss)

func _on_boss_defeated() -> void:
	animated_sprite.play("EndOpen")
	# 2. Unlock Walls
	invisible_wall.set_deferred("disabled", true)
	
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.limit_left = -120 # Reset to default large value
