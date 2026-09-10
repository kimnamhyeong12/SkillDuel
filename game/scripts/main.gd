extends Node2D

enum GameState {
	MAIN_MENU,
	DIFFICULTY_SELECT,
	CHARACTER_SELECT,
	MAP_SELECT,
	BATTLE,
	RESULT
}

const SCREEN_SIZE: Vector2 = Vector2(1280.0, 720.0)
const RIVER_TOP: float = 280.0
const RIVER_BOTTOM: float = 440.0
const STATS_PATH: String = "user://skillduel_stats.cfg"
const HEAL_PACK_SCENE: PackedScene = preload("res://scenes/HealPack.tscn")

const MAP_ARCANE_RIVER: int = 0
const MAP_RAIN_RUINS: int = 1
const MAP_FROZEN_PASS: int = 2

var state: GameState = GameState.MAIN_MENU

var selected_difficulty: int = 0
var selected_character: int = 0
var selected_character_card: int = 0
var selected_map: int = MAP_ARCANE_RIVER
var selected_map_card: int = MAP_ARCANE_RIVER
var enemy_character: int = 1

var total_wins: int = 0
var total_losses: int = 0
var result_was_win: bool = false
var elapsed: float = 0.0

var ultimate_banner_timer: float = 0.0
var ultimate_banner_character: int = 0
var ultimate_banner_enemy: bool = false

var heal_pack_timer: float = 10.0
var heal_pack_direction: float = 1.0
var heal_message_timer: float = 0.0
var heal_message: String = ""

var impact_shake_timer: float = 0.0
var impact_shake_strength: float = 0.0
var impact_flash_timer: float = 0.0
var impact_flash_color: Color = Color.WHITE

var player_terrain_status: String = ""
var enemy_terrain_status: String = ""

var rng := RandomNumberGenerator.new()

@onready var player = $Player
@onready var enemy = $Enemy
@onready var camera: Camera2D = $Camera2D


# Main menu
var start_button := Rect2(490.0, 350.0, 300.0, 70.0)
var exit_button := Rect2(490.0, 445.0, 300.0, 58.0)

# Difficulty
var difficulty_rects: Array[Rect2] = [
	Rect2(155.0, 290.0, 290.0, 220.0),
	Rect2(495.0, 290.0, 290.0, 220.0),
	Rect2(835.0, 290.0, 290.0, 220.0)
]

# Character
var character_rects: Array[Rect2] = [
	Rect2(80.0, 205.0, 350.0, 370.0),
	Rect2(465.0, 205.0, 350.0, 370.0),
	Rect2(850.0, 205.0, 350.0, 370.0)
]
var character_start_button := Rect2(490.0, 610.0, 300.0, 60.0)

# Map select
var map_rects: Array[Rect2] = [
	Rect2(105.0, 220.0, 320.0, 330.0),
	Rect2(480.0, 220.0, 320.0, 330.0),
	Rect2(855.0, 220.0, 320.0, 330.0)
]
var map_start_button := Rect2(490.0, 610.0, 300.0, 60.0)

# Result
var retry_button := Rect2(365.0, 535.0, 250.0, 60.0)
var main_button := Rect2(665.0, 535.0, 250.0, 60.0)


# Rain puddles: top field + bottom field
var rain_puddles: Array[Rect2] = [
	Rect2(120.0, 95.0, 190.0, 82.0),
	Rect2(560.0, 175.0, 220.0, 72.0),
	Rect2(930.0, 80.0, 180.0, 86.0),
	Rect2(180.0, 520.0, 210.0, 92.0),
	Rect2(620.0, 575.0, 210.0, 82.0),
	Rect2(970.0, 500.0, 185.0, 95.0)
]

# Ice patches: top field + bottom field
var ice_zones: Array[Rect2] = [
	Rect2(150.0, 105.0, 190.0, 74.0),
	Rect2(555.0, 165.0, 220.0, 76.0),
	Rect2(960.0, 78.0, 175.0, 90.0),
	Rect2(155.0, 530.0, 205.0, 82.0),
	Rect2(600.0, 575.0, 220.0, 82.0),
	Rect2(980.0, 505.0, 175.0, 92.0)
]


func _ready() -> void:
	rng.randomize()
	_load_stats()

	player.defeated.connect(_on_player_defeated)
	enemy.defeated.connect(_on_enemy_defeated)
	player.ultimate_used.connect(_on_player_ultimate_used)

	if enemy.has_signal("ultimate_used"):
		enemy.ultimate_used.connect(_on_enemy_ultimate_used)

	_hide_battle_objects()
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta

	ultimate_banner_timer = maxf(
		0.0,
		ultimate_banner_timer - delta
	)

	heal_message_timer = maxf(
		0.0,
		heal_message_timer - delta
	)


	impact_shake_timer = maxf(
		0.0,
		impact_shake_timer - delta
	)

	impact_flash_timer = maxf(
		0.0,
		impact_flash_timer - delta
	)

	if impact_shake_timer > 0.0:
		camera.offset = Vector2(
			rng.randf_range(
				-impact_shake_strength,
				impact_shake_strength
			),
			rng.randf_range(
				-impact_shake_strength,
				impact_shake_strength
			)
		)
	else:
		camera.offset = Vector2.ZERO

	if state == GameState.BATTLE:
		_update_map_effects(delta)
		_update_heal_pack(delta)
	else:
		_clear_terrain_effects()

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey

		if (
			key_event.pressed
			and not key_event.echo
			and key_event.physical_keycode == KEY_ESCAPE
		):
			if state == GameState.DIFFICULTY_SELECT:
				_go_to_main_menu()

			elif state == GameState.CHARACTER_SELECT:
				state = GameState.DIFFICULTY_SELECT
				queue_redraw()

			elif state == GameState.MAP_SELECT:
				state = GameState.CHARACTER_SELECT
				queue_redraw()

	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton

	if (
		mouse_event.button_index != MOUSE_BUTTON_LEFT
		or not mouse_event.pressed
	):
		return

	var pos := mouse_event.position

	match state:
		GameState.MAIN_MENU:
			if start_button.has_point(pos):
				state = GameState.DIFFICULTY_SELECT
				queue_redraw()

			elif exit_button.has_point(pos):
				get_tree().quit()

		GameState.DIFFICULTY_SELECT:
			for i in range(difficulty_rects.size()):
				if difficulty_rects[i].has_point(pos):
					selected_difficulty = i
					selected_character_card = 0
					state = GameState.CHARACTER_SELECT
					queue_redraw()
					return

		GameState.CHARACTER_SELECT:
			for i in range(character_rects.size()):
				if character_rects[i].has_point(pos):
					selected_character_card = i
					queue_redraw()
					return

			if character_start_button.has_point(pos):
				selected_character = selected_character_card
				selected_map_card = selected_map
				state = GameState.MAP_SELECT
				queue_redraw()
				return

		GameState.MAP_SELECT:
			for i in range(map_rects.size()):
				if map_rects[i].has_point(pos):
					selected_map_card = i
					queue_redraw()
					return

			if map_start_button.has_point(pos):
				selected_map = selected_map_card
				_start_battle()
				return

		GameState.RESULT:
			if retry_button.has_point(pos):
				_go_to_difficulty_select()

			elif main_button.has_point(pos):
				_go_to_main_menu()


func _start_battle() -> void:
	_clear_projectiles()
	_clear_terrain_effects()

	var choices: Array[int] = []

	for i in range(3):
		if i != selected_character:
			choices.append(i)

	enemy_character = choices[
		rng.randi_range(
			0,
			choices.size() - 1
		)
	]

	player.configure_character(selected_character)
	enemy.configure(
		selected_difficulty,
		enemy_character,
		selected_map
	)

	player.reset_for_battle()
	enemy.reset_for_battle()

	player.visible = true
	enemy.visible = true

	player.set_active(true)
	enemy.set_active(true)

	heal_pack_timer = 10.0
	heal_pack_direction = 1.0
	heal_message_timer = 0.0
	heal_message = ""

	_clear_heal_packs()

	state = GameState.BATTLE
	queue_redraw()


func _end_battle(player_won: bool) -> void:
	result_was_win = player_won

	_clear_heal_packs()

	player.set_active(false)
	enemy.set_active(false)

	if player_won:
		total_wins += 1
	else:
		total_losses += 1

	_save_stats()

	state = GameState.RESULT
	queue_redraw()


func _on_player_defeated() -> void:
	if state == GameState.BATTLE:
		_end_battle(false)


func _on_enemy_defeated() -> void:
	if state == GameState.BATTLE:
		_end_battle(true)


func _on_player_ultimate_used(character_index: int) -> void:
	ultimate_banner_timer = 0.85
	ultimate_banner_character = character_index
	ultimate_banner_enemy = false
	queue_redraw()


func _on_enemy_ultimate_used(character_index: int) -> void:
	ultimate_banner_timer = 0.85
	ultimate_banner_character = character_index
	ultimate_banner_enemy = true
	queue_redraw()


func _go_to_main_menu() -> void:
	_hide_battle_objects()
	state = GameState.MAIN_MENU
	queue_redraw()


func _go_to_difficulty_select() -> void:
	_hide_battle_objects()
	state = GameState.DIFFICULTY_SELECT
	queue_redraw()


func _hide_battle_objects() -> void:
	_clear_projectiles()
	_clear_heal_packs()
	_clear_terrain_effects()

	player.set_active(false)
	enemy.set_active(false)

	player.visible = false
	enemy.visible = false


func _clear_projectiles() -> void:
	for node in get_tree().get_nodes_in_group("projectile"):
		if is_instance_valid(node):
			node.queue_free()


func _clear_terrain_effects() -> void:
	player_terrain_status = ""
	enemy_terrain_status = ""

	if is_instance_valid(player):
		player.reset_terrain_effects()

	if is_instance_valid(enemy):
		enemy.reset_terrain_effects()


func _clear_heal_packs() -> void:
	for node in get_tree().get_nodes_in_group("heal_pack"):
		if is_instance_valid(node):
			node.queue_free()


# =========================================================
# MAP EFFECTS
# =========================================================

func _update_map_effects(_delta: float) -> void:
	player.reset_terrain_effects()
	enemy.reset_terrain_effects()

	player_terrain_status = ""
	enemy_terrain_status = ""

	match selected_map:
		MAP_ARCANE_RIVER:
			pass

		MAP_RAIN_RUINS:
			_apply_rain_puddles()

		MAP_FROZEN_PASS:
			_apply_ice_zones()


func _apply_rain_puddles() -> void:
	var player_slow: bool = false
	var enemy_slow: bool = false

	for puddle in rain_puddles:
		if puddle.has_point(player.position):
			player_slow = true

		if puddle.has_point(enemy.position):
			enemy_slow = true

	if player_slow:
		player.set_terrain_speed_multiplier(0.55)
		player_terrain_status = "PUDDLE  이동속도 감소"

	if enemy_slow:
		enemy.set_terrain_speed_multiplier(0.55)
		enemy_terrain_status = "PUDDLE"


func _apply_ice_zones() -> void:
	var player_ice: bool = false
	var enemy_ice: bool = false

	for zone in ice_zones:
		if zone.has_point(player.position):
			player_ice = true

		if zone.has_point(enemy.position):
			enemy_ice = true

	if player_ice:
		player.set_terrain_ice(true)
		player_terrain_status = "ICE  미끄러짐"

	if enemy_ice:
		enemy.set_terrain_ice(true)
		enemy_terrain_status = "ICE"


# =========================================================
# HEAL PACK
# 중앙 강을 약 10초마다 가로지르는 중립 오브젝트.
# 먼저 공격해 맞힌 쪽이 35 HP 회복.
# =========================================================

func _update_heal_pack(delta: float) -> void:
	heal_pack_timer -= delta

	if heal_pack_timer > 0.0:
		return

	heal_pack_timer = 10.0
	_spawn_heal_pack()


func _spawn_heal_pack() -> void:
	var pack := HEAL_PACK_SCENE.instantiate()
	add_child(pack)

	var y: float = rng.randf_range(
		RIVER_TOP + 38.0,
		RIVER_BOTTOM - 38.0
	)

	var start_x: float

	if heal_pack_direction > 0.0:
		start_x = -55.0
	else:
		start_x = 1335.0

	pack.setup(
		Vector2(start_x, y),
		heal_pack_direction
	)

	pack.claimed.connect(
		_on_heal_pack_claimed
	)

	heal_pack_direction *= -1.0


func _on_heal_pack_claimed(
	by_player: bool,
	amount: int
) -> void:
	heal_message_timer = 1.15

	if by_player:
		heal_message = "HEAL PACK  +" + str(amount) + " HP"
	else:
		heal_message = "CPU HEAL  +" + str(amount) + " HP"

	queue_redraw()


# =========================================================
# IMPACT FEEDBACK
# =========================================================

func request_impact(
	damage: int,
	_hit_position: Vector2,
	color: Color
) -> void:
	var strength: float = clampf(
		float(damage) * 0.095,
		2.0,
		10.0
	)

	impact_shake_strength = maxf(
		impact_shake_strength,
		strength
	)

	impact_shake_timer = maxf(
		impact_shake_timer,
		0.08 if damage < 45 else 0.14
	)

	impact_flash_timer = maxf(
		impact_flash_timer,
		0.035 if damage < 45 else 0.075
	)

	impact_flash_color = color.lightened(0.40)


func _draw_impact_flash() -> void:
	var alpha: float = clampf(
		impact_flash_timer / 0.075,
		0.0,
		1.0
	) * 0.12

	draw_rect(
		Rect2(Vector2.ZERO, SCREEN_SIZE),
		Color(
			impact_flash_color.r,
			impact_flash_color.g,
			impact_flash_color.b,
			alpha
		)
	)


# =========================================================
# AI TERRAIN AWARENESS
# Medium/Hard AI가 비맵의 물웅덩이를 이동 목표로 덜 선택한다.
# 설원 빙판은 위험지형이 아니라 활용 가능한 지형으로 취급한다.
# =========================================================

func is_ai_position_bad(point: Vector2) -> bool:
	if selected_map != MAP_RAIN_RUINS:
		return false

	for puddle in rain_puddles:
		if puddle.has_point(point):
			return true

	return false

func _load_stats() -> void:
	var config := ConfigFile.new()
	var err := config.load(STATS_PATH)

	if err == OK:
		total_wins = int(
			config.get_value("record", "wins", 0)
		)

		total_losses = int(
			config.get_value("record", "losses", 0)
		)


func _save_stats() -> void:
	var config := ConfigFile.new()

	config.set_value(
		"record",
		"wins",
		total_wins
	)

	config.set_value(
		"record",
		"losses",
		total_losses
	)

	config.save(STATS_PATH)


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font

	match state:
		GameState.MAIN_MENU:
			_draw_menu_background()
			_draw_main_menu(font)

		GameState.DIFFICULTY_SELECT:
			_draw_menu_background()
			_draw_difficulty_select(font)

		GameState.CHARACTER_SELECT:
			_draw_menu_background()
			_draw_character_select(font)

		GameState.MAP_SELECT:
			_draw_menu_background()
			_draw_map_select(font)

		GameState.BATTLE:
			_draw_battle_map()
			_draw_battle_hud(font)

		GameState.RESULT:
			_draw_battle_map()
			_draw_battle_hud(font)
			_draw_result_screen(font)

	if (
		(state == GameState.BATTLE or state == GameState.RESULT)
		and ultimate_banner_timer > 0.0
	):
		_draw_ultimate_banner(font)


	if impact_flash_timer > 0.0:
		_draw_impact_flash()


# =========================================================
# MENU / DIFFICULTY
# =========================================================

func _draw_menu_background() -> void:
	draw_rect(
		Rect2(Vector2.ZERO, SCREEN_SIZE),
		Color(0.025, 0.035, 0.060)
	)

	draw_rect(
		Rect2(Vector2(0.0, 0.0), Vector2(1280.0, 8.0)),
		Color(0.20, 0.60, 0.84)
	)

	draw_rect(
		Rect2(Vector2(0.0, 548.0), Vector2(1280.0, 172.0)),
		Color(0.025, 0.15, 0.23)
	)

	for i in range(10):
		var y: float = 570.0 + float(i) * 14.0
		var shift: float = fmod(
			elapsed * 18.0 + float(i * 33),
			90.0
		)

		for x in range(-100, 1380, 90):
			draw_rect(
				Rect2(
					Vector2(float(x) + shift, y),
					Vector2(44.0, 3.0)
				),
				Color(0.18, 0.55, 0.75, 0.24)
			)

	for i in range(34):
		var x: float = float((i * 127 + 45) % 1280)
		var y: float = float(45 + ((i * 79) % 430))

		draw_rect(
			Rect2(Vector2(x, y), Vector2(2.0, 2.0)),
			Color(0.62, 0.82, 1.0, 0.20)
		)


func _draw_main_menu(font: Font) -> void:
	draw_string(
		font,
		Vector2(0.0, 165.0),
		"SKILL DUEL",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		70,
		Color.WHITE
	)

	draw_string(
		font,
		Vector2(0.0, 215.0),
		"ARCANE RIVER BATTLE",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		18,
		Color(0.40, 0.78, 1.0)
	)

	draw_rect(
		Rect2(Vector2(420.0, 270.0), Vector2(440.0, 4.0)),
		Color(0.18, 0.55, 0.78, 0.65)
	)

	_draw_button(
		start_button,
		"게임 시작",
		font,
		Color(0.08, 0.42, 0.68)
	)

	_draw_button(
		exit_button,
		"게임 종료",
		font,
		Color(0.12, 0.15, 0.21)
	)

	draw_string(
		font,
		Vector2(0.0, 535.0),
		"현재 전적  " + _record_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		18,
		Color(0.78, 0.84, 0.91)
	)


func _draw_difficulty_select(font: Font) -> void:
	draw_string(
		font,
		Vector2(0.0, 125.0),
		"난이도 선택",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		44,
		Color.WHITE
	)

	draw_string(
		font,
		Vector2(0.0, 175.0),
		"CPU의 이동·조준·스킬 사용 빈도가 달라집니다.",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		17,
		Color(0.64, 0.72, 0.82)
	)

	var titles: Array[String] = [
		"초급",
		"중급",
		"상급"
	]

	var subtitles: Array[String] = [
		"입문용",
		"표준 대전",
		"숙련자용"
	]

	var descriptions: Array[String] = [
		"느린 이동\n낮은 명중률\n스킬 사용 적음",
		"균형 잡힌 이동\n보통 명중률\n정상 스킬 사용",
		"빠른 이동\n높은 명중률\n잦은 스킬 사용"
	]

	var colors: Array[Color] = [
		Color(0.10, 0.48, 0.31),
		Color(0.08, 0.38, 0.65),
		Color(0.62, 0.13, 0.22)
	]

	for i in range(3):
		var rect := difficulty_rects[i]

		draw_rect(rect, Color(0.025, 0.04, 0.06, 0.95))
		draw_rect(rect, colors[i], false, 4.0)

		draw_rect(
			Rect2(
				rect.position,
				Vector2(rect.size.x, 50.0)
			),
			Color(colors[i], 0.55)
		)

		draw_string(
			font,
			Vector2(rect.position.x, rect.position.y + 40.0),
			titles[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			30,
			Color.WHITE
		)

		draw_string(
			font,
			Vector2(rect.position.x, rect.position.y + 84.0),
			subtitles[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			16,
			Color(0.84, 0.90, 0.96)
		)

		var lines := descriptions[i].split("\n")

		for line_index in range(lines.size()):
			draw_string(
				font,
				Vector2(
					rect.position.x,
					rect.position.y
					+ 126.0
					+ float(line_index) * 27.0
				),
				lines[line_index],
				HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x,
				15,
				Color(0.72, 0.78, 0.84)
			)

	draw_string(
		font,
		Vector2(0.0, 640.0),
		"ESC : 뒤로",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		15,
		Color(0.50, 0.57, 0.64)
	)


# =========================================================
# CHARACTER SELECT
# =========================================================

func _draw_character_select(font: Font) -> void:
	var difficulty_names: Array[String] = [
		"초급",
		"중급",
		"상급"
	]

	draw_string(
		font,
		Vector2(0.0, 78.0),
		"캐릭터 선택",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		40,
		Color.WHITE
	)

	draw_string(
		font,
		Vector2(0.0, 116.0),
		"난이도 : " + difficulty_names[selected_difficulty],
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		16,
		Color(0.38, 0.78, 1.0)
	)

	for i in range(3):
		_draw_character_card(
			i,
			character_rects[i],
			font
		)

	_draw_button(
		character_start_button,
		"다음 : 맵 선택",
		font,
		Color(0.09, 0.47, 0.69)
	)

	draw_string(
		font,
		Vector2(0.0, 696.0),
		"카드 선택 → 맵 선택   |   ESC : 뒤로",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		14,
		Color(0.55, 0.61, 0.68)
	)


func _draw_character_card(
	index: int,
	rect: Rect2,
	font: Font
) -> void:
	var names: Array[String] = ["ARIA", "LYRA", "SERA"]

	var roles: Array[String] = [
		"ARCANE MAGE",
		"RIVER RANGER",
		"BLADE DANCER"
	]

	var playstyles: Array[String] = [
		"곡선 탄도 / 관통 / 광역 궁극기",
		"고속 사격 / 부채꼴 / 화살비",
		"근중거리 / 튕겨내기 / 돌진 검기"
	]

	var colors: Array[Color] = [
		Color(0.42, 0.24, 0.72),
		Color(0.08, 0.48, 0.34),
		Color(0.70, 0.13, 0.26)
	]

	var selected: bool = (
		index == selected_character_card
	)

	draw_rect(rect, Color(0.025, 0.035, 0.055, 0.97))

	draw_rect(
		rect,
		colors[index]
		if selected
		else Color(0.24, 0.28, 0.34),
		false,
		5.0 if selected else 2.0
	)

	draw_rect(
		Rect2(rect.position, Vector2(rect.size.x, 48.0)),
		Color(colors[index], 0.45)
	)

	var portrait_center := Vector2(
		rect.position.x + rect.size.x * 0.5,
		rect.position.y + 125.0
	)

	_draw_pixel_portrait(
		index,
		portrait_center,
		2.1
	)

	draw_string(
		font,
		Vector2(rect.position.x, rect.position.y + 218.0),
		names[index],
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		28,
		Color.WHITE
	)

	draw_string(
		font,
		Vector2(rect.position.x, rect.position.y + 246.0),
		roles[index],
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		13,
		Color(0.64, 0.80, 0.92)
	)

	draw_string(
		font,
		Vector2(rect.position.x + 15.0, rect.position.y + 280.0),
		playstyles[index],
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x - 30.0,
		13,
		Color(0.78, 0.81, 0.84)
	)

	var keys: Array[String] = ["Q", "E", "S", "R"]

	for i in range(4):
		var icon_rect := Rect2(
			Vector2(
				rect.position.x + 34.0 + float(i) * 72.0,
				rect.position.y + 310.0
			),
			Vector2(54.0, 44.0)
		)

		_draw_skill_icon(
			index,
			i,
			icon_rect,
			keys[i],
			font,
			0.0,
			false
		)


func _draw_pixel_portrait(
	index: int,
	center: Vector2,
	scale_value: float
) -> void:
	var s := scale_value
	var skin := Color(1.0, 0.82, 0.72)

	match index:
		0:
			draw_rect(Rect2(center + Vector2(-18, -31) * s, Vector2(36, 24) * s), Color(0.32, 0.20, 0.58))
			draw_rect(Rect2(center + Vector2(-14, -27) * s, Vector2(28, 22) * s), skin)
			draw_rect(Rect2(center + Vector2(-23, -30) * s, Vector2(10, 30) * s), Color(0.42, 0.28, 0.72))
			draw_rect(Rect2(center + Vector2(14, -30) * s, Vector2(10, 30) * s), Color(0.42, 0.28, 0.72))
			draw_rect(Rect2(center + Vector2(-8, -18) * s, Vector2(4, 4) * s), Color(0.25, 0.82, 1.0))
			draw_rect(Rect2(center + Vector2(5, -18) * s, Vector2(4, 4) * s), Color(0.25, 0.82, 1.0))
			draw_rect(Rect2(center + Vector2(-17, -3) * s, Vector2(34, 30) * s), Color(0.50, 0.28, 0.82))
			draw_rect(Rect2(center + Vector2(-24, 22) * s, Vector2(48, 18) * s), Color(0.62, 0.38, 0.92))
			draw_rect(Rect2(center + Vector2(-6, 4) * s, Vector2(12, 12) * s), Color(0.25, 0.84, 1.0))

		1:
			draw_rect(Rect2(center + Vector2(-18, -31) * s, Vector2(36, 23) * s), Color(0.13, 0.36, 0.27))
			draw_rect(Rect2(center + Vector2(-14, -27) * s, Vector2(28, 22) * s), skin)
			draw_rect(Rect2(center + Vector2(-22, -32) * s, Vector2(44, 9) * s), Color(0.10, 0.52, 0.36))
			draw_rect(Rect2(center + Vector2(-8, -18) * s, Vector2(4, 4) * s), Color(0.95, 0.72, 0.18))
			draw_rect(Rect2(center + Vector2(5, -18) * s, Vector2(4, 4) * s), Color(0.95, 0.72, 0.18))
			draw_rect(Rect2(center + Vector2(-17, -3) * s, Vector2(34, 34) * s), Color(0.10, 0.60, 0.40))
			draw_rect(Rect2(center + Vector2(-19, -2) * s, Vector2(38, 7) * s), Color(0.96, 0.74, 0.20))
			draw_line(center + Vector2(23, -10) * s, center + Vector2(33, 32) * s, Color(0.96, 0.78, 0.24), 4.0)

		2:
			draw_rect(Rect2(center + Vector2(-20, -33) * s, Vector2(40, 27) * s), Color(0.40, 0.07, 0.16))
			draw_rect(Rect2(center + Vector2(-14, -27) * s, Vector2(28, 22) * s), skin)
			draw_rect(Rect2(center + Vector2(-25, -25) * s, Vector2(10, 50) * s), Color(0.48, 0.08, 0.18))
			draw_rect(Rect2(center + Vector2(-8, -18) * s, Vector2(4, 4) * s), Color(1.0, 0.34, 0.46))
			draw_rect(Rect2(center + Vector2(5, -18) * s, Vector2(4, 4) * s), Color(1.0, 0.34, 0.46))
			draw_rect(Rect2(center + Vector2(-17, -3) * s, Vector2(34, 33) * s), Color(0.66, 0.12, 0.26))
			draw_rect(Rect2(center + Vector2(-23, 23) * s, Vector2(46, 17) * s), Color(0.82, 0.18, 0.34))
			draw_line(center + Vector2(22, 24) * s, center + Vector2(40, -16) * s, Color(0.88, 0.95, 1.0), 5.0)


# =========================================================
# MAP SELECT
# =========================================================

func _draw_map_select(font: Font) -> void:
	draw_string(
		font,
		Vector2(0.0, 78.0),
		"맵 선택",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		40,
		Color.WHITE
	)

	draw_string(
		font,
		Vector2(0.0, 118.0),
		"일부 맵에는 전투에 영향을 주는 지형 효과가 있습니다.",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		16,
		Color(0.66, 0.74, 0.82)
	)

	for i in range(3):
		_draw_map_card(
			i,
			map_rects[i],
			font
		)

	_draw_button(
		map_start_button,
		"이 맵에서 대전",
		font,
		Color(0.09, 0.47, 0.69)
	)

	draw_string(
		font,
		Vector2(0.0, 696.0),
		"맵 선택 → 대전 시작   |   ESC : 캐릭터 선택",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		14,
		Color(0.55, 0.61, 0.68)
	)


func _draw_map_card(
	index: int,
	rect: Rect2,
	font: Font
) -> void:
	var names: Array[String] = [
		"ARCANE RIVER",
		"RAIN RUINS",
		"FROZEN PASS"
	]

	var korean_names: Array[String] = [
		"아케인 강가",
		"비 내리는 폐허",
		"설원 협곡"
	]

	var effects: Array[String] = [
		"기본 맵\n특수 지형 없음",
		"물웅덩이\n진입 시 이동속도 45% 감소",
		"빙판 지대\n진입 시 가속 + 미끄러짐"
	]

	var colors: Array[Color] = [
		Color(0.10, 0.44, 0.58),
		Color(0.18, 0.42, 0.58),
		Color(0.30, 0.54, 0.72)
	]

	var selected: bool = (
		index == selected_map_card
	)

	draw_rect(
		rect,
		Color(0.025, 0.035, 0.050, 0.97)
	)

	draw_rect(
		rect,
		colors[index]
		if selected
		else Color(0.23, 0.27, 0.31),
		false,
		5.0 if selected else 2.0
	)

	var preview := Rect2(
		rect.position + Vector2(12.0, 12.0),
		Vector2(rect.size.x - 24.0, 155.0)
	)

	_draw_map_preview(
		index,
		preview
	)

	draw_string(
		font,
		Vector2(rect.position.x, rect.position.y + 205.0),
		names[index],
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		24,
		Color.WHITE
	)

	draw_string(
		font,
		Vector2(rect.position.x, rect.position.y + 232.0),
		korean_names[index],
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		15,
		Color(0.66, 0.82, 0.92)
	)

	var lines := effects[index].split("\n")

	for line_index in range(lines.size()):
		draw_string(
			font,
			Vector2(
				rect.position.x,
				rect.position.y
				+ 270.0
				+ float(line_index) * 26.0
			),
			lines[line_index],
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			14,
			Color(0.80, 0.82, 0.84)
		)


func _draw_map_preview(
	index: int,
	rect: Rect2
) -> void:
	draw_rect(
		rect,
		Color(0.02, 0.03, 0.04)
	)

	var half_h: float = rect.size.y * 0.38
	var river_y: float = rect.position.y + half_h

	match index:
		MAP_ARCANE_RIVER:
			draw_rect(
				Rect2(
					rect.position,
					Vector2(rect.size.x, half_h)
				),
				Color(0.08, 0.28, 0.17)
			)

			draw_rect(
				Rect2(
					Vector2(rect.position.x, river_y),
					Vector2(rect.size.x, rect.size.y * 0.24)
				),
				Color(0.04, 0.38, 0.58)
			)

			draw_rect(
				Rect2(
					Vector2(
						rect.position.x,
						river_y + rect.size.y * 0.24
					),
					Vector2(rect.size.x, half_h)
				),
				Color(0.09, 0.30, 0.18)
			)

		MAP_RAIN_RUINS:
			draw_rect(
				rect,
				Color(0.14, 0.19, 0.23)
			)

			draw_rect(
				Rect2(
					Vector2(
						rect.position.x,
						rect.position.y + rect.size.y * 0.42
					),
					Vector2(
						rect.size.x,
						rect.size.y * 0.22
					)
				),
				Color(0.08, 0.30, 0.43)
			)

			for i in range(12):
				var x: float = rect.position.x + 10.0 + float(i) * 24.0
				draw_line(
					Vector2(x, rect.position.y + 8.0),
					Vector2(x - 7.0, rect.position.y + 40.0),
					Color(0.45, 0.72, 0.86, 0.50),
					2.0
				)

			draw_rect(
				Rect2(
					Vector2(
						rect.position.x + 36.0,
						rect.position.y + 102.0
					),
					Vector2(80.0, 22.0)
				),
				Color(0.15, 0.46, 0.60, 0.75)
			)

		MAP_FROZEN_PASS:
			draw_rect(
				rect,
				Color(0.70, 0.82, 0.88)
			)

			draw_rect(
				Rect2(
					Vector2(
						rect.position.x,
						rect.position.y + rect.size.y * 0.42
					),
					Vector2(
						rect.size.x,
						rect.size.y * 0.22
					)
				),
				Color(0.34, 0.63, 0.78)
			)

			for i in range(5):
				var x: float = rect.position.x + 25.0 + float(i) * 58.0

				draw_rect(
					Rect2(
						Vector2(x, rect.position.y + 90.0),
						Vector2(42.0, 18.0)
					),
					Color(0.62, 0.86, 0.96, 0.80)
				)

			for i in range(12):
				var sx: float = rect.position.x + float((i * 29) % int(rect.size.x))
				var sy: float = rect.position.y + float((i * 41) % int(rect.size.y))

				draw_rect(
					Rect2(Vector2(sx, sy), Vector2(3.0, 3.0)),
					Color.WHITE
				)


# =========================================================
# BATTLE MAP
# =========================================================

func _draw_battle_map() -> void:
	match selected_map:
		MAP_ARCANE_RIVER:
			_draw_arcane_river_battle()

		MAP_RAIN_RUINS:
			_draw_rain_ruins_battle()

		MAP_FROZEN_PASS:
			_draw_frozen_pass_battle()


func _draw_arcane_river_battle() -> void:
	draw_rect(
		Rect2(Vector2(0.0, 0.0), Vector2(1280.0, RIVER_TOP)),
		Color(0.075, 0.24, 0.15)
	)

	draw_rect(
		Rect2(Vector2(0.0, RIVER_BOTTOM), Vector2(1280.0, 280.0)),
		Color(0.085, 0.27, 0.16)
	)

	_draw_common_river(
		Color(0.04, 0.35, 0.55),
		Color(0.30, 0.70, 0.88, 0.30)
	)

	for i in range(52):
		var x: float = float((i * 89 + 25) % 1280)
		var upper_y: float = float(80 + ((i * 53) % 155))
		var lower_y: float = float(500 + ((i * 67) % 175))

		draw_rect(
			Rect2(Vector2(x, upper_y), Vector2(8.0, 3.0)),
			Color(0.16, 0.42, 0.23, 0.45)
		)

		draw_rect(
			Rect2(Vector2(1280.0 - x, lower_y), Vector2(7.0, 3.0)),
			Color(0.17, 0.45, 0.24, 0.42)
		)


func _draw_rain_ruins_battle() -> void:
	draw_rect(
		Rect2(Vector2(0.0, 0.0), Vector2(1280.0, RIVER_TOP)),
		Color(0.11, 0.17, 0.19)
	)

	draw_rect(
		Rect2(Vector2(0.0, RIVER_BOTTOM), Vector2(1280.0, 280.0)),
		Color(0.12, 0.18, 0.20)
	)

	_draw_common_river(
		Color(0.055, 0.28, 0.40),
		Color(0.40, 0.70, 0.82, 0.30)
	)

	# ruins
	for x in [45, 385, 790, 1120]:
		draw_rect(
			Rect2(Vector2(float(x), 82.0), Vector2(44.0, 130.0)),
			Color(0.25, 0.28, 0.29)
		)

		draw_rect(
			Rect2(Vector2(float(x - 10), 70.0), Vector2(64.0, 14.0)),
			Color(0.32, 0.34, 0.34)
		)

	for x in [80, 450, 850, 1150]:
		draw_rect(
			Rect2(Vector2(float(x), 525.0), Vector2(38.0, 130.0)),
			Color(0.24, 0.27, 0.28)
		)

	# puddles
	for puddle in rain_puddles:
		draw_rect(
			puddle,
			Color(0.12, 0.42, 0.55, 0.62)
		)

		draw_rect(
			Rect2(
				puddle.position + Vector2(12.0, 12.0),
				Vector2(puddle.size.x * 0.55, 4.0)
			),
			Color(0.55, 0.82, 0.92, 0.46)
		)

	# rain
	var rain_shift: float = fmod(elapsed * 420.0, 55.0)

	for i in range(65):
		var x: float = float((i * 83 + 19) % 1320) - 20.0
		var y: float = fmod(
			float((i * 109) % 720) + rain_shift,
			720.0
		)

		draw_line(
			Vector2(x, y),
			Vector2(x - 8.0, y + 20.0),
			Color(0.55, 0.76, 0.86, 0.40),
			2.0
		)


func _draw_frozen_pass_battle() -> void:
	# snow fields
	draw_rect(
		Rect2(Vector2(0.0, 0.0), Vector2(1280.0, RIVER_TOP)),
		Color(0.70, 0.78, 0.82)
	)

	draw_rect(
		Rect2(Vector2(0.0, RIVER_BOTTOM), Vector2(1280.0, 280.0)),
		Color(0.74, 0.82, 0.86)
	)

	# cold river / partially frozen water
	_draw_common_river(
		Color(0.18, 0.48, 0.66),
		Color(0.62, 0.86, 0.96, 0.34)
	)

	# darker snow/rock specks
	for i in range(42):
		var x: float = float((i * 97 + 21) % 1280)
		var upper_y: float = float(70 + ((i * 47) % 165))
		var lower_y: float = float(490 + ((i * 61) % 185))

		draw_rect(
			Rect2(Vector2(x, upper_y), Vector2(7.0, 4.0)),
			Color(0.50, 0.62, 0.68, 0.40)
		)

		draw_rect(
			Rect2(Vector2(1280.0 - x, lower_y), Vector2(8.0, 4.0)),
			Color(0.50, 0.62, 0.68, 0.38)
		)

	# visible ice patches
	for zone in ice_zones:
		draw_rect(
			zone,
			Color(0.44, 0.78, 0.92, 0.58)
		)

		draw_rect(
			Rect2(
				zone.position + Vector2(8.0, 8.0),
				zone.size - Vector2(16.0, 16.0)
			),
			Color(0.80, 0.95, 1.0, 0.45),
			false,
			3.0
		)

		for row in range(3):
			var y: float = zone.position.y + 14.0 + float(row) * 18.0

			draw_line(
				Vector2(zone.position.x + 12.0, y),
				Vector2(zone.end.x - 12.0, y - 7.0),
				Color(0.88, 0.98, 1.0, 0.38),
				2.0
			)

	# snow
	var snow_fall: float = fmod(elapsed * 78.0, 720.0)

	for i in range(90):
		var x: float = float((i * 73 + 31) % 1280)
		var y: float = fmod(
			float((i * 101) % 720) + snow_fall,
			720.0
		)

		var size: float = 2.0 + float(i % 3)

		draw_rect(
			Rect2(
				Vector2(x, y),
				Vector2(size, size)
			),
			Color(1.0, 1.0, 1.0, 0.62)
		)

func _draw_common_river(
	river_color: Color,
	wave_color: Color
) -> void:
	draw_rect(
		Rect2(Vector2(0.0, RIVER_TOP - 12.0), Vector2(1280.0, 12.0)),
		Color(0.38, 0.36, 0.25)
	)

	draw_rect(
		Rect2(Vector2(0.0, RIVER_BOTTOM), Vector2(1280.0, 12.0)),
		Color(0.38, 0.36, 0.25)
	)

	draw_rect(
		Rect2(
			Vector2(0.0, RIVER_TOP),
			Vector2(1280.0, RIVER_BOTTOM - RIVER_TOP)
		),
		river_color
	)

	for row in range(9):
		var y: float = RIVER_TOP + 15.0 + float(row) * 16.0
		var shift: float = fmod(
			elapsed * (12.0 + float(row % 3) * 3.0),
			80.0
		)

		for x in range(-80, 1360, 80):
			draw_rect(
				Rect2(
					Vector2(float(x) + shift, y),
					Vector2(34.0, 3.0)
				),
				wave_color
			)


# =========================================================
# BATTLE HUD
# =========================================================

func _draw_battle_hud(font: Font) -> void:
	var player_ratio: float = player.get_hp_ratio()
	var enemy_ratio: float = enemy.get_hp_ratio()

	draw_rect(
		Rect2(Vector2(35.0, 22.0), Vector2(410.0, 54.0)),
		Color(0.015, 0.022, 0.034, 0.94)
	)

	draw_rect(
		Rect2(Vector2(42.0, 30.0), Vector2(390.0, 20.0)),
		Color(0.10, 0.12, 0.14)
	)

	draw_rect(
		Rect2(Vector2(42.0, 30.0), Vector2(390.0 * player_ratio, 20.0)),
		Color(0.20, 0.82, 0.44)
	)

	draw_rect(
		Rect2(Vector2(835.0, 22.0), Vector2(410.0, 54.0)),
		Color(0.015, 0.022, 0.034, 0.94)
	)

	draw_rect(
		Rect2(Vector2(848.0, 30.0), Vector2(390.0, 20.0)),
		Color(0.10, 0.12, 0.14)
	)

	draw_rect(
		Rect2(
			Vector2(
				848.0 + 390.0 * (1.0 - enemy_ratio),
				30.0
			),
			Vector2(390.0 * enemy_ratio, 20.0)
		),
		Color(0.90, 0.25, 0.30)
	)

	draw_string(
		font,
		Vector2(43.0, 70.0),
		player.character_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		220.0,
		17,
		Color.WHITE
	)

	draw_string(
		font,
		Vector2(1010.0, 70.0),
		enemy.character_name + "  CPU",
		HORIZONTAL_ALIGNMENT_RIGHT,
		220.0,
		17,
		Color.WHITE
	)

	var difficulty_names: Array[String] = [
		"초급",
		"중급",
		"상급"
	]

	var map_names: Array[String] = [
		"ARCANE RIVER",
		"RAIN RUINS",
		"FROZEN PASS"
	]

	draw_string(
		font,
		Vector2(0.0, 44.0),
		difficulty_names[selected_difficulty]
		+ "  |  "
		+ map_names[selected_map],
		HORIZONTAL_ALIGNMENT_CENTER,
		1280.0,
		15,
		Color(0.80, 0.88, 0.96)
	)


	# 중앙 강의 중립 힐팩 리스폰 정보
	draw_string(
		font,
		Vector2(0.0, 69.0),
		"HEAL PACK  %.1fs" % heal_pack_timer,
		HORIZONTAL_ALIGNMENT_CENTER,
		1280.0,
		12,
		Color(0.55, 1.0, 0.72)
	)

	if heal_message_timer > 0.0:
		draw_string(
			font,
			Vector2(0.0, 126.0),
			heal_message,
			HORIZONTAL_ALIGNMENT_CENTER,
			1280.0,
			20,
			Color(0.55, 1.0, 0.70)
		)

	if player_terrain_status != "":
		draw_string(
			font,
			Vector2(42.0, 94.0),
			player_terrain_status,
			HORIZONTAL_ALIGNMENT_LEFT,
			300.0,
			14,
			Color(1.0, 0.74, 0.28)
		)

	if enemy_terrain_status != "":
		draw_string(
			font,
			Vector2(940.0, 94.0),
			enemy_terrain_status,
			HORIZONTAL_ALIGNMENT_RIGHT,
			300.0,
			14,
			Color(1.0, 0.60, 0.24)
		)

	_draw_skill_hud(font)


func _draw_skill_hud(font: Font) -> void:
	var cooldowns: Array[float] = [
		player.q_cooldown,
		player.e_cooldown,
		player.shift_cooldown,
		player.r_cooldown
	]

	var keys: Array[String] = [
		"Q",
		"E",
		"SHIFT",
		"R"
	]

	var start_x: float = 750.0
	var y: float = 625.0
	var width: float = 115.0
	var height: float = 76.0
	var gap: float = 11.0

	for i in range(4):
		var rect := Rect2(
			Vector2(
				start_x + float(i) * (width + gap),
				y
			),
			Vector2(width, height)
		)

		_draw_skill_icon(
			selected_character,
			i,
			rect,
			keys[i],
			font,
			cooldowns[i],
			true
		)


func _draw_skill_icon(
	character_index: int,
	slot: int,
	rect: Rect2,
	key_text: String,
	font: Font,
	cooldown: float,
	show_ready: bool
) -> void:
	var colors: Array[Color] = [
		Color(0.42, 0.24, 0.72),
		Color(0.08, 0.48, 0.34),
		Color(0.70, 0.13, 0.26)
	]

	var accent: Color = colors[character_index]

	if slot == 3:
		accent = accent.lightened(0.12)

	draw_rect(
		rect,
		Color(0.015, 0.025, 0.040, 0.96)
	)

	draw_rect(
		rect,
		accent,
		false,
		3.0
	)

	var c := Vector2(
		rect.position.x + rect.size.x * 0.5,
		rect.position.y + rect.size.y * 0.48
	)

	_draw_skill_glyph(
		character_index,
		slot,
		c,
		rect.size.y * 0.23,
		accent
	)

	draw_string(
		font,
		rect.position + Vector2(8.0, 18.0),
		key_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		Color.WHITE
	)

	if slot == 3:
		draw_string(
			font,
			rect.position + Vector2(rect.size.x - 36.0, 18.0),
			"ULT",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			10,
			Color(1.0, 0.78, 0.90)
		)

	if cooldown > 0.0:
		draw_rect(
			rect,
			Color(0.0, 0.0, 0.0, 0.60)
		)

		draw_string(
			font,
			Vector2(
				rect.position.x,
				rect.position.y + rect.size.y * 0.62
			),
			"%.1f" % cooldown,
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			20,
			Color.WHITE
		)

	elif show_ready:
		draw_string(
			font,
			Vector2(
				rect.position.x,
				rect.position.y + rect.size.y - 8.0
			),
			"READY",
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			10,
			Color(0.42, 1.0, 0.58)
		)


func _draw_skill_glyph(
	character_index: int,
	slot: int,
	center: Vector2,
	size: float,
	accent: Color
) -> void:
	match character_index:
		0:
			match slot:
				0:
					var diamond := PackedVector2Array([
						center + Vector2(size, 0.0),
						center + Vector2(0.0, -size),
						center + Vector2(-size, 0.0),
						center + Vector2(0.0, size)
					])

					draw_polygon(
						diamond,
						PackedColorArray([Color(0.42, 0.90, 1.0)])
					)

				1:
					draw_circle(center + Vector2(-size * 0.7, 0.0), size * 0.42, Color(0.58, 0.38, 1.0))
					draw_circle(center + Vector2(size * 0.7, 0.0), size * 0.42, Color(0.78, 0.55, 1.0))
					draw_line(center + Vector2(-size, size), center + Vector2(size, -size), Color.WHITE, 2.0)

				2:
					draw_rect(Rect2(center - Vector2(size * 0.8, size * 0.8), Vector2(size * 0.6, size * 1.6)), Color(0.35, 0.80, 1.0))
					draw_rect(Rect2(center + Vector2(size * 0.2, -size * 0.8), Vector2(size * 0.6, size * 1.6)), Color(0.70, 0.45, 1.0))

				3:
					draw_circle(center, size, Color(0.72, 0.28, 1.0))
					draw_circle(center, size * 0.45, Color.WHITE)

		1:
			match slot:
				0:
					draw_line(center - Vector2(size, -size * 0.4), center + Vector2(size, -size * 0.4), Color(1.0, 0.82, 0.22), 4.0)

					var arrow := PackedVector2Array([
						center + Vector2(size, -size * 0.4),
						center + Vector2(size * 0.35, -size),
						center + Vector2(size * 0.35, size * 0.2)
					])

					draw_polygon(arrow, PackedColorArray([Color(1.0, 0.70, 0.12)]))

				1:
					for angle in [-0.55, -0.27, 0.0, 0.27, 0.55]:
						var dir := Vector2.UP.rotated(angle)
						draw_line(center, center + dir * size, Color(0.95, 0.90, 0.30), 2.0)

				2:
					draw_arc(center, size, 0.3, 5.5, 12, Color(0.30, 0.90, 0.58), 3.0)
					draw_rect(Rect2(center + Vector2(size * 0.5, -2.0), Vector2(size * 0.8, 4.0)), Color.WHITE)

				3:
					for x in [-0.65, 0.0, 0.65]:
						draw_line(center + Vector2(size * x, -size), center + Vector2(size * x, size), Color(1.0, 0.58, 0.08), 3.0)

		2:
			match slot:
				0:
					draw_line(center + Vector2(-size, size * 0.7), center + Vector2(size, -size * 0.7), Color(1.0, 0.35, 0.52), 5.0)

				1:
					draw_arc(
						center,
						size,
						0.0,
						TAU,
						20,
						Color(1.0, 0.42, 0.62),
						4.0
					)

					draw_line(
						center + Vector2(-size * 0.55, 0.0),
						center + Vector2(size * 0.55, 0.0),
						Color.WHITE,
						2.0
					)

					draw_line(
						center + Vector2(size * 0.55, 0.0),
						center + Vector2(size * 0.20, -size * 0.28),
						Color.WHITE,
						2.0
					)

				2:
					var bolt := PackedVector2Array([
						center + Vector2(-size, size * 0.5),
						center + Vector2(-size * 0.1, -size),
						center + Vector2(-size * 0.25, -size * 0.1),
						center + Vector2(size, -size * 0.5),
						center + Vector2(size * 0.1, size),
						center + Vector2(size * 0.25, size * 0.1)
					])

					draw_polygon(bolt, PackedColorArray([Color(1.0, 0.30, 0.48)]))

				3:
					for y in [-0.60, 0.0, 0.60]:
						draw_line(center + Vector2(-size, size * y), center + Vector2(size, -size * y), Color(1.0, 0.15, 0.36), 4.0)


# =========================================================
# ULTIMATE / RESULT
# =========================================================

func _draw_ultimate_banner(font: Font) -> void:
	var names: Array[String] = [
		"ARIA - ARCANE CORE",
		"LYRA - ARROW RAIN",
		"SERA - PHANTOM RIFT"
	]

	var colors: Array[Color] = [
		Color(0.62, 0.34, 1.0),
		Color(1.0, 0.62, 0.12),
		Color(1.0, 0.20, 0.38)
	]

	var alpha: float = clampf(
		ultimate_banner_timer / 0.85,
		0.0,
		1.0
	)

	var c: Color = colors[
		ultimate_banner_character
	]

	draw_rect(
		Rect2(Vector2(0.0, 300.0), Vector2(1280.0, 92.0)),
		Color(0.0, 0.0, 0.0, 0.55 * alpha)
	)

	draw_rect(
		Rect2(Vector2(0.0, 300.0), Vector2(1280.0, 4.0)),
		Color(c, alpha)
	)

	draw_rect(
		Rect2(Vector2(0.0, 388.0), Vector2(1280.0, 4.0)),
		Color(c, alpha)
	)

	var prefix: String = (
		"CPU ULTIMATE  "
		if ultimate_banner_enemy
		else "ULTIMATE  "
	)

	draw_string(
		font,
		Vector2(0.0, 358.0),
		prefix + names[ultimate_banner_character],
		HORIZONTAL_ALIGNMENT_CENTER,
		1280.0,
		29,
		Color(1.0, 1.0, 1.0, alpha)
	)


func _draw_result_screen(font: Font) -> void:
	draw_rect(
		Rect2(Vector2.ZERO, SCREEN_SIZE),
		Color(0.0, 0.0, 0.0, 0.74)
	)

	var title: String = (
		"VICTORY"
		if result_was_win
		else "DEFEAT"
	)

	var title_color: Color = (
		Color(0.35, 1.0, 0.58)
		if result_was_win
		else Color(1.0, 0.35, 0.38)
	)

	draw_string(
		font,
		Vector2(0.0, 220.0),
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		64,
		title_color
	)

	draw_string(
		font,
		Vector2(0.0, 305.0),
		player.character_name
		+ "  VS  "
		+ enemy.character_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		24,
		Color.WHITE
	)

	var map_names: Array[String] = [
		"ARCANE RIVER",
		"RAIN RUINS",
		"FROZEN PASS"
	]

	draw_string(
		font,
		Vector2(0.0, 345.0),
		map_names[selected_map],
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		15,
		Color(0.68, 0.78, 0.86)
	)

	draw_string(
		font,
		Vector2(0.0, 400.0),
		"누적 전적  " + _record_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		28,
		Color(0.90, 0.94, 1.0)
	)

	_draw_button(
		retry_button,
		"다시 대전",
		font,
		Color(0.10, 0.48, 0.72)
	)

	_draw_button(
		main_button,
		"메인 화면",
		font,
		Color(0.18, 0.22, 0.28)
	)


func _record_text() -> String:
	var total: int = total_wins + total_losses
	var rate: float = 0.0

	if total > 0:
		rate = (
			float(total_wins)
			/ float(total)
			* 100.0
		)

	return "%d승 %d패  (승률 %.1f%%)" % [
		total_wins,
		total_losses,
		rate
	]


func _draw_button(
	rect: Rect2,
	text: String,
	font: Font,
	color: Color
) -> void:
	var hovered: bool = rect.has_point(
		get_viewport().get_mouse_position()
	)

	var draw_color := color

	if hovered:
		draw_color = color.lightened(0.12)

	draw_rect(
		rect,
		Color(0.015, 0.025, 0.040, 0.97)
	)

	draw_rect(
		Rect2(
			rect.position + Vector2(4.0, 4.0),
			rect.size - Vector2(8.0, 8.0)
		),
		draw_color
	)

	draw_rect(
		rect,
		Color(0.76, 0.86, 0.96, 0.65),
		false,
		2.0
	)

	draw_string(
		font,
		Vector2(
			rect.position.x,
			rect.position.y + rect.size.y * 0.64
		),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		22,
		Color.WHITE
	)
