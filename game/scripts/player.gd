extends CharacterBody2D

signal defeated
signal ultimate_used(character_index: int)

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/Projectile.tscn")

const MAX_HP: int = 200

const MIN_X: float = 34.0
const MAX_X: float = 1246.0
const MIN_Y: float = 472.0
const MAX_Y: float = 686.0

var hp: int = MAX_HP
var active: bool = false

var character_index: int = 0
var character_name: String = "ARIA"

var move_speed: float = 300.0
var terrain_speed_multiplier: float = 1.0
var terrain_is_ice: bool = false
var move_direction: Vector2 = Vector2.ZERO

var basic_cooldown: float = 0.0
var q_cooldown: float = 0.0
var e_cooldown: float = 0.0
var shift_cooldown: float = 0.0
var r_cooldown: float = 0.0

var cast_timer: float = 0.0
var dash_timer: float = 0.0
var invulnerable_timer: float = 0.0
var deflect_timer: float = 0.0
var hit_flash_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	set_active(false)
	queue_redraw()


func configure_character(index: int) -> void:
	character_index = index

	match character_index:
		0:
			character_name = "ARIA"
			move_speed = 285.0

		1:
			character_name = "LYRA"
			move_speed = 310.0

		2:
			character_name = "SERA"
			move_speed = 335.0

	hp = MAX_HP
	_reset_cooldowns()
	queue_redraw()


func set_active(value: bool) -> void:
	active = value
	set_physics_process(value)
	set_process_unhandled_input(value)


func set_terrain_speed_multiplier(value: float) -> void:
	terrain_speed_multiplier = clampf(value, 0.35, 1.50)


func set_terrain_ice(value: bool) -> void:
	terrain_is_ice = value


func reset_terrain_effects() -> void:
	terrain_speed_multiplier = 1.0
	terrain_is_ice = false


func reset_for_battle() -> void:
	hp = MAX_HP
	position = Vector2(300.0, 585.0)
	velocity = Vector2.ZERO

	cast_timer = 0.0
	dash_timer = 0.0
	invulnerable_timer = 0.0
	deflect_timer = 0.0
	hit_flash_timer = 0.0
	terrain_speed_multiplier = 1.0
	terrain_is_ice = false

	_reset_cooldowns()
	queue_redraw()


func _reset_cooldowns() -> void:
	basic_cooldown = 0.0
	q_cooldown = 0.0
	e_cooldown = 0.0
	shift_cooldown = 0.0
	r_cooldown = 0.0


func _physics_process(delta: float) -> void:
	if not active:
		return

	_update_cooldowns(delta)

	cast_timer = maxf(0.0, cast_timer - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
	deflect_timer = maxf(0.0, deflect_timer - delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)

	if deflect_timer > 0.0:
		_process_deflect()

	_update_movement()

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if (
			mouse_event.button_index == MOUSE_BUTTON_LEFT
			and mouse_event.pressed
		):
			_use_basic_attack()

	if event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed or key_event.echo:
			return

		match key_event.physical_keycode:
			KEY_Q:
				_use_q_skill()

			KEY_E:
				_use_e_skill()

			KEY_SHIFT:
				_use_shift_skill()

			KEY_R:
				_use_r_skill()


func _update_movement() -> void:
	move_direction = Vector2.ZERO

	if Input.is_physical_key_pressed(KEY_A):
		move_direction.x -= 1.0

	if Input.is_physical_key_pressed(KEY_D):
		move_direction.x += 1.0

	if Input.is_physical_key_pressed(KEY_W):
		move_direction.y -= 1.0

	if Input.is_physical_key_pressed(KEY_S):
		move_direction.y += 1.0

	if move_direction.length() > 0.0:
		move_direction = move_direction.normalized()

	var target_velocity := (
		move_direction
		* move_speed
		* terrain_speed_multiplier
	)

	if terrain_is_ice:
		# 빙판에서는 더 잘 미끄러지고 급정지가 어렵다.
		target_velocity *= 1.18
		velocity = velocity.lerp(target_velocity, 0.075)
	else:
		velocity = target_velocity

	if dash_timer > 0.0:
		velocity *= 1.25

	move_and_slide()

	position.x = clampf(position.x, MIN_X, MAX_X)
	position.y = clampf(position.y, MIN_Y, MAX_Y)


func _update_cooldowns(delta: float) -> void:
	basic_cooldown = maxf(0.0, basic_cooldown - delta)
	q_cooldown = maxf(0.0, q_cooldown - delta)
	e_cooldown = maxf(0.0, e_cooldown - delta)
	shift_cooldown = maxf(0.0, shift_cooldown - delta)
	r_cooldown = maxf(0.0, r_cooldown - delta)


func _aim_direction() -> Vector2:
	var aim := get_global_mouse_position() - global_position

	if aim.length() <= 0.001:
		return Vector2.UP

	return aim.normalized()


func _spawn_projectile(
	spawn_position: Vector2,
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
		spawn_position,
		direction,
		speed,
		damage,
		&"enemy",
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


func _spawn_from_self(
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
	var start := global_position + direction.normalized() * 36.0

	_spawn_projectile(
		start,
		direction,
		speed,
		damage,
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


# =========================================================
# BASIC ATTACK
# =========================================================

func _use_basic_attack() -> void:
	if basic_cooldown > 0.0:
		return

	cast_timer = 0.12
	var aim := _aim_direction()

	match character_index:
		# ARIA: 안정적인 마법탄
		0:
			basic_cooldown = 0.42

			_spawn_from_self(
				aim,
				760.0,
				17,
				7.0,
				Color(0.35, 0.85, 1.0),
				0,
				0,
				1050.0
			)

		# LYRA: 가장 빠른 기본 화살
		1:
			basic_cooldown = 0.34

			_spawn_from_self(
				aim,
				1040.0,
				16,
				5.0,
				Color(1.0, 0.82, 0.24),
				2,
				0,
				1250.0
			)

		# SERA: 짧지만 넓은 검기
		2:
			basic_cooldown = 0.30

			_spawn_from_self(
				aim,
				720.0,
				15,
				10.0,
				Color(1.0, 0.35, 0.52),
				4,
				0,
				720.0
			)


# =========================================================
# Q
# =========================================================

func _use_q_skill() -> void:
	if q_cooldown > 0.0:
		return

	cast_timer = 0.22
	var aim := _aim_direction()

	match character_index:
		# ARIA Q: 관통하는 초고속 Arcane Lance
		0:
			q_cooldown = 3.0

			_spawn_from_self(
				aim,
				1220.0,
				42,
				9.0,
				Color(0.38, 0.94, 1.0),
				1,
				2,
				1500.0,
				1,
				0.0,
				0.0,
				540.0
			)

		# LYRA Q: 초장거리 Piercing Shot.
		# 속도가 매우 빠르고 2회 관통한다.
		1:
			q_cooldown = 3.2

			_spawn_from_self(
				aim,
				1500.0,
				52,
				6.0,
				Color(1.0, 0.68, 0.12),
				2,
				2,
				1800.0,
				2,
				0.0,
				0.0,
				480.0
			)

		# SERA Q: 크고 짧은 Crescent Slash
		2:
			q_cooldown = 2.15

			_spawn_from_self(
				aim,
				650.0,
				38,
				16.0,
				Color(1.0, 0.42, 0.58),
				4,
				0,
				680.0
			)


# =========================================================
# E
# =========================================================

func _use_e_skill() -> void:
	if e_cooldown > 0.0:
		return

	cast_timer = 0.28
	var aim := _aim_direction()

	match character_index:
		# ARIA E: Arcane Spiral.
		# 6개의 마력 파편이 서로 다른 곡선 궤적으로 공간을 막는다.
		0:
			e_cooldown = 5.0

			for i in range(6):
				var side: float = -1.0 if i % 2 == 0 else 1.0
				var angle_offset: float = float(i - 2) * 0.055

				_spawn_from_self(
					aim.rotated(angle_offset),
					620.0 + float(i) * 24.0,
					15,
					7.0,
					Color(0.58 + float(i) * 0.045, 0.36, 1.0),
					5,
					1,
					950.0,
					0,
					side * (28.0 + float(i) * 7.0),
					5.2 + float(i) * 0.22
				)

		# LYRA E: 부채꼴 5연사
		1:
			e_cooldown = 4.7

			for angle in [-0.28, -0.14, 0.0, 0.14, 0.28]:
				_spawn_from_self(
					aim.rotated(angle),
					900.0,
					12,
					5.0,
					Color(0.95, 0.90, 0.32),
					2,
					0,
					980.0
				)

		# SERA E: Deflect
		# 0.65초 동안 주변 적 투사체를 되받아친다.
		# 반사된 투사체는 적을 노리고 피해량이 20% 증가한다.
		2:
			e_cooldown = 5.2
			deflect_timer = 0.65


# =========================================================
# SHIFT
# =========================================================

func _use_shift_skill() -> void:
	if shift_cooldown > 0.0:
		return

	var direction := move_direction

	if direction.length() <= 0.001:
		direction = _aim_direction()

	direction = direction.normalized()

	match character_index:
		# ARIA: Blink. 가장 긴 무적 순간이동.
		0:
			shift_cooldown = 5.2
			invulnerable_timer = 0.28
			position += direction * 175.0

		# LYRA: Roll. 짧지만 재사용이 빠름.
		1:
			shift_cooldown = 3.8
			invulnerable_timer = 0.16
			dash_timer = 0.20
			position += direction * 125.0

		# SERA: Shadow Dash + 양옆 검기 발생.
		2:
			shift_cooldown = 4.4
			invulnerable_timer = 0.20

			var old_position := global_position

			position += direction * 205.0

			var side := Vector2(-direction.y, direction.x)

			_spawn_projectile(
				old_position,
				direction.rotated(-0.08),
				900.0,
				18,
				10.0,
				Color(1.0, 0.25, 0.42),
				4,
				0,
				520.0
			)

			_spawn_projectile(
				global_position,
				direction.rotated(0.08),
				900.0,
				18,
				10.0,
				Color(1.0, 0.58, 0.70),
				4,
				0,
				520.0
			)

	position.x = clampf(position.x, MIN_X, MAX_X)
	position.y = clampf(position.y, MIN_Y, MAX_Y)

	dash_timer = maxf(dash_timer, 0.13)
	queue_redraw()


# =========================================================
# R - ULTIMATE
# =========================================================

func _use_r_skill() -> void:
	if r_cooldown > 0.0:
		return

	cast_timer = 0.42
	ultimate_used.emit(character_index)

	var aim := _aim_direction()

	match character_index:
		# ARIA R: 느리게 커지며 관통하는 대형 Arcane Core
		0:
			r_cooldown = 9.0

			_spawn_from_self(
				aim,
				470.0,
				82,
				19.0,
				Color(0.72, 0.28, 1.0),
				3,
				0,
				1350.0,
				2,
				0.0,
				0.0,
				0.0,
				6.0
			)

		# LYRA R: 조준 위치 주변에 위에서 떨어지는 Arrow Rain
		1:
			r_cooldown = 9.5

			var target_x: float = clampf(
				get_global_mouse_position().x,
				120.0,
				1160.0
			)

			for i in range(9):
				var offset: float = float(i - 4) * 38.0

				var spawn := Vector2(
					target_x + offset,
					-25.0 - absf(float(i - 4)) * 12.0
				)

				_spawn_projectile(
					spawn,
					Vector2.DOWN,
					780.0 + float(i % 3) * 70.0,
					18,
					6.0,
					Color(1.0, 0.58, 0.08),
					6,
					2,
					420.0,
					0,
					0.0,
					0.0,
					150.0
				)

		# SERA R: 좁은 부채꼴 7연속 거대 검기
		2:
			r_cooldown = 8.0

			for angle in [-0.18, -0.12, -0.06, 0.0, 0.06, 0.12, 0.18]:
				_spawn_from_self(
					aim.rotated(angle),
					780.0,
					23,
					17.0,
					Color(1.0, 0.16, 0.36),
					7,
					2,
					1050.0,
					0,
					0.0,
					0.0,
					260.0
				)



func _process_deflect() -> void:
	for node in get_tree().get_nodes_in_group("projectile"):
		if not is_instance_valid(node):
			continue

		if not node.has_method("reflect_projectile"):
			continue

		# 플레이어를 노리는 CPU 투사체만 튕겨낸다.
		if node.target_group != &"player":
			continue

		if global_position.distance_to(node.global_position) <= 108.0:
			node.reflect_projectile(
				&"enemy",
				1.20
			)

func take_damage(amount: int) -> void:
	if not active:
		return

	if invulnerable_timer > 0.0:
		return

	hp = maxi(0, hp - amount)
	hit_flash_timer = 0.12
	queue_redraw()

	if hp <= 0:
		active = false
		defeated.emit()



func heal(amount: int) -> void:
	hp = mini(MAX_HP, hp + amount)
	queue_redraw()

func get_hp_ratio() -> float:
	return float(hp) / float(MAX_HP)


# =========================================================
# PIXEL-STYLE CHARACTER DRAWING
# 외부 이미지 없이 코드로 직접 그려서 통일감 유지.
# =========================================================

func _draw() -> void:
	if deflect_timer > 0.0 and character_index == 2:
		var shield_alpha: float = 0.55 + sin(Time.get_ticks_msec() * 0.02) * 0.15

		draw_arc(
			Vector2.ZERO,
			62.0,
			0.0,
			TAU,
			32,
			Color(1.0, 0.42, 0.62, shield_alpha),
			5.0
		)

		draw_arc(
			Vector2.ZERO,
			51.0,
			0.0,
			TAU,
			32,
			Color(1.0, 0.88, 0.94, shield_alpha * 0.7),
			2.0
		)

	if dash_timer > 0.0:
		draw_rect(
			Rect2(Vector2(-32.0, -20.0), Vector2(64.0, 58.0)),
			Color(1.0, 1.0, 1.0, 0.10)
		)

	match character_index:
		0:
			_draw_aria()

		1:
			_draw_lyra()

		2:
			_draw_sera()

	if cast_timer > 0.0:
		draw_rect(
			Rect2(Vector2(-26.0, -38.0), Vector2(52.0, 4.0)),
			Color(1.0, 1.0, 1.0, 0.35)
		)


	if hit_flash_timer > 0.0:
		draw_rect(
			Rect2(Vector2(-28.0, -39.0), Vector2(56.0, 82.0)),
			Color(1.0, 0.86, 0.86, 0.32)
		)


func _draw_aria() -> void:
	# hair / head
	draw_rect(Rect2(Vector2(-13, -29), Vector2(26, 20)), Color(0.30, 0.20, 0.55))
	draw_rect(Rect2(Vector2(-10, -25), Vector2(20, 18)), Color(1.0, 0.82, 0.72))
	draw_rect(Rect2(Vector2(-15, -31), Vector2(10, 18)), Color(0.38, 0.25, 0.70))
	draw_rect(Rect2(Vector2(6, -31), Vector2(9, 21)), Color(0.38, 0.25, 0.70))

	# eyes
	draw_rect(Rect2(Vector2(-6, -18), Vector2(3, 3)), Color(0.30, 0.82, 1.0))
	draw_rect(Rect2(Vector2(4, -18), Vector2(3, 3)), Color(0.30, 0.82, 1.0))

	# body / skirt
	draw_rect(Rect2(Vector2(-13, -7), Vector2(26, 25)), Color(0.47, 0.27, 0.78))
	draw_rect(Rect2(Vector2(-18, 14), Vector2(36, 15)), Color(0.58, 0.34, 0.90))
	draw_rect(Rect2(Vector2(-6, 19), Vector2(12, 8)), Color(0.28, 0.82, 1.0))

	# legs
	draw_rect(Rect2(Vector2(-11, 28), Vector2(8, 15)), Color(0.20, 0.18, 0.30))
	draw_rect(Rect2(Vector2(4, 28), Vector2(8, 15)), Color(0.20, 0.18, 0.30))

	# staff
	draw_rect(Rect2(Vector2(18, -10), Vector2(4, 40)), Color(0.72, 0.60, 0.42))
	draw_rect(Rect2(Vector2(14, -18), Vector2(12, 12)), Color(0.28, 0.84, 1.0))


func _draw_lyra() -> void:
	# hair / face
	draw_rect(Rect2(Vector2(-13, -30), Vector2(26, 20)), Color(0.16, 0.38, 0.30))
	draw_rect(Rect2(Vector2(-10, -25), Vector2(20, 18)), Color(1.0, 0.84, 0.72))
	draw_rect(Rect2(Vector2(-15, -31), Vector2(30, 8)), Color(0.12, 0.48, 0.36))

	draw_rect(Rect2(Vector2(-6, -18), Vector2(3, 3)), Color(0.95, 0.72, 0.20))
	draw_rect(Rect2(Vector2(4, -18), Vector2(3, 3)), Color(0.95, 0.72, 0.20))

	# body
	draw_rect(Rect2(Vector2(-13, -7), Vector2(26, 28)), Color(0.12, 0.60, 0.42))
	draw_rect(Rect2(Vector2(-16, 18), Vector2(32, 11)), Color(0.08, 0.42, 0.30))

	# scarf
	draw_rect(Rect2(Vector2(-15, -5), Vector2(30, 5)), Color(0.95, 0.75, 0.22))
	draw_rect(Rect2(Vector2(9, 0), Vector2(6, 18)), Color(0.95, 0.75, 0.22))

	# legs
	draw_rect(Rect2(Vector2(-11, 28), Vector2(8, 15)), Color(0.18, 0.20, 0.18))
	draw_rect(Rect2(Vector2(4, 28), Vector2(8, 15)), Color(0.18, 0.20, 0.18))

	# bow
	draw_line(Vector2(21, -12), Vector2(29, 28), Color(0.98, 0.76, 0.24), 3.0)
	draw_line(Vector2(29, 28), Vector2(33, 5), Color(0.98, 0.76, 0.24), 2.0)
	draw_line(Vector2(21, -12), Vector2(33, 5), Color(0.92, 0.92, 0.82), 1.0)


func _draw_sera() -> void:
	# long dark-red hair
	draw_rect(Rect2(Vector2(-15, -31), Vector2(30, 22)), Color(0.38, 0.08, 0.16))
	draw_rect(Rect2(Vector2(-18, -24), Vector2(8, 38)), Color(0.45, 0.08, 0.18))
	draw_rect(Rect2(Vector2(-10, -25), Vector2(20, 18)), Color(1.0, 0.80, 0.70))

	draw_rect(Rect2(Vector2(-6, -18), Vector2(3, 3)), Color(1.0, 0.38, 0.48))
	draw_rect(Rect2(Vector2(4, -18), Vector2(3, 3)), Color(1.0, 0.38, 0.48))

	# armor / skirt
	draw_rect(Rect2(Vector2(-13, -7), Vector2(26, 27)), Color(0.62, 0.12, 0.24))
	draw_rect(Rect2(Vector2(-18, 17), Vector2(36, 13)), Color(0.78, 0.18, 0.32))
	draw_rect(Rect2(Vector2(-4, -5), Vector2(8, 24)), Color(0.92, 0.70, 0.76))

	draw_rect(Rect2(Vector2(-11, 29), Vector2(8, 14)), Color(0.22, 0.18, 0.22))
	draw_rect(Rect2(Vector2(4, 29), Vector2(8, 14)), Color(0.22, 0.18, 0.22))

	# sword
	draw_line(Vector2(20, 18), Vector2(35, -16), Color(0.86, 0.94, 1.0), 5.0)
	draw_line(Vector2(18, 16), Vector2(24, 22), Color(1.0, 0.28, 0.46), 4.0)
