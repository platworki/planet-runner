extends Node

const MAX_RIPPLES = 6
var active_radii := []
var active_centers := []
var ripples_enabled := false

@export var tilemap: TileMapLayer
@export var min_interval := 2.0
@export var max_interval := 5.0
@export var spawn_frequency_multiplier := 1.0 # >1 = more frequent, <1 = less frequent
@export var ripple_max_radius := 1000.0
@export var ripple_duration := 2
@export var spawn_radius := 550.0

func _random_point_near_player() -> Vector2:
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return _random_point_on_tilemap()
	
	var angle = randf_range(0, TAU)
	var dist = randf_range(250, spawn_radius)
	var offset = Vector2(cos(angle), sin(angle)) * dist
	return player.global_position + offset

func _ready() -> void:
	add_to_group("RippleSpawner")
	for i in MAX_RIPPLES:
		active_radii.append(-1.0)
		active_centers.append(Vector2.ZERO)
	_push_all_to_shader()

func set_enabled(value: bool) -> void:
	ripples_enabled = value
	if ripples_enabled:
		_schedule_next()

func _schedule_next() -> void:
	if not ripples_enabled:
		return
	var t = randf_range(min_interval, max_interval) / spawn_frequency_multiplier
	get_tree().create_timer(t).timeout.connect(_spawn_random_ripple)

func _spawn_random_ripple() -> void:
	if not ripples_enabled:
		return
	var slot = _find_free_slot()
	if slot != -1:
		var origin = _random_point_near_player()
		active_centers[slot] = origin
		active_radii[slot] = 0.0
		RenderingServer.global_shader_parameter_set("ripple_center_%d" % slot, origin)
		RenderingServer.global_shader_parameter_set("ripple_radius_%d" % slot, 0.0)
		RenderingServer.global_shader_parameter_set("ripple_alpha_%d" % slot, 1.0)
		var tween = create_tween()
		tween.tween_method(
			func(r): _update_radius(slot, r),
			0.0, ripple_max_radius, ripple_duration
		)
		tween.parallel().tween_method(
			func(a): RenderingServer.global_shader_parameter_set("ripple_alpha_%d" % slot, a),
			1.0, 1.0, ripple_duration - 0.4
		)
		tween.chain().tween_method(
			func(a): RenderingServer.global_shader_parameter_set("ripple_alpha_%d" % slot, a),
			1.0, 0.0, 0.4
		)
		tween.tween_callback(func(): _clear_slot(slot))
	if ripples_enabled:
		_schedule_next()

func _find_free_slot() -> int:
	for i in MAX_RIPPLES:
		if active_radii[i] < 0.0:
			return i
	return -1

func _update_radius(slot: int, r: float) -> void:
	active_radii[slot] = r
	RenderingServer.global_shader_parameter_set("ripple_radius_%d" % slot, r)

func _clear_slot(slot: int) -> void:
	active_radii[slot] = -1.0
	RenderingServer.global_shader_parameter_set("ripple_radius_%d" % slot, -1.0)

func _push_slot(slot: int) -> void:
	RenderingServer.global_shader_parameter_set("ripple_center_%d" % slot, active_centers[slot])
	RenderingServer.global_shader_parameter_set("ripple_radius_%d" % slot, active_radii[slot])

func _push_all_to_shader() -> void:
	for i in MAX_RIPPLES:
		_push_slot(i)

func _random_point_on_tilemap() -> Vector2:
	var used_rect: Rect2i = tilemap.get_used_rect()
	var cell_size = tilemap.tile_set.tile_size
	var x = randi_range(used_rect.position.x, used_rect.position.x + used_rect.size.x) * cell_size.x
	var y = randi_range(used_rect.position.y, used_rect.position.y + used_rect.size.y) * cell_size.y
	return tilemap.to_global(Vector2(x, y))
