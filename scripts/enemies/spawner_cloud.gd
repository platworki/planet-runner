extends Node2D

signal cloud_finished

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var shot_timer: Timer = $ShotTimer
@onready var fireball_sfx: AudioStreamPlayer = $Fireball
@onready var appear_portal_sfx: AudioStreamPlayer = $AppearPortal

@export var fireball_scene: PackedScene # Drag your fireball.tscn her

var shots_fired = 0
var player = null

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")
	sprite.play("Open")
	appear_portal_sfx.pitch_scale = randf_range(0.5,0.7)
	appear_portal_sfx.play(0.1)
	# Start shooting shortly after opening
	get_tree().create_timer(0.8).timeout.connect(fire_sequence)

func fire_sequence() -> void:
	if shots_fired < 3:
		spawn_projectile()
		shots_fired += 1
		shot_timer.start()
		shot_timer.timeout.connect(fire_sequence, CONNECT_ONE_SHOT)

func spawn_projectile() -> void:
	if !player: 
		return
	var fireball = fireball_scene.instantiate()
	fireball.global_position = muzzle.global_position
	# Aim at player
	var target_pos = player.global_position + Vector2(0, -20)
	var dir = (target_pos - muzzle.global_position).normalized()
	fireball.direction = dir
	fireball.rotation = dir.angle()
	
	Effects.play_sound(fireball_sfx.stream,0.3)
	
	get_parent().add_child(fireball)

func _on_animated_sprite_2d_animation_finished() -> void:
	cloud_finished.emit()
	queue_free()
