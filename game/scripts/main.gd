extends Node2D

enum GameState {
	MAIN_MENU,
	DIFFICULTY_SELECT,
	CHARACTER_SELECT,
	BATTLE,
	RESULT
}

const SCREEN_SIZE: Vector2 = Vector2(1280.0, 720.0)
const RIVER_TOP: float = 280.0
const RIVER_BOTTOM: float = 440.0
const STATS_PATH: String = "user://skillduel_stats.cfg"

var state: GameState = GameState.MAIN_MENU
var selected_difficulty: int = 0
var selected_character: int = 0
var enemy_character: int = 1

var total_wins: int = 0
var total_losses: int = 0
var result_was_win: bool = false
var elapsed: float = 0.0

var rng := RandomNumberGenerator.new()

@onready var player = $Player
@onready var enemy = $Enemy

# Main menu
var start_button := Rect2(490.0, 345.0, 300.0, 72.0)
var exit_button := Rect2(490.0, 440.0, 300.0, 58.0)

# Difficulty cards
var difficulty_rects: Array[Rect2] = [
	Rect2(190.0, 315.0, 270.0, 180.0),
	Rect2(505.0, 315.0, 270.0, 180.0),
	Rect2(820.0, 315.0, 270.0, 180.0)
]

# Character cards
var character_rects: Array[Rect2] = [
	Rect2(105.0, 245.0, 315.0, 330.0),
	Rect2(482.0, 245.0, 315.0, 330.0),
	Rect2(859.0, 245.0, 315.0, 330.0)
]

# Result buttons
var retry_button := Rect2(365.0, 535.0, 250.0, 60.0)
var main_button := Rect2(665.0, 535.0, 250.0, 60.0)

func _ready() -> void:
	rng.randomize()
	_load_stats()

	player.defeated.connect(_on_player_defeated)
	enemy.defeated.connect(_on_enemy_defeated)

	player.visible = false
	enemy.visible = false
	player.set_active(false)
	enemy.set_active(false)

	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_ESCAPE:
			if state == GameState.DIFFICULTY_SELECT:
				state = GameState.MAIN_MENU
				queue_redraw()
			elif state == GameState.CHARACTER_SELECT:
				state = GameState.DIFFICULTY_SELECT
				queue_redraw()

	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
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
					state = GameState.CHARACTER_SELECT
					queue_redraw()
					return

		GameState.CHARACTER_SELECT:
			for i in range(character_rects.size()):
				if character_rects[i].has_point(pos):
					selected_character = i
					_start_battle()
					return

		GameState.RESULT:
			if retry_button.has_point(pos):
				state = GameState.DIFFICULTY_SELECT
				queue_redraw()
			elif main_button.has_point(pos):
				state = GameState.MAIN_MENU
				queue_redraw()

func _start_battle() -> void:
	# CPU는 플레이어와 다른 캐릭터를 우선 선택.
	var choices: Array[int] = []
	for i in range(3):
		if i != selected_character:
			choices.append(i)

	enemy_character = choices[rng.randi_range(0, choices.size() - 1)]

	_clear_projectiles()

	player.configure_character(selected_character)
	enemy.configure(selected_difficulty, enemy_character)

	player.reset_for_battle()
	enemy.reset_for_battle()

	player.visible = true
	enemy.visible = true
	player.set_active(true)
	enemy.set_active(true)

	state = GameState.BATTLE
	queue_redraw()

func _end_battle(player_won: bool) -> void:
	result_was_win = player_won

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

func _clear_projectiles() -> void:
	for node in get_tree().get_nodes_in_group("projectile"):
		node.queue_free()

func _load_stats() -> void:
	var config := ConfigFile.new()
	var err := config.load(STATS_PATH)

	if err == OK:
		total_wins = int(config.get_value("record", "wins", 0))
		total_losses = int(config.get_value("record", "losses", 0))

func _save_stats() -> void:
	var config := ConfigFile.new()
	config.set_value("record", "wins", total_wins)
	config.set_value("record", "losses", total_losses)
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

		GameState.BATTLE:
			_draw_battle_map()
			_draw_battle_hud(font)

		GameState.RESULT:
			_draw_battle_map()
			_draw_battle_hud(font)
			_draw_result_screen(font)

func _draw_menu_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.035, 0.060, 0.085))

	# Decorative river / light streak
	draw_rect(Rect2(Vector2(0.0, 565.0), Vector2(1280.0, 155.0)), Color(0.035, 0.15, 0.22))

	for i in range(9):
		var y: float = 585.0 + float(i) * 14.0
		var offset: float = sin(elapsed * 1.4 + float(i)) * 24.0
		draw_line(
			Vector2(80.0 + offset, y),
			Vector2(1200.0 - offset, y),
			Color(0.20, 0.65, 0.82, 0.18),
			2.0
		)

	for i in range(20):
		var x: float = float((i * 83) % 1280)
		var y: float = float(60 + ((i * 137) % 420))
		draw_circle(Vector2(x, y), float(2 + i % 3), Color(0.45, 0.80, 1.0, 0.12))

func _draw_main_menu(font: Font) -> void:
	draw_string(
		font,
		Vector2(0.0, 185.0),
		"SKILL DUEL",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		72,
		Color.WHITE
	)

	draw_string(
		font,
		Vector2(0.0, 238.0),
		"ARCANE RIVER BATTLE",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		20,
		Color(0.42, 0.82, 1.0)
	)

	_draw_button(start_button, "게임 시작", font, Color(0.10, 0.48, 0.72))
	_draw_button(exit_button, "게임 종료", font, Color(0.18, 0.22, 0.28))

	var record_text := _record_text()
	draw_string(
		font,
		Vector2(0.0, 545.0),
		"현재 전적  " + record_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		19,
		Color(0.82, 0.88, 0.94)
	)

func _draw_difficulty_select(font: Font) -> void:
	draw_string(
		font,
		Vector2(0.0, 155.0),
		"난이도 선택",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		46,
		Color.WHITE
	)

	draw_string(
		font,
		Vector2(0.0, 205.0),
		"CPU의 이동, 공격 속도와 명중률이 달라집니다.",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		18,
		Color(0.68, 0.76, 0.84)
	)

	var titles: Array[String] = ["초급", "중급", "상급"]
	var subs: Array[String] = [
		"느린 이동 / 긴 공격 간격",
		"균형 잡힌 기본 난이도",
		"빠른 이동 / 높은 명중률"
	]
	var colors: Array[Color] = [
		Color(0.12, 0.52, 0.36),
		Color(0.12, 0.42, 0.68),
		Color(0.67, 0.18, 0.28)
	]

	for i in range(3):
		var rect := difficulty_rects[i]
		draw_rect(rect, Color(colors[i], 0.88))
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.35), false, 2.0)

		draw_string(
			font,
			Vector2(rect.position.x, rect.position.y + 68.0),
			titles[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			34,
			Color.WHITE
		)

		draw_string(
			font,
			Vector2(rect.position.x, rect.position.y + 125.0),
			subs[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			15,
			Color(0.90, 0.95, 1.0)
		)

	draw_string(
		font,
		Vector2(0.0, 635.0),
		"ESC : 뒤로",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		16,
		Color(0.58, 0.64, 0.70)
	)

func _draw_character_select(font: Font) -> void:
	draw_string(
		font,
		Vector2(0.0, 105.0),
		"캐릭터 선택",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		44,
		Color.WHITE
	)

	var diff_names: Array[String] = ["초급", "중급", "상급"]
	draw_string(
		font,
		Vector2(0.0, 150.0),
		"선택 난이도 : " + diff_names[selected_difficulty],
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		17,
		Color(0.42, 0.82, 1.0)
	)

	for i in range(3):
		_draw_character_card(i, character_rects[i], font)

	draw_string(
		font,
		Vector2(0.0, 635.0),
		"캐릭터 카드를 클릭하면 바로 대전이 시작됩니다.   ESC : 뒤로",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		16,
		Color(0.62, 0.70, 0.78)
	)

func _draw_character_card(index: int, rect: Rect2, font: Font) -> void:
	var names: Array[String] = ["ARIA", "LYRA", "SERA"]
	var roles: Array[String] = ["ARCANE MAGE", "RIVER RANGER", "BLADE DANCER"]
	var skills: Array[String] = [
		"마법탄 / 3연발 / 순간이동 / 마력 폭발",
		"화살 / 5연사 / 구르기 / 초대형 관통 화살",
		"검기 / 쌍검기 / 장거리 돌진 / 연속 궁극 검기"
	]
	var colors: Array[Color] = [
		Color(0.42, 0.22, 0.68),
		Color(0.08, 0.46, 0.36),
		Color(0.66, 0.14, 0.26)
	]

	draw_rect(rect, Color(colors[index], 0.88))
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.35), false, 2.0)

	var center := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 102.0)
	_draw_portrait(index, center, 1.65)

	draw_string(
		font,
		Vector2(rect.position.x, rect.position.y + 205.0),
		names[index],
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		30,
		Color.WHITE
	)

	draw_string(
		font,
		Vector2(rect.position.x, rect.position.y + 235.0),
		roles[index],
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		14,
		Color(0.78, 0.90, 1.0)
	)

	draw_string(
		font,
		Vector2(rect.position.x + 16.0, rect.position.y + 285.0),
		skills[index],
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x - 32.0,
		13,
		Color(0.92, 0.94, 0.96)
	)

func _draw_portrait(index: int, center: Vector2, scale_value: float) -> void:
	var skin := Color(1.0, 0.80, 0.70)

	match index:
		0:
			draw_circle(center + Vector2(0.0, -30.0) * scale_value, 20.0 * scale_value, skin)
			draw_circle(center + Vector2(-10.0, -42.0) * scale_value, 18.0 * scale_value, Color(0.16, 0.10, 0.32))
			draw_circle(center + Vector2(12.0, -40.0) * scale_value, 17.0 * scale_value, Color(0.16, 0.10, 0.32))
			draw_rect(Rect2(center + Vector2(-26.0, -5.0) * scale_value, Vector2(52.0, 52.0) * scale_value), Color(0.58, 0.32, 0.92))
			draw_circle(center + Vector2(0.0, 9.0) * scale_value, 7.0 * scale_value, Color(0.25, 0.85, 1.0))

		1:
			draw_circle(center + Vector2(0.0, -30.0) * scale_value, 20.0 * scale_value, skin)
			draw_rect(Rect2(center + Vector2(-22.0, -52.0) * scale_value, Vector2(44.0, 22.0) * scale_value), Color(0.10, 0.28, 0.24))
			draw_rect(Rect2(center + Vector2(-25.0, -5.0) * scale_value, Vector2(50.0, 52.0) * scale_value), Color(0.16, 0.70, 0.55))
			draw_arc(center + Vector2(32.0, 5.0) * scale_value, 25.0 * scale_value, -1.4, 1.4, 18, Color(1.0, 0.78, 0.22), 4.0)

		2:
			draw_circle(center + Vector2(0.0, -30.0) * scale_value, 20.0 * scale_value, skin)
			draw_circle(center + Vector2(-10.0, -43.0) * scale_value, 19.0 * scale_value, Color(0.38, 0.08, 0.16))
			draw_line(center + Vector2(-23.0, -43.0) * scale_value, center + Vector2(-34.0, 6.0) * scale_value, Color(0.38, 0.08, 0.16), 9.0)
			draw_rect(Rect2(center + Vector2(-26.0, -5.0) * scale_value, Vector2(52.0, 52.0) * scale_value), Color(0.88, 0.27, 0.42))
			draw_line(center + Vector2(26.0, 8.0) * scale_value, center + Vector2(48.0, -30.0) * scale_value, Color(0.85, 0.92, 1.0), 6.0)

func _draw_battle_map() -> void:
	# Grass fields
	draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(1280.0, RIVER_TOP)), Color(0.10, 0.29, 0.20))
	draw_rect(Rect2(Vector2(0.0, RIVER_BOTTOM), Vector2(1280.0, 280.0)), Color(0.11, 0.31, 0.20))

	# Subtle grass patches
	for i in range(30):
		var x: float = float((i * 97 + 37) % 1280)
		var top_y: float = float(55 + ((i * 43) % 180))
		var bottom_y: float = float(490 + ((i * 61) % 185))
		draw_circle(Vector2(x, top_y), float(15 + i % 12), Color(0.16, 0.38, 0.22, 0.35))
		draw_circle(Vector2(1280.0 - x, bottom_y), float(12 + i % 15), Color(0.17, 0.40, 0.22, 0.32))

	# River banks
	draw_rect(Rect2(Vector2(0.0, RIVER_TOP - 10.0), Vector2(1280.0, 10.0)), Color(0.45, 0.43, 0.30))
	draw_rect(Rect2(Vector2(0.0, RIVER_BOTTOM), Vector2(1280.0, 10.0)), Color(0.45, 0.43, 0.30))

	# River
	draw_rect(Rect2(Vector2(0.0, RIVER_TOP), Vector2(1280.0, RIVER_BOTTOM - RIVER_TOP)), Color(0.055, 0.40, 0.62))

	for i in range(9):
		var y: float = RIVER_TOP + 15.0 + float(i) * 16.0
		var wave: float = sin(elapsed * 2.2 + float(i) * 0.7) * 24.0
		draw_line(
			Vector2(25.0 + wave, y),
			Vector2(1255.0 - wave, y),
			Color(0.35, 0.78, 0.95, 0.28),
			2.0
		)

	# Rocks along banks
	for i in range(18):
		var x: float = 25.0 + float(i) * 73.0
		draw_circle(Vector2(x, RIVER_TOP - 4.0), float(5 + i % 5), Color(0.52, 0.52, 0.45))
		draw_circle(Vector2(1280.0 - x, RIVER_BOTTOM + 5.0), float(5 + (i + 2) % 5), Color(0.52, 0.52, 0.45))

	# Small flowers
	for i in range(16):
		var x: float = 60.0 + float((i * 149) % 1160)
		var y: float = 500.0 + float((i * 37) % 155)
		draw_circle(Vector2(x, y), 3.0, Color(0.90, 0.65, 0.90))
		draw_circle(Vector2(x + 4.0, y), 3.0, Color(0.95, 0.85, 0.45))

func _draw_battle_hud(font: Font) -> void:
	# Top player/enemy status
	var player_ratio: float = player.get_hp_ratio()
	var enemy_ratio: float = enemy.get_hp_ratio()

	draw_rect(Rect2(Vector2(40.0, 25.0), Vector2(390.0, 25.0)), Color(0.03, 0.03, 0.04, 0.85))
	draw_rect(Rect2(Vector2(42.0, 27.0), Vector2(386.0 * player_ratio, 21.0)), Color(0.15, 0.82, 0.42))

	draw_rect(Rect2(Vector2(850.0, 25.0), Vector2(390.0, 25.0)), Color(0.03, 0.03, 0.04, 0.85))
	draw_rect(Rect2(Vector2(852.0 + 386.0 * (1.0 - enemy_ratio), 27.0), Vector2(386.0 * enemy_ratio, 21.0)), Color(0.90, 0.25, 0.28))

	draw_string(font, Vector2(40.0, 72.0), player.character_name, HORIZONTAL_ALIGNMENT_LEFT, 250.0, 18, Color.WHITE)
	draw_string(font, Vector2(990.0, 72.0), enemy.character_name + "  CPU", HORIZONTAL_ALIGNMENT_RIGHT, 250.0, 18, Color.WHITE)

	var diff_names: Array[String] = ["초급", "중급", "상급"]
	draw_string(font, Vector2(0.0, 45.0), diff_names[selected_difficulty], HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 17, Color(0.82, 0.90, 0.98))

	_draw_skill_hud(font)

func _draw_skill_hud(font: Font) -> void:
	var labels: Array[String] = ["Q", "E", "SHIFT", "R"]
	var cooldowns: Array[float] = [
		player.q_cooldown,
		player.e_cooldown,
		player.shift_cooldown,
		player.r_cooldown
	]

	var start_x: float = 768.0
	var y: float = 645.0
	var width: float = 108.0
	var height: float = 58.0
	var gap: float = 10.0

	for i in range(4):
		var x: float = start_x + float(i) * (width + gap)
		var rect := Rect2(Vector2(x, y), Vector2(width, height))

		var base := Color(0.035, 0.045, 0.05, 0.94)
		if i == 3:
			base = Color(0.28, 0.08, 0.34, 0.95)

		draw_rect(rect, base)
		draw_rect(rect, Color(0.82, 0.88, 0.93, 0.75), false, 2.0)

		draw_string(font, Vector2(x + 9.0, y + 19.0), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color.WHITE)

		if i == 3:
			draw_string(font, Vector2(x + 71.0, y + 19.0), "ULT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(1.0, 0.75, 1.0))

		if cooldowns[i] > 0.0:
			draw_rect(rect, Color(0.0, 0.0, 0.0, 0.52))
			draw_string(
				font,
				Vector2(x, y + 43.0),
				"%.1f" % cooldowns[i],
				HORIZONTAL_ALIGNMENT_CENTER,
				width,
				21,
				Color.WHITE
			)
		else:
			draw_string(
				font,
				Vector2(x, y + 42.0),
				"READY",
				HORIZONTAL_ALIGNMENT_CENTER,
				width,
				12,
				Color(0.38, 1.0, 0.52)
			)

func _draw_result_screen(font: Font) -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.0, 0.0, 0.0, 0.72))

	var title: String = "VICTORY" if result_was_win else "DEFEAT"
	var title_color: Color = Color(0.35, 1.0, 0.58) if result_was_win else Color(1.0, 0.35, 0.38)

	draw_string(font, Vector2(0.0, 220.0), title, HORIZONTAL_ALIGNMENT_CENTER, SCREEN_SIZE.x, 64, title_color)

	draw_string(
		font,
		Vector2(0.0, 305.0),
		player.character_name + "  VS  " + enemy.character_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		24,
		Color.WHITE
	)

	draw_string(
		font,
		Vector2(0.0, 380.0),
		"누적 전적  " + _record_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_SIZE.x,
		28,
		Color(0.90, 0.94, 1.0)
	)

	_draw_button(retry_button, "다시 대전", font, Color(0.10, 0.48, 0.72))
	_draw_button(main_button, "메인 화면", font, Color(0.18, 0.22, 0.28))

func _record_text() -> String:
	var total: int = total_wins + total_losses
	var rate: float = 0.0

	if total > 0:
		rate = float(total_wins) / float(total) * 100.0

	return "%d승 %d패  (승률 %.1f%%)" % [total_wins, total_losses, rate]

func _draw_button(rect: Rect2, text: String, font: Font, color: Color) -> void:
	var hovered: bool = rect.has_point(get_viewport().get_mouse_position())
	var draw_color := color

	if hovered:
		draw_color = color.lightened(0.12)

	draw_rect(rect, draw_color)
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.40), false, 2.0)

	draw_string(
		font,
		Vector2(rect.position.x, rect.position.y + rect.size.y * 0.64),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		23,
		Color.WHITE
	)
