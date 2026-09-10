extends CharacterBody2D

signal defeated
signal ultimate_used(character_index: int)

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/Projectile.tscn")
const MAX_HP: int = 200

const MIN_X: float = 40.0
const MAX_X: float = 1240.0
const MIN_Y: float = 45.0
const MAX_Y: float = 245.0

var hp: int = MAX_HP
var active: bool = false

var difficulty: int = 0
var character_index: int = 1
var character_name: String = "LYRA"

var move_speed: float = 110.0
var terrain_speed_multiplier: float = 1.0
var attack_interval: float = 1.6
var attack_damage: int = 11
var aim_spread: float = 0.10

var shoot_cooldown: float = 1.0
var skill_cooldown: float = 4.5
var move_target: Vector2 = Vector2(980.0, 145.0)
var decision_timer: float = 0.0

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("enemy")
	rng.randomize()
	set_active(false)
	queue_redraw()


func configure(new_difficulty: int, new_character_index: int) -> void:
	difficulty = new_difficulty
	character_index = new_character_index

	character_name = ["ARIA", "LYRA", "SERA"][character_index]

	match difficulty:
		0:
			move_speed = 105.0
			attack_interval = 1.65
			attack_damage = 10
			aim_spread = 0.20
			skill_cooldown = 6.5

		1:
			move_speed = 165.0
			attack_interval = 1.10
			attack_damage = 15
			aim_spread = 0.08
			skill_cooldown = 4.5

		2:
			move_speed = 235.0
			attack_interval = 0.72
			attack_damage = 20
			aim_spread = 0.025
			skill_cooldown = 3.2

	hp = MAX_HP
	queue_redraw()


func set_active(value: bool) -> void:
	active = value
	set_physics_process(value)


func set_terrain_speed_multiplier(value: float) -> void:
	terrain_speed_multiplier = clampf(value, 0.35, 1.50)


func reset_terrain_effects() -> void:
	terrain_speed_multiplier = 1.0


func reset_for_battle() -> void:
	hp = MAX_HP
	position = Vector2(980.0, 145.0)
	velocity = Vector2.ZERO

	shoot_cooldown = attack_interval * 0.65
	skill_cooldown = 2.8 + float(difficulty)

	decision_timer = 0.0
	move_target = Vector2(920.0, 145.0)
	terrain_speed_multiplier = 1.0

	queue_redraw()


func _physics_process(delta: float) -> void:
	if not active:
		return

	decision_timer -= delta

	if decision_timer <= 0.0:
		_choose_move_target()

	var to_target := move_target - position

	if to_target.length() > 8.0:
		velocity = to_target.normalized() * move_speed * terrain_speed_multiplier
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	position.x = clampf(position.x, MIN_X, MAX_X)
	position.y = clampf(position.y, MIN_Y, MAX_Y)

	shoot_cooldown -= delta
	skill_cooldown -= delta

	if shoot_cooldown <= 0.0:
		shoot_cooldown = attack_interval
		_shoot_basic()

	if skill_cooldown <= 0.0:
		skill_cooldown = _next_skill_delay()
		_use_character_skill()

	queue_redraw()


func _choose_move_target() -> void:
	match difficulty:
		0:
			decision_timer = 1.25

		1:
			decision_timer = 0.72

		2:
			decision_timer = 0.34

	move_target = Vector2(
		rng.randf_range(90.0, 1190.0),
		rng.randf_range(70.0, 225.0)
	)


func _next_skill_delay() -> float:
	match difficulty:
		0:
			return rng.randf_range(5.8, 7.2)

		1:
			return rng.randf_range(4.0, 5.2)

		2:
			return rng.randf_range(2.9, 4.0)

	return 5.0


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")

	if players.is_empty():
		return null

	return players[0] as Node2D


func _aim_at_player() -> Vector2:
	var target := _get_player()

	if target == null:
		return Vector2.DOWN

	var dir := (
		target.global_position
		- global_position
	).normalized()

	return dir.rotated(
		rng.randf_range(
			-aim_spread,
			aim_spread
		)
	)


func _spawn(
	direction: Vector2,
	speed: float,
	damage: int,
	radius: float,
	color: Color,
	style: int,
	trajectory: int = 0,
	max_distance: float = 1400.0,
	pierce: int = 0,
	wave_amplitude: float = 0.0,
	wave_frequency: float = 0.0,
	acceleration: float = 0.0,
	radius_growth: float = 0.0
) -> void:
	var projectile := PROJECTILE_SCENE.instantiate()

	get_tree().current_scene.add_child(projectile)

	projectile.setup(
		global_position + direction.normalized() * 34.0,
		direction,
		speed,
		damage,
		&"player",
		radius,
		color,
		style,
		trajectory,
		max_distance,
		pierce,
		wave_amplitude,
		wave_frequency,
		acceleration,
		radius_growth
	)


func _shoot_basic() -> void:
	var dir := _aim_at_player()

	match character_index:
		0:
			_spawn(
				dir,
				560.0,
				attack_damage,
				7.0,
				Color(0.35, 0.85, 1.0),
				0,
				0,
				1050.0
			)

		1:
			_spawn(
				dir,
				720.0,
				attack_damage,
				5.0,
				Color(1.0, 0.82, 0.24),
				2,
				0,
				1250.0
			)

		2:
			_spawn(
				dir,
				620.0,
				attack_damage,
				9.0,
				Color(1.0, 0.35, 0.52),
				4,
				0,
				720.0
			)


func _use_character_skill() -> void:
	var dir := _aim_at_player()

	match character_index:
		# ARIA AI: 굽는 마력탄
		0:
			_spawn(
				dir,
				560.0,
				attack_damage + 8,
				9.0,
				Color(0.68, 0.42, 1.0),
				5,
				1,
				950.0,
				0,
				38.0,
				6.0
			)

			_spawn(
				dir,
				560.0,
				attack_damage + 8,
				9.0,
				Color(0.40, 0.88, 1.0),
				5,
				1,
				950.0,
				0,
				-38.0,
				6.0
			)

		# LYRA AI: 3방향 화살
		1:
			for angle in [-0.16, 0.0, 0.16]:
				_spawn(
					dir.rotated(angle),
					800.0,
					attack_damage,
					5.0,
					Color(1.0, 0.72, 0.18),
					2,
					0,
					1000.0
				)

		# SERA AI: X 형태 검기
		2:
			_spawn(
				dir.rotated(-0.10),
				720.0,
				attack_damage + 5,
				11.0,
				Color(1.0, 0.22, 0.42),
				4,
				1,
				800.0,
				0,
				24.0,
				7.0
			)

			_spawn(
				dir.rotated(0.10),
				720.0,
				attack_damage + 5,
				11.0,
				Color(1.0, 0.55, 0.68),
				4,
				1,
				800.0,
				0,
				-24.0,
				7.0
			)


func take_damage(amount: int) -> void:
	if not active:
		return

	hp = maxi(0, hp - amount)
	queue_redraw()

	if hp <= 0:
		active = false
		defeated.emit()


func get_hp_ratio() -> float:
	return float(hp) / float(MAX_HP)


func _draw() -> void:
	# CPU도 플레이어와 같은 픽셀 캐릭터 계열로 표현
	match character_index:
		0:
			_draw_aria()

		1:
			_draw_lyra()

		2:
			_draw_sera()


func _draw_aria() -> void:
	draw_rect(Rect2(Vector2(-13, -29), Vector2(26, 20)), Color(0.30, 0.20, 0.55))
	draw_rect(Rect2(Vector2(-10, -25), Vector2(20, 18)), Color(1.0, 0.82, 0.72))
	draw_rect(Rect2(Vector2(-15, -31), Vector2(10, 18)), Color(0.38, 0.25, 0.70))
	draw_rect(Rect2(Vector2(6, -31), Vector2(9, 21)), Color(0.38, 0.25, 0.70))

	draw_rect(Rect2(Vector2(-6, -18), Vector2(3, 3)), Color(0.30, 0.82, 1.0))
	draw_rect(Rect2(Vector2(4, -18), Vector2(3, 3)), Color(0.30, 0.82, 1.0))

	draw_rect(Rect2(Vector2(-13, -7), Vector2(26, 25)), Color(0.47, 0.27, 0.78))
	draw_rect(Rect2(Vector2(-18, 14), Vector2(36, 15)), Color(0.58, 0.34, 0.90))
	draw_rect(Rect2(Vector2(-6, 19), Vector2(12, 8)), Color(0.28, 0.82, 1.0))

	draw_rect(Rect2(Vector2(-11, 28), Vector2(8, 15)), Color(0.20, 0.18, 0.30))
	draw_rect(Rect2(Vector2(4, 28), Vector2(8, 15)), Color(0.20, 0.18, 0.30))

	draw_rect(Rect2(Vector2(18, -10), Vector2(4, 40)), Color(0.72, 0.60, 0.42))
	draw_rect(Rect2(Vector2(14, -18), Vector2(12, 12)), Color(0.28, 0.84, 1.0))


func _draw_lyra() -> void:
	draw_rect(Rect2(Vector2(-13, -30), Vector2(26, 20)), Color(0.16, 0.38, 0.30))
	draw_rect(Rect2(Vector2(-10, -25), Vector2(20, 18)), Color(1.0, 0.84, 0.72))
	draw_rect(Rect2(Vector2(-15, -31), Vector2(30, 8)), Color(0.12, 0.48, 0.36))

	draw_rect(Rect2(Vector2(-6, -18), Vector2(3, 3)), Color(0.95, 0.72, 0.20))
	draw_rect(Rect2(Vector2(4, -18), Vector2(3, 3)), Color(0.95, 0.72, 0.20))

	draw_rect(Rect2(Vector2(-13, -7), Vector2(26, 28)), Color(0.12, 0.60, 0.42))
	draw_rect(Rect2(Vector2(-16, 18), Vector2(32, 11)), Color(0.08, 0.42, 0.30))
	draw_rect(Rect2(Vector2(-15, -5), Vector2(30, 5)), Color(0.95, 0.75, 0.22))

	draw_rect(Rect2(Vector2(-11, 28), Vector2(8, 15)), Color(0.18, 0.20, 0.18))
	draw_rect(Rect2(Vector2(4, 28), Vector2(8, 15)), Color(0.18, 0.20, 0.18))

	draw_line(Vector2(-21, -12), Vector2(-29, 28), Color(0.98, 0.76, 0.24), 3.0)
	draw_line(Vector2(-29, 28), Vector2(-33, 5), Color(0.98, 0.76, 0.24), 2.0)


func _draw_sera() -> void:
	draw_rect(Rect2(Vector2(-15, -31), Vector2(30, 22)), Color(0.38, 0.08, 0.16))
	draw_rect(Rect2(Vector2(-18, -24), Vector2(8, 38)), Color(0.45, 0.08, 0.18))
	draw_rect(Rect2(Vector2(-10, -25), Vector2(20, 18)), Color(1.0, 0.80, 0.70))

	draw_rect(Rect2(Vector2(-6, -18), Vector2(3, 3)), Color(1.0, 0.38, 0.48))
	draw_rect(Rect2(Vector2(4, -18), Vector2(3, 3)), Color(1.0, 0.38, 0.48))

	draw_rect(Rect2(Vector2(-13, -7), Vector2(26, 27)), Color(0.62, 0.12, 0.24))
	draw_rect(Rect2(Vector2(-18, 17), Vector2(36, 13)), Color(0.78, 0.18, 0.32))

	draw_rect(Rect2(Vector2(-11, 29), Vector2(8, 14)), Color(0.22, 0.18, 0.22))
	draw_rect(Rect2(Vector2(4, 29), Vector2(8, 14)), Color(0.22, 0.18, 0.22))

	draw_line(Vector2(-20, 18), Vector2(-35, -16), Color(0.86, 0.94, 1.0), 5.0)
