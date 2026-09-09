extends CharacterBody2D

signal defeated

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/Projectile.tscn")

const MOVE_SPEED: float = 300.0
const MAX_HP: int = 200

const MIN_X: float = 34.0
const MAX_X: float = 1246.0
const MIN_Y: float = 472.0
const MAX_Y: float = 686.0

var hp: int = MAX_HP
var active: bool = false
var character_index: int = 0
var character_name: String = "ARIA"

var body_color: Color = Color(0.55, 0.35, 0.95)
var accent_color: Color = Color(0.25, 0.85, 1.0)
var hair_color: Color = Color(0.20, 0.15, 0.38)

var move_direction: Vector2 = Vector2.ZERO

var basic_cooldown: float = 0.0
var q_cooldown: float = 0.0
var e_cooldown: float = 0.0
var shift_cooldown: float = 0.0
var r_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("player")
	set_active(false)
	queue_redraw()

func configure_character(index: int) -> void:
	character_index = index

	match character_index:
		0:
			character_name = "ARIA"
			body_color = Color(0.58, 0.32, 0.92)
			accent_color = Color(0.25, 0.85, 1.0)
			hair_color = Color(0.16, 0.10, 0.32)

		1:
			character_name = "LYRA"
			body_color = Color(0.16, 0.70, 0.55)
			accent_color = Color(1.0, 0.78, 0.22)
			hair_color = Color(0.10, 0.28, 0.24)

		2:
			character_name = "SERA"
			body_color = Color(0.88, 0.27, 0.42)
			accent_color = Color(1.0, 0.70, 0.82)
			hair_color = Color(0.38, 0.08, 0.16)

	hp = MAX_HP
	_reset_cooldowns()
	queue_redraw()

func set_active(value: bool) -> void:
	active = value
	set_physics_process(value)
	set_process_unhandled_input(value)

func reset_for_battle() -> void:
	hp = MAX_HP
	position = Vector2(300.0, 585.0)
	velocity = Vector2.ZERO
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
	_update_movement()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
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

	velocity = move_direction * MOVE_SPEED
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
	direction: Vector2,
	speed: float,
	damage: int,
	radius: float,
	color: Color,
	style: int
) -> void:
	var projectile := PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.add_to_group("player_projectile")
	projectile.setup(
		global_position + direction.normalized() * 34.0,
		direction,
		speed,
		damage,
		&"enemy",
		radius,
		color,
		style
	)

func _use_basic_attack() -> void:
	if basic_cooldown > 0.0:
		return

	match character_index:
		0:
			basic_cooldown = 0.38
			_spawn_projectile(_aim_direction(), 760.0, 18, 7.0, accent_color, 0)
		1:
			basic_cooldown = 0.45
			_spawn_projectile(_aim_direction(), 880.0, 20, 6.0, accent_color, 2)
		2:
			basic_cooldown = 0.32
			_spawn_projectile(_aim_direction(), 800.0, 16, 8.0, accent_color, 4)

func _use_q_skill() -> void:
	if q_cooldown > 0.0:
		return

	match character_index:
		0:
			q_cooldown = 2.5
			_spawn_projectile(_aim_direction(), 960.0, 40, 11.0, Color(0.30, 0.92, 1.0), 1)
		1:
			q_cooldown = 2.8
			_spawn_projectile(_aim_direction(), 1100.0, 44, 10.0, Color(1.0, 0.75, 0.18), 2)
		2:
			q_cooldown = 2.2
			_spawn_projectile(_aim_direction(), 1000.0, 36, 12.0, Color(1.0, 0.45, 0.62), 4)

func _use_e_skill() -> void:
	if e_cooldown > 0.0:
		return

	var base_dir := _aim_direction()

	match character_index:
		0:
			e_cooldown = 4.0
			for angle in [-0.16, 0.0, 0.16]:
				_spawn_projectile(base_dir.rotated(angle), 720.0, 16, 7.0, Color(0.60, 0.35, 1.0), 0)

		1:
			e_cooldown = 4.5
			for angle in [-0.24, -0.12, 0.0, 0.12, 0.24]:
				_spawn_projectile(base_dir.rotated(angle), 820.0, 11, 5.0, Color(0.95, 0.88, 0.30), 2)

		2:
			e_cooldown = 3.6
			_spawn_projectile(base_dir.rotated(-0.10), 850.0, 23, 10.0, accent_color, 4)
			_spawn_projectile(base_dir.rotated(0.10), 850.0, 23, 10.0, accent_color, 4)

func _use_shift_skill() -> void:
	if shift_cooldown > 0.0:
		return

	var dash_dir := move_direction
	if dash_dir.length() <= 0.001:
		dash_dir = _aim_direction()

	match character_index:
		0:
			shift_cooldown = 5.0
			position += dash_dir.normalized() * 145.0
		1:
			shift_cooldown = 4.4
			position += dash_dir.normalized() * 120.0
		2:
			shift_cooldown = 4.0
			position += dash_dir.normalized() * 175.0

	position.x = clampf(position.x, MIN_X, MAX_X)
	position.y = clampf(position.y, MIN_Y, MAX_Y)

func _use_r_skill() -> void:
	if r_cooldown > 0.0:
		return

	match character_index:
		0:
			r_cooldown = 8.0
			_spawn_projectile(_aim_direction(), 620.0, 82, 21.0, Color(0.70, 0.25, 1.0), 3)
		1:
			r_cooldown = 8.5
			_spawn_projectile(_aim_direction(), 940.0, 88, 18.0, Color(1.0, 0.58, 0.10), 2)
		2:
			r_cooldown = 7.5
			for angle in [-0.10, 0.0, 0.10]:
				_spawn_projectile(_aim_direction().rotated(angle), 760.0, 38, 16.0, Color(1.0, 0.18, 0.42), 4)

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
	# Stylized original female fighter placeholders made with vector shapes.
	# These are intentionally original temporary assets, not third-party game characters.
	match character_index:
		0:
			# ARIA - arcane mage
			draw_circle(Vector2(0.0, -16.0), 15.0, Color(1.0, 0.80, 0.70))
			draw_circle(Vector2(-7.0, -23.0), 12.0, hair_color)
			draw_circle(Vector2(8.0, -22.0), 11.0, hair_color)
			draw_polygon(PackedVector2Array([
				Vector2(-18.0, -2.0), Vector2(18.0, -2.0),
				Vector2(25.0, 28.0), Vector2(-25.0, 28.0)
			]), PackedColorArray([body_color]))
			draw_circle(Vector2(0.0, 7.0), 5.0, accent_color)
			draw_line(Vector2(22.0, 5.0), Vector2(33.0, -24.0), Color(0.8, 0.7, 0.5), 4.0)
			draw_circle(Vector2(35.0, -28.0), 7.0, accent_color)

		1:
			# LYRA - ranger
			draw_circle(Vector2(0.0, -16.0), 15.0, Color(1.0, 0.82, 0.70))
			draw_polygon(PackedVector2Array([
				Vector2(-17.0, -30.0), Vector2(17.0, -28.0),
				Vector2(12.0, -11.0), Vector2(-13.0, -9.0)
			]), PackedColorArray([hair_color]))
			draw_polygon(PackedVector2Array([
				Vector2(-19.0, -2.0), Vector2(19.0, -2.0),
				Vector2(18.0, 27.0), Vector2(-18.0, 27.0)
			]), PackedColorArray([body_color]))
			draw_arc(Vector2(27.0, 2.0), 18.0, -1.4, 1.4, 16, accent_color, 3.0)
			draw_line(Vector2(27.0, -16.0), Vector2(27.0, 20.0), accent_color, 2.0)

		2:
			# SERA - blade fighter
			draw_circle(Vector2(0.0, -16.0), 15.0, Color(1.0, 0.78, 0.68))
			draw_circle(Vector2(-8.0, -24.0), 13.0, hair_color)
			draw_line(Vector2(-17.0, -25.0), Vector2(-25.0, 4.0), hair_color, 8.0)
			draw_polygon(PackedVector2Array([
				Vector2(-20.0, -2.0), Vector2(20.0, -2.0),
				Vector2(23.0, 27.0), Vector2(-23.0, 27.0)
			]), PackedColorArray([body_color]))
			draw_line(Vector2(21.0, 7.0), Vector2(39.0, -18.0), Color(0.85, 0.90, 1.0), 5.0)
			draw_line(Vector2(39.0, -18.0), Vector2(43.0, -24.0), accent_color, 2.0)

	var aim := _aim_direction()
	draw_line(Vector2.ZERO, aim * 36.0, Color(1.0, 1.0, 1.0, 0.75), 2.0)
