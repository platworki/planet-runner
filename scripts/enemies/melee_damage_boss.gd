extends Area2D

@onready var melee_hitbox: CollisionShape2D = $MeleeHitbox

func _physics_process(_delta: float) -> void:
	if not melee_hitbox.disabled:
		var bodies = get_overlapping_bodies()
		for body in bodies:
			if body.name == "Player" and body.has_method("take_damage"):
				# Access the Helicopter's LASER_DAMAGE specifically
				var snek = get_parent().get_parent()
				body.take_damage(snek.MELEE_DAMAGE, snek.global_position)
				melee_hitbox.set_deferred("disabled", true)
