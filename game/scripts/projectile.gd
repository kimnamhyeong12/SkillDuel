extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var damage: int = 20
var target_group: StringName = &"enemy"
var projectile_radius: float = 8.0
var projectile_color: Color = Color.WHITE
var style: int = 0
var lifetime: float = 3.2
var age: float = 0.0
var trail: Array[Vector2] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("projectile")
	queue_redraw()

func setup(
	start_position: Vector2,
	move_direction: Vector2,
	new_speed: float,
	new_damage: int,
	new_target_group: StringName,
	new_radius: float,
	new_color: Color,
	new_style: int
) -> void:
	global_position = start_position
	direction = move_direction.normalized()
	speed = new_speed
	damage = new_damage
	target_group = new_target_group
	projectile_radius = new_radius
	projectile_color = new_color
	style = new_style

func _physics_process(delta: float) -> void:
	age += delta
	trail.push_front(global_position)
	if trail.size() > 7:
		trail.pop_back()

	global_position += direction * speed * delta
	lifetime -= delta
	rotation = direction.angle()

	queue_redraw()

	if lifetime <= 0.0:
		queue_free()
		return

	if global_position.x < -100.0 or global_position.x > 1380.0 	or global_position.y < -100.0 or global_position.y > 820.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(target_group) and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

func _draw() -> void:
	var pulse: float = 1.0 + sin(age * 12.0) * 0.10

	match style:
		0:
			# Magic orb
			draw_circle(Vector2.ZERO, projectile_radius * 1.8 * pulse, Color(projectile_color, 0.14))
			draw_circle(Vector2.ZERO, projectile_radius * pulse, projectile_color)
			draw_circle(Vector2(-2.0, -2.0), projectile_radius * 0.35, Color.WHITE)

		1:
			# Arcane bolt / diamond
			var pts := PackedVector2Array([
				Vector2(projectile_radius * 1.8, 0.0),
				Vector2(0.0, -projectile_radius),
				Vector2(-projectile_radius * 1.5, 0.0),
				Vector2(0.0, projectile_radius)
			])
			draw_polygon(pts, PackedColorArray([projectile_color]))
			draw_line(Vector2(-projectile_radius * 2.8, 0.0), Vector2.ZERO, Color(projectile_color, 0.45), projectile_radius * 0.65)

		2:
			# Arrow
			draw_line(Vector2(-projectile_radius * 3.0, 0.0), Vector2(projectile_radius * 1.4, 0.0), projectile_color, 4.0)
			var arrow := PackedVector2Array([
				Vector2(projectile_radius * 2.0, 0.0),
				Vector2(projectile_radius * 0.6, -projectile_radius),
				Vector2(projectile_radius * 0.6, projectile_radius)
			])
			draw_polygon(arrow, PackedColorArray([projectile_color]))

		3:
			# Ultimate wave
			draw_circle(Vector2.ZERO, projectile_radius * 2.2 * pulse, Color(projectile_color, 0.13))
			draw_circle(Vector2.ZERO, projectile_radius * 1.35, Color(projectile_color, 0.35))
			draw_circle(Vector2.ZERO, projectile_radius, projectile_color)
			for i in range(3):
				var a: float = age * 5.0 + float(i) * 2.094
				var p := Vector2(cos(a), sin(a)) * projectile_radius * 1.65
				draw_circle(p, projectile_radius * 0.28, Color.WHITE)

		4:
			# Blade wave
			var slash := PackedVector2Array([
				Vector2(projectile_radius * 2.3, 0.0),
				Vector2(-projectile_radius * 1.1, -projectile_radius * 0.7),
				Vector2(-projectile_radius * 0.5, 0.0),
				Vector2(-projectile_radius * 1.1, projectile_radius * 0.7)
			])
			draw_polygon(slash, PackedColorArray([projectile_color]))
			draw_line(Vector2(-projectile_radius * 2.8, 0.0), Vector2.ZERO, Color.WHITE, 2.0)

		_:
			draw_circle(Vector2.ZERO, projectile_radius, projectile_color)
