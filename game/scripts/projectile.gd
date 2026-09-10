extends Area2D

const HIT_EFFECT_SCENE: PackedScene = preload("res://scenes/HitEffect.tscn")

# trajectory
const TRAJECTORY_STRAIGHT: int = 0
const TRAJECTORY_SINE: int = 1
const TRAJECTORY_ACCEL: int = 2
const TRAJECTORY_BOOMERANG: int = 3

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var damage: int = 20
var target_group: StringName = &"enemy"

var projectile_radius: float = 8.0
var projectile_color: Color = Color.WHITE
var style: int = 0

var trajectory: int = TRAJECTORY_STRAIGHT
var max_distance: float = 1400.0
var pierce_left: int = 0
var wave_amplitude: float = 0.0
var wave_frequency: float = 0.0
var acceleration: float = 0.0
var radius_growth: float = 0.0

var start_position: Vector2 = Vector2.ZERO
var travelled: float = 0.0
var age: float = 0.0
var returning: bool = false
var already_hit: Array[Node] = []


func _ready() -> void:
	add_to_group("projectile")
	body_entered.connect(_on_body_entered)
	queue_redraw()


func setup(
	new_position: Vector2,
	move_direction: Vector2,
	new_speed: float,
	new_damage: int,
	new_target_group: StringName,
	new_radius: float,
	new_color: Color,
	new_style: int,
	new_trajectory: int = TRAJECTORY_STRAIGHT,
	new_max_distance: float = 1400.0,
	new_pierce: int = 0,
	new_wave_amplitude: float = 0.0,
	new_wave_frequency: float = 0.0,
	new_acceleration: float = 0.0,
	new_radius_growth: float = 0.0
) -> void:
	global_position = new_position
	start_position = new_position
	direction = move_direction.normalized()

	speed = new_speed
	damage = new_damage
	target_group = new_target_group

	projectile_radius = new_radius
	projectile_color = new_color
	style = new_style

	trajectory = new_trajectory
	max_distance = new_max_distance
	pierce_left = new_pierce
	wave_amplitude = new_wave_amplitude
	wave_frequency = new_wave_frequency
	acceleration = new_acceleration
	radius_growth = new_radius_growth

	rotation = direction.angle()
	_update_collision_radius()


func _physics_process(delta: float) -> void:
	age += delta

	match trajectory:
		TRAJECTORY_STRAIGHT:
			var step: float = speed * delta
			global_position += direction * step
			travelled += absf(step)

		TRAJECTORY_SINE:
			var step: float = speed * delta
			travelled += absf(step)

			var perpendicular := Vector2(-direction.y, direction.x)
			var wave_offset: float = sin(age * wave_frequency) * wave_amplitude

			global_position = (
				start_position
				+ direction * travelled
				+ perpendicular * wave_offset
			)

		TRAJECTORY_ACCEL:
			speed += acceleration * delta
			speed = maxf(80.0, speed)

			var step: float = speed * delta
			global_position += direction * step
			travelled += absf(step)

		TRAJECTORY_BOOMERANG:
			var step: float = speed * delta
			travelled += absf(step)

			if not returning and travelled >= max_distance * 0.52:
				returning = true
				direction = -direction

			global_position += direction * step

	rotation = direction.angle()
	_update_collision_radius()
	queue_redraw()

	if travelled >= max_distance:
		queue_free()
		return

	if (
		global_position.x < -180.0
		or global_position.x > 1460.0
		or global_position.y < -180.0
		or global_position.y > 900.0
	):
		queue_free()


func _update_collision_radius() -> void:
	var current_radius: float = maxf(
		2.0,
		projectile_radius + radius_growth * age
	)

	var circle := $CollisionShape2D.shape as CircleShape2D
	if circle != null:
		circle.radius = current_radius



func reflect_projectile(
	new_target_group: StringName,
	damage_multiplier: float = 1.20
) -> void:
	# SERA의 튕겨내기로 소유권과 진행 방향을 뒤집는다.
	target_group = new_target_group
	direction = -direction
	start_position = global_position
	travelled = 0.0
	returning = false
	already_hit.clear()

	damage = maxi(
		1,
		int(round(float(damage) * damage_multiplier))
	)

	projectile_color = projectile_color.lightened(0.22)
	rotation = direction.angle()
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body in already_hit:
		return

	if body.is_in_group(target_group) and body.has_method("take_damage"):
		already_hit.append(body)
		body.take_damage(damage)
		_spawn_hit_effect()

		var scene := get_tree().current_scene
		if scene != null and scene.has_method("request_impact"):
			scene.request_impact(
				damage,
				global_position,
				projectile_color
			)

		if pierce_left > 0:
			pierce_left -= 1
		else:
			queue_free()


func _spawn_hit_effect() -> void:
	var effect := HIT_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)

	effect.setup(
		global_position,
		damage,
		projectile_color
	)


func _draw() -> void:
	var radius: float = maxf(
		2.0,
		projectile_radius + radius_growth * age
	)

	var pulse: float = 1.0 + sin(age * 13.0) * 0.10

	match style:
		# ARIA basic - square-pixel magic orb
		0:
			draw_rect(
				Rect2(
					Vector2(-radius * 1.6, -radius * 1.6),
					Vector2(radius * 3.2, radius * 3.2)
				),
				Color(projectile_color, 0.13)
			)

			draw_rect(
				Rect2(
					Vector2(-radius, -radius),
					Vector2(radius * 2.0, radius * 2.0)
				),
				projectile_color
			)

			draw_rect(
				Rect2(
					Vector2(-radius * 0.35, -radius * 0.35),
					Vector2(radius * 0.70, radius * 0.70)
				),
				Color.WHITE
			)

		# ARIA Q - long arcane lance
		1:
			draw_rect(
				Rect2(
					Vector2(-radius * 3.5, -radius * 0.45),
					Vector2(radius * 4.5, radius * 0.9)
				),
				Color(projectile_color, 0.42)
			)

			var diamond := PackedVector2Array([
				Vector2(radius * 2.2, 0.0),
				Vector2(0.0, -radius),
				Vector2(-radius * 1.3, 0.0),
				Vector2(0.0, radius)
			])

			draw_polygon(
				diamond,
				PackedColorArray([projectile_color])
			)

			draw_rect(
				Rect2(
					Vector2(-radius * 0.35, -radius * 0.35),
					Vector2(radius * 0.7, radius * 0.7)
				),
				Color.WHITE
			)

		# LYRA arrow
		2:
			draw_rect(
				Rect2(
					Vector2(-radius * 3.1, -2.0),
					Vector2(radius * 4.0, 4.0)
				),
				projectile_color
			)

			var arrow_head := PackedVector2Array([
				Vector2(radius * 2.0, 0.0),
				Vector2(radius * 0.5, -radius),
				Vector2(radius * 0.5, radius)
			])

			draw_polygon(
				arrow_head,
				PackedColorArray([projectile_color])
			)

			draw_line(
				Vector2(-radius * 2.5, -radius * 0.7),
				Vector2(-radius * 1.7, 0.0),
				Color.WHITE,
				2.0
			)

			draw_line(
				Vector2(-radius * 2.5, radius * 0.7),
				Vector2(-radius * 1.7, 0.0),
				Color.WHITE,
				2.0
			)

		# ARIA ultimate - expanding rune core
		3:
			draw_rect(
				Rect2(
					Vector2(-radius * 2.2, -radius * 2.2),
					Vector2(radius * 4.4, radius * 4.4)
				),
				Color(projectile_color, 0.10)
			)

			draw_circle(
				Vector2.ZERO,
				radius * 1.35 * pulse,
				Color(projectile_color, 0.32)
			)

			draw_circle(
				Vector2.ZERO,
				radius,
				projectile_color
			)

			for i in range(4):
				var a: float = age * 5.2 + float(i) * TAU / 4.0
				var p := Vector2(cos(a), sin(a)) * radius * 1.65

				draw_rect(
					Rect2(
						p - Vector2(radius * 0.20, radius * 0.20),
						Vector2(radius * 0.40, radius * 0.40)
					),
					Color.WHITE
				)

		# SERA crescent / blade wave
		4:
			var blade := PackedVector2Array([
				Vector2(radius * 2.7, 0.0),
				Vector2(-radius * 0.8, -radius),
				Vector2(-radius * 0.2, 0.0),
				Vector2(-radius * 0.8, radius)
			])

			draw_polygon(
				blade,
				PackedColorArray([projectile_color])
			)

			draw_line(
				Vector2(-radius * 2.5, 0.0),
				Vector2(radius * 0.8, 0.0),
				Color.WHITE,
				2.0
			)

		# ARIA curved shard
		5:
			var shard := PackedVector2Array([
				Vector2(radius * 1.8, 0.0),
				Vector2(radius * 0.2, -radius * 1.2),
				Vector2(-radius * 1.6, 0.0),
				Vector2(radius * 0.2, radius * 1.2)
			])

			draw_polygon(
				shard,
				PackedColorArray([projectile_color])
			)

			draw_rect(
				Rect2(
					Vector2(-radius * 2.8, -2.0),
					Vector2(radius * 1.5, 4.0)
				),
				Color(projectile_color, 0.38)
			)

		# LYRA ultimate rain arrow
		6:
			draw_rect(
				Rect2(
					Vector2(-2.0, -radius * 3.5),
					Vector2(4.0, radius * 4.2)
				),
				projectile_color
			)

			var head := PackedVector2Array([
				Vector2(0.0, radius * 2.5),
				Vector2(-radius * 0.8, radius * 1.0),
				Vector2(radius * 0.8, radius * 1.0)
			])

			draw_polygon(
				head,
				PackedColorArray([projectile_color])
			)

		# SERA ultimate - thick rift
		7:
			var flicker: float = 0.75 + sin(age * 18.0) * 0.20

			draw_rect(
				Rect2(
					Vector2(-radius * 3.4, -radius * 0.9),
					Vector2(radius * 5.4, radius * 1.8)
				),
				Color(projectile_color, 0.18)
			)

			draw_polygon(
				PackedVector2Array([
					Vector2(radius * 3.0, 0.0),
					Vector2(-radius * 1.5, -radius * flicker),
					Vector2(-radius * 0.4, 0.0),
					Vector2(-radius * 1.5, radius * flicker)
				]),
				PackedColorArray([projectile_color])
			)

			draw_line(
				Vector2(-radius * 3.0, 0.0),
				Vector2(radius * 2.0, 0.0),
				Color.WHITE,
				3.0
			)

		_:
			draw_circle(
				Vector2.ZERO,
				radius,
				projectile_color
			)
