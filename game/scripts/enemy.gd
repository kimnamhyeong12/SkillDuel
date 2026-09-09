extends CharacterBody2D

signal defeated

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

var body_color: Color = Color(0.16, 0.70, 0.55)
var accent_color: Color = Color(1.0, 0.78, 0.22)
var hair_color: Color = Color(0.10, 0.28, 0.24)

var move_speed: float = 110.0
var attack_interval: float = 1.6
var attack_damage: int = 11
var aim_spread: float = 0.10

var shoot_cooldown: float = 1.0
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
	_apply_character_visuals()
	_apply_difficulty()
	hp = MAX_HP
	shoot_cooldown = attack_interval * 0.65
	queue_redraw()

func _apply_character_visuals() -> void:
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

func _apply_difficulty() -> void:
	match difficulty:
		0:
			move_speed = 105.0
			attack_interval = 1.65
			attack_damage = 10
			aim_spread = 0.18
		1:
			move_speed = 165.0
			attack_interval = 1.10
			attack_damage = 15
			aim_spread = 0.08
		2:
			move_speed = 235.0
			attack_interval = 0.72
			attack_damage = 20
			aim_spread = 0.025

func set_active(value: bool) -> void:
	active = value
	set_physics_process(value)

func reset_for_battle() -> void:
	hp = MAX_HP
	position = Vector2(980.0, 145.0)
	velocity = Vector2.ZERO
	shoot_cooldown = attack_interval * 0.65
	decision_timer = 0.0
	move_target = Vector2(920.0, 145.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not active:
		return

	decision_timer -= delta
	if decision_timer <= 0.0:
		_choose_move_target()

	var to_target := move_target - position
	if to_target.length() > 8.0:
		velocity = to_target.normalized() * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	position.x = clampf(position.x, MIN_X, MAX_X)
	position.y = clampf(position.y, MIN_Y, MAX_Y)

	shoot_cooldown -= delta
	if shoot_cooldown <= 0.0:
		shoot_cooldown = attack_interval
		_shoot_at_player()

	queue_redraw()

func _choose_move_target() -> void:
	match difficulty:
		0:
			decision_timer = 1.25
		1:
			decision_timer = 0.75
		2:
			decision_timer = 0.38

	move_target = Vector2(
		rng.randf_range(90.0, 1190.0),
		rng.randf_range(70.0, 225.0)
	)

func _shoot_at_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var target := players[0] as Node2D
	var dir := (target.global_position - global_position).normalized()
	dir = dir.rotated(rng.randf_range(-aim_spread, aim_spread))

	var speed: float = 530.0
	var radius: float = 7.0
	var style: int = 0

	match character_index:
		0:
			speed = 540.0
			radius = 8.0
			style = 0
		1:
			speed = 680.0
			radius = 6.0
			style = 2
		2:
			speed = 620.0
			radius = 8.0
			style = 4

	var projectile := PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.add_to_group("enemy_projectile")
	projectile.setup(
		global_position + dir * 34.0,
		dir,
		speed,
		attack_damage,
		&"player",
		radius,
		accent_color,
		style
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
	# Same original roster, mirrored as CPU fighter.
	match character_index:
		0:
			draw_circle(Vector2(0.0, -16.0), 15.0, Color(1.0, 0.80, 0.70))
			draw_circle(Vector2(-7.0, -23.0), 12.0, hair_color)
			draw_circle(Vector2(8.0, -22.0), 11.0, hair_color)
			draw_polygon(PackedVector2Array([
				Vector2(-18.0, -2.0), Vector2(18.0, -2.0),
				Vector2(25.0, 28.0), Vector2(-25.0, 28.0)
			]), PackedColorArray([body_color]))
			draw_circle(Vector2(0.0, 7.0), 5.0, accent_color)

		1:
			draw_circle(Vector2(0.0, -16.0), 15.0, Color(1.0, 0.82, 0.70))
			draw_polygon(PackedVector2Array([
				Vector2(-17.0, -30.0), Vector2(17.0, -28.0),
				Vector2(12.0, -11.0), Vector2(-13.0, -9.0)
			]), PackedColorArray([hair_color]))
			draw_polygon(PackedVector2Array([
				Vector2(-19.0, -2.0), Vector2(19.0, -2.0),
				Vector2(18.0, 27.0), Vector2(-18.0, 27.0)
			]), PackedColorArray([body_color]))
			draw_arc(Vector2(-27.0, 2.0), 18.0, 1.75, 4.55, 16, accent_color, 3.0)

		2:
			draw_circle(Vector2(0.0, -16.0), 15.0, Color(1.0, 0.78, 0.68))
			draw_circle(Vector2(-8.0, -24.0), 13.0, hair_color)
			draw_line(Vector2(-17.0, -25.0), Vector2(-25.0, 4.0), hair_color, 8.0)
			draw_polygon(PackedVector2Array([
				Vector2(-20.0, -2.0), Vector2(20.0, -2.0),
				Vector2(23.0, 27.0), Vector2(-23.0, 27.0)
			]), PackedColorArray([body_color]))
			draw_line(Vector2(-21.0, 7.0), Vector2(-39.0, -18.0), Color(0.85, 0.90, 1.0), 5.0)
