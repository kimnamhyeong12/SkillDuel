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
var map_index: int = 0

var move_speed: float = 110.0
var terrain_speed_multiplier: float = 1.0
var terrain_is_ice: bool = false

var attack_interval: float = 1.6
var attack_damage: int = 11
var aim_spread: float = 0.10
var prediction_time: float = 0.0

var basic_cooldown: float = 1.0
var q_cooldown: float = 2.0
var e_cooldown: float = 3.0
var shift_cooldown: float = 3.0
var r_cooldown: float = 8.0
var think_timer: float = 0.0

var move_target: Vector2 = Vector2(980.0, 145.0)
var deflect_timer: float = 0.0
var hit_flash_timer: float = 0.0
var animation_time: float = 0.0
var dash_timer: float = 0.0
var invulnerable_timer: float = 0.0

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("enemy")
	rng.randomize()
	set_active(false)
	queue_redraw()


func configure(
	new_difficulty: int,
	new_character_index: int,
	new_map_index: int = 0
) -> void:
	difficulty = new_difficulty
	character_index = new_character_index
	map_index = new_map_index
	character_name = ["ARIA", "LYRA", "SERA"][character_index]

	match difficulty:
		0:
			move_speed = 110.0
			attack_interval = 1.60
			attack_damage = 10
			aim_spread = 0.18
			prediction_time = 0.0

		1:
			move_speed = 170.0
			attack_interval = 1.05
			attack_damage = 14
			aim_spread = 0.075
			prediction_time = 0.16

		2:
			move_speed = 230.0
			attack_interval = 0.68
			attack_damage = 18
			aim_spread = 0.025
			prediction_time = 0.34

	hp = MAX_HP
	queue_redraw()


func set_active(value: bool) -> void:
	active = value
	set_physics_process(value)


func set_terrain_speed_multiplier(value: float) -> void:
	terrain_speed_multiplier = clampf(value, 0.35, 1.50)


func set_terrain_ice(value: bool) -> void:
	terrain_is_ice = value


func reset_terrain_effects() -> void:
	terrain_speed_multiplier = 1.0
	terrain_is_ice = false


func reset_for_battle() -> void:
	hp = MAX_HP
	position = Vector2(980.0, 145.0)
	velocity = Vector2.ZERO

	basic_cooldown = attack_interval * 0.75
	q_cooldown = 2.3
	e_cooldown = 3.4
	shift_cooldown = 2.8
	r_cooldown = 9.0
	think_timer = 0.15

	move_target = Vector2(920.0, 145.0)

	terrain_speed_multiplier = 1.0
	terrain_is_ice = false
	deflect_timer = 0.0
	hit_flash_timer = 0.0
	dash_timer = 0.0
	invulnerable_timer = 0.0

	queue_redraw()


func _physics_process(delta: float) -> void:
	if not active:
		return

	_update_timers(delta)

	if deflect_timer > 0.0:
		_process_deflect()

	think_timer -= delta

	if think_timer <= 0.0:
		think_timer = _get_think_interval()
		_think()

	_move_ai()
	queue_redraw()


func _update_timers(delta: float) -> void:
	basic_cooldown = maxf(0.0, basic_cooldown - delta)
	q_cooldown = maxf(0.0, q_cooldown - delta)
	e_cooldown = maxf(0.0, e_cooldown - delta)
	shift_cooldown = maxf(0.0, shift_cooldown - delta)
	r_cooldown = maxf(0.0, r_cooldown - delta)

	deflect_timer = maxf(0.0, deflect_timer - delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	animation_time += delta
	dash_timer = maxf(0.0, dash_timer - delta)
	invulnerable_timer = maxf(0.0, invulnerable_timer - delta)


func _get_think_interval() -> float:
	match difficulty:
		0:
			return rng.randf_range(0.55, 0.82)

		1:
			return rng.randf_range(0.25, 0.40)

		2:
			return rng.randf_range(0.10, 0.18)

	return 0.4


func _think() -> void:
	var player := _get_player()

	if player == null:
		return

	var incoming := _get_nearest_incoming_projectile()

	# -----------------------------------------------------
	# 난이도가 높을수록 '인지 → 대응'이 더 정확해진다.
	# -----------------------------------------------------
	if incoming != null:
		var distance_to_threat: float = global_position.distance_to(
			incoming.global_position
		)

		# SERA는 중/상 난이도에서 위험한 탄을 보고 E를 반응형으로 사용.
		if character_index == 2 and e_cooldown <= 0.0:
			var deflect_distance: float = (
				95.0
				if difficulty == 0
				else 135.0
				if difficulty == 1
				else 180.0
			)

			if distance_to_threat <= deflect_distance:
				var react_chance: float = [0.15, 0.62, 0.94][difficulty]

				if rng.randf() <= react_chance:
					_use_sera_deflect()
					return

		# 중/상 난이도는 위험한 투사체를 보고 회피 이동기 사용.
		if shift_cooldown <= 0.0 and difficulty >= 1:
			var dodge_distance: float = (
				145.0
				if difficulty == 1
				else 220.0
			)

			if distance_to_threat <= dodge_distance:
				var dodge_chance: float = (
					0.42
					if difficulty == 1
					else 0.88
				)

				if rng.randf() <= dodge_chance:
					_use_defensive_shift(incoming)
					return

	# -----------------------------------------------------
	# 힐팩 판단.
	# 초급은 잘 못 보고, 중급은 체력이 낮으면 노리며,
	# 상급은 회복 또는 상대 힐팩 차단까지 고려한다.
	# -----------------------------------------------------
	var heal_pack := _get_heal_pack()

	if heal_pack != null and basic_cooldown <= 0.0:
		if _should_target_heal_pack(player):
			_shoot_at_position(
				heal_pack.global_position,
				true
			)
			basic_cooldown = attack_interval
			return

	# -----------------------------------------------------
	# 궁극기 판단.
	# 상급일수록 상대 HP와 위치를 보고 더 적극적으로 사용.
	# -----------------------------------------------------
	if r_cooldown <= 0.0:
		if _should_use_ultimate(player):
			_use_r_skill(player)
			return

	# 캐릭터별 일반 스킬 판단
	var skill_roll: float = rng.randf()

	if q_cooldown <= 0.0 and skill_roll < [0.18, 0.42, 0.68][difficulty]:
		_use_q_skill(player)
		return

	if e_cooldown <= 0.0 and skill_roll < [0.30, 0.62, 0.84][difficulty]:
		_use_e_skill(player)
		return

	# 기본 공격
	if basic_cooldown <= 0.0:
		_shoot_basic()
		basic_cooldown = attack_interval

	# 이동 의사결정도 난이도별로 다름.
	_choose_move_target(player, incoming)


func _should_target_heal_pack(player: Node2D) -> bool:
	if difficulty == 0:
		return hp <= 75 and rng.randf() < 0.22

	if difficulty == 1:
		if hp <= 135:
			return rng.randf() < 0.66

		return false

	# HARD:
	# 체력이 조금이라도 깎였으면 적극적으로 회복.
	if hp <= 175:
		return rng.randf() < 0.90

	# 본인은 거의 풀피여도 상대가 약하면 힐팩을 먼저 터뜨려 차단.
	if "hp" in player and int(player.hp) <= 115:
		return rng.randf() < 0.50

	return false


func _should_use_ultimate(player: Node2D) -> bool:
	var player_hp: int = 200

	if "hp" in player:
		player_hp = int(player.hp)

	match difficulty:
		0:
			return (
				player_hp <= 55
				and rng.randf() < 0.28
			)

		1:
			return (
				player_hp <= 105
				and rng.randf() < 0.58
			)

		2:
			if player_hp <= 135:
				return rng.randf() < 0.92

			return rng.randf() < 0.22

	return false



func _character_preferred_distance() -> float:
	match character_index:
		0:
			# ARIA: 중장거리 공간 장악
			return 500.0

		1:
			# LYRA: 최대한 거리 유지
			return 650.0

		2:
			# SERA: 반사/검기를 위해 더 적극적으로 접근
			return 300.0

	return 450.0


func _apply_character_personality(
	candidate: Vector2,
	player: Node2D
) -> Vector2:
	var result := candidate
	var dx: float = absf(
		player.global_position.x
		- global_position.x
	)
	var preferred: float = _character_preferred_distance()

	if character_index == 1 and dx < preferred:
		# LYRA는 플레이어 반대쪽 끝으로 벌린다.
		result.x = (
			100.0
			if player.global_position.x > global_position.x
			else 1180.0
		)

	elif character_index == 2 and dx > preferred:
		# SERA는 상대 X축 쪽으로 접근.
		result.x = lerpf(
			global_position.x,
			player.global_position.x,
			0.55
		)

	elif character_index == 0:
		# ARIA는 너무 가깝지도 멀지도 않게 중거리 유지.
		if dx < preferred * 0.65:
			result.x = (
				120.0
				if player.global_position.x > global_position.x
				else 1160.0
			)
		elif dx > preferred * 1.35:
			result.x = lerpf(
				global_position.x,
				player.global_position.x,
				0.32
			)

	result.x = clampf(result.x, MIN_X, MAX_X)
	result.y = clampf(result.y, MIN_Y, MAX_Y)
	return result


func _choose_move_target(
	player: Node2D,
	incoming: Node
) -> void:
	if difficulty == 0:
		move_target = Vector2(
			rng.randf_range(90.0, 1190.0),
			rng.randf_range(70.0, 225.0)
		)
		return

	# incoming projectile가 있으면 탄 진행 방향의 수직 방향으로 피한다.
	if incoming != null and difficulty >= 1:
		var projectile_dir: Vector2 = incoming.direction
		var side := Vector2(
			-projectile_dir.y,
			projectile_dir.x
		)

		if rng.randf() < 0.5:
			side = -side

		var candidate := global_position + side * (
			120.0
			if difficulty == 1
			else 190.0
		)

		candidate.x = clampf(candidate.x, MIN_X, MAX_X)
		candidate.y = clampf(candidate.y, MIN_Y, MAX_Y)

		if not _is_bad_position(candidate):
			candidate = _apply_character_personality(candidate, player)
	move_target = candidate
			return

	# 체력이 낮으면 상대와 x축 거리를 벌린다.
	if hp <= 75 and difficulty == 2:
		var flee_x: float = (
			110.0
			if player.global_position.x > global_position.x
			else 1170.0
		)

		move_target = Vector2(
			flee_x,
			rng.randf_range(75.0, 220.0)
		)
		return

	# 중급은 일반 스트레이프, 상급은 플레이어 진행방향 반대쪽을 더 선호.
	var candidate := Vector2.ZERO

	if difficulty == 1:
		candidate = Vector2(
			rng.randf_range(80.0, 1200.0),
			rng.randf_range(70.0, 225.0)
		)
	else:
		var lead_x: float = player.global_position.x

		if "velocity" in player:
			lead_x += player.velocity.x * 0.55

		var offset_x: float = (
			-230.0
			if lead_x > global_position.x
			else 230.0
		)

		candidate = Vector2(
			global_position.x + offset_x + rng.randf_range(-120.0, 120.0),
			rng.randf_range(65.0, 225.0)
		)

	candidate.x = clampf(candidate.x, MIN_X, MAX_X)
	candidate.y = clampf(candidate.y, MIN_Y, MAX_Y)

	# 비맵 물웅덩이 등 불리한 위치는 중/상 난이도에서 회피.
	for attempt in range(5):
		if not _is_bad_position(candidate):
			break

		candidate = Vector2(
			rng.randf_range(80.0, 1200.0),
			rng.randf_range(65.0, 225.0)
		)

	move_target = candidate


func _is_bad_position(point: Vector2) -> bool:
	if difficulty == 0:
		return false

	var scene := get_tree().current_scene

	if scene != null and scene.has_method("is_ai_position_bad"):
		return scene.is_ai_position_bad(point)

	return false


func _move_ai() -> void:
	var to_target := move_target - global_position
	var target_velocity := Vector2.ZERO

	if to_target.length() > 8.0:
		target_velocity = (
			to_target.normalized()
			* move_speed
			* terrain_speed_multiplier
		)

	if terrain_is_ice:
		target_velocity *= 1.18
		velocity = velocity.lerp(
			target_velocity,
			0.075 if difficulty == 0 else 0.10
		)
	else:
		velocity = target_velocity

	if dash_timer > 0.0:
		velocity *= 1.30

	move_and_slide()

	position.x = clampf(position.x, MIN_X, MAX_X)
	position.y = clampf(position.y, MIN_Y, MAX_Y)


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")

	if players.is_empty():
		return null

	return players[0] as Node2D


func _get_heal_pack() -> Node2D:
	var packs := get_tree().get_nodes_in_group("heal_pack")

	if packs.is_empty():
		return null

	return packs[0] as Node2D


func _get_nearest_incoming_projectile() -> Node:
	var nearest: Node = null
	var nearest_distance: float = INF

	for node in get_tree().get_nodes_in_group("projectile"):
		if not is_instance_valid(node):
			continue

		if not "target_group" in node:
			continue

		if node.target_group != &"enemy":
			continue

		var distance: float = global_position.distance_to(
			node.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest = node

	return nearest


func _predicted_aim_position(player: Node2D) -> Vector2:
	var target_position: Vector2 = player.global_position

	if difficulty >= 1 and "velocity" in player:
		target_position += player.velocity * prediction_time

	return target_position


func _aim_at_player() -> Vector2:
	var player := _get_player()

	if player == null:
		return Vector2.DOWN

	var target_position := _predicted_aim_position(player)
	var dir := (
		target_position
		- global_position
	).normalized()

	return dir.rotated(
		rng.randf_range(
			-aim_spread,
			aim_spread
		)
	)


func _spawn(
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
	_spawn(
		global_position + direction.normalized() * 34.0,
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


func _shoot_basic() -> void:
	var dir := _aim_at_player()

	match character_index:
		0:
			_spawn_from_self(
				dir,
				570.0,
				attack_damage,
				7.0,
				Color(0.35, 0.85, 1.0),
				0,
				0,
				1050.0
			)

		1:
			_spawn_from_self(
				dir,
				770.0,
				attack_damage,
				5.0,
				Color(1.0, 0.82, 0.24),
				2,
				0,
				1250.0
			)

		2:
			_spawn_from_self(
				dir,
				650.0,
				attack_damage,
				9.0,
				Color(1.0, 0.35, 0.52),
				4,
				0,
				720.0
			)


func _shoot_at_position(
	target_position: Vector2,
	heal_pack_shot: bool = false
) -> void:
	var dir := (
		target_position
		- global_position
	).normalized()

	var speed: float = (
		900.0
		if heal_pack_shot and difficulty == 2
		else 720.0
	)

	_spawn_from_self(
		dir,
		speed,
		attack_damage,
		6.0,
		Color(0.88, 0.95, 1.0),
		2 if character_index == 1 else 0,
		0,
		1250.0
	)


# =========================================================
# AI Q / E / SHIFT / R
# =========================================================

func _use_q_skill(player: Node2D) -> void:
	var dir := _aim_at_player()

	match character_index:
		0:
			q_cooldown = 3.0

			_spawn_from_self(
				dir,
				1220.0,
				38 + difficulty * 4,
				9.0,
				Color(0.38, 0.94, 1.0),
				1,
				2,
				1500.0,
				1,
				0.0,
				0.0,
				520.0
			)

		1:
			q_cooldown = 3.2

			_spawn_from_self(
				dir,
				1450.0,
				44 + difficulty * 4,
				6.0,
				Color(1.0, 0.68, 0.12),
				2,
				2,
				1800.0,
				2,
				0.0,
				0.0,
				460.0
			)

		2:
			q_cooldown = 2.2

			_spawn_from_self(
				dir,
				660.0,
				34 + difficulty * 4,
				16.0,
				Color(1.0, 0.42, 0.58),
				4,
				0,
				680.0
			)


func _use_e_skill(player: Node2D) -> void:
	var dir := _aim_at_player()

	match character_index:
		# ARIA: 다중 곡선 파편
		0:
			e_cooldown = 5.0

			for i in range(6):
				var side: float = -1.0 if i % 2 == 0 else 1.0
				var angle_offset: float = float(i - 2) * 0.055

				_spawn_from_self(
					dir.rotated(angle_offset),
					580.0 + float(i) * 22.0,
					13 + difficulty,
					7.0,
					Color(0.60 + float(i) * 0.04, 0.38, 1.0),
					5,
					1,
					940.0,
					0,
					side * (25.0 + float(i) * 6.0),
					5.0 + float(i) * 0.2
				)

		# LYRA: 5방향 부채꼴
		1:
			e_cooldown = 4.7

			for angle in [-0.28, -0.14, 0.0, 0.14, 0.28]:
				_spawn_from_self(
					dir.rotated(angle),
					920.0,
					11 + difficulty,
					5.0,
					Color(0.95, 0.90, 0.32),
					2,
					0,
					1000.0
				)

		# SERA: 일반 판단에서 쓸 경우에도 Deflect
		2:
			_use_sera_deflect()


func _use_sera_deflect() -> void:
	e_cooldown = 5.2
	deflect_timer = (
		0.42
		if difficulty == 0
		else 0.58
		if difficulty == 1
		else 0.72
	)


func _use_defensive_shift(incoming: Node) -> void:
	var projectile_dir: Vector2 = incoming.direction
	var dodge_dir := Vector2(
		-projectile_dir.y,
		projectile_dir.x
	)

	if rng.randf() < 0.5:
		dodge_dir = -dodge_dir

	dodge_dir = dodge_dir.normalized()

	match character_index:
		0:
			shift_cooldown = 5.0
			invulnerable_timer = 0.20
			position += dodge_dir * 165.0

		1:
			shift_cooldown = 3.8
			invulnerable_timer = 0.14
			dash_timer = 0.18
			position += dodge_dir * 125.0

		2:
			shift_cooldown = 4.4
			invulnerable_timer = 0.18
			dash_timer = 0.16
			position += dodge_dir * 190.0

	position.x = clampf(position.x, MIN_X, MAX_X)
	position.y = clampf(position.y, MIN_Y, MAX_Y)
	move_target = position


func _use_r_skill(player: Node2D) -> void:
	var dir := _aim_at_player()
	ultimate_used.emit(character_index)

	match character_index:
		0:
			r_cooldown = 9.5

			_spawn_from_self(
				dir,
				480.0,
				72 + difficulty * 5,
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

		1:
			r_cooldown = 10.0

			var target_x: float = clampf(
				_predicted_aim_position(player).x,
				120.0,
				1160.0
			)

			for i in range(9):
				var offset: float = float(i - 4) * 38.0
				var spawn := Vector2(
					target_x + offset,
					745.0 + absf(float(i - 4)) * 12.0
				)

				_spawn(
					spawn,
					Vector2.UP,
					790.0 + float(i % 3) * 70.0,
					16 + difficulty,
					6.0,
					Color(1.0, 0.58, 0.08),
					6,
					2,
					430.0,
					0,
					0.0,
					0.0,
					160.0
				)

		2:
			r_cooldown = 8.4

			for angle in [-0.18, -0.12, -0.06, 0.0, 0.06, 0.12, 0.18]:
				_spawn_from_self(
					dir.rotated(angle),
					790.0,
					20 + difficulty * 2,
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

		if node.target_group != &"enemy":
			continue

		if global_position.distance_to(node.global_position) <= 104.0:
			node.reflect_projectile(
				&"player",
				1.15
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


func _draw() -> void:
	if deflect_timer > 0.0 and character_index == 2:
		var shield_alpha: float = 0.48 + sin(Time.get_ticks_msec() * 0.02) * 0.14

		draw_arc(
			Vector2.ZERO,
			58.0,
			0.0,
			TAU,
			32,
			Color(1.0, 0.42, 0.62, shield_alpha),
			4.0
		)


	var bob: float = sin(animation_time * 4.0) * 1.6
	var tilt: float = 0.0

	if velocity.length() > 20.0:
		bob = sin(animation_time * 9.0) * 2.5
		tilt = clampf(velocity.x / 1800.0, -0.08, 0.08)

	if hp <= 0:
		tilt = -1.35
		bob = 10.0

	draw_set_transform(
		Vector2(0.0, bob),
		tilt,
		Vector2.ONE
	)

	# CPU도 플레이어와 같은 픽셀 캐릭터 계열로 표현
	match character_index:
		0:
			_draw_aria()

		1:
			_draw_lyra()

		2:
			_draw_sera()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if hit_flash_timer > 0.0:
		draw_rect(
			Rect2(Vector2(-28.0, -39.0), Vector2(56.0, 82.0)),
			Color(1.0, 0.86, 0.86, 0.32)
		)


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
