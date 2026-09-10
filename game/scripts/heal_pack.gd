extends Area2D

signal claimed(by_player: bool, amount: int)

const HEAL_AMOUNT: int = 35
const SPEED: float = 155.0

var direction: float = 1.0
var claimed_already: bool = false
var bob_time: float = 0.0


func _ready() -> void:
	add_to_group("heal_pack")

	area_entered.connect(
		_on_area_entered
	)

	z_index = 3
	queue_redraw()


func setup(
	start_position: Vector2,
	move_direction: float
) -> void:
	global_position = start_position
	direction = signf(move_direction)

	if is_zero_approx(direction):
		direction = 1.0


func _physics_process(delta: float) -> void:
	bob_time += delta

	global_position.x += (
		SPEED
		* direction
		* delta
	)

	queue_redraw()

	if (
		global_position.x < -90.0
		or global_position.x > 1370.0
	):
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if claimed_already:
		return

	if not area.is_in_group("projectile"):
		return

	if not "target_group" in area:
		return

	var shooter_is_player: bool = (
		area.target_group == &"enemy"
	)

	var target_group: StringName = (
		&"player"
		if shooter_is_player
		else &"enemy"
	)

	var targets := get_tree().get_nodes_in_group(
		target_group
	)

	if targets.is_empty():
		return

	var target = targets[0]

	if not target.has_method("heal"):
		return

	claimed_already = true

	target.heal(HEAL_AMOUNT)

	claimed.emit(
		shooter_is_player,
		HEAL_AMOUNT
	)

	if is_instance_valid(area):
		area.queue_free()

	queue_free()


func _draw() -> void:
	var bob: float = sin(bob_time * 4.0) * 3.0
	var c := Vector2(0.0, bob)

	# glow
	draw_rect(
		Rect2(
			c + Vector2(-26.0, -22.0),
			Vector2(52.0, 44.0)
		),
		Color(0.25, 1.0, 0.55, 0.12)
	)

	# pack body
	draw_rect(
		Rect2(
			c + Vector2(-20.0, -16.0),
			Vector2(40.0, 32.0)
		),
		Color(0.14, 0.23, 0.20)
	)

	draw_rect(
		Rect2(
			c + Vector2(-18.0, -14.0),
			Vector2(36.0, 28.0)
		),
		Color(0.18, 0.62, 0.36)
	)

	# white medical cross
	draw_rect(
		Rect2(
			c + Vector2(-4.0, -11.0),
			Vector2(8.0, 22.0)
		),
		Color.WHITE
	)

	draw_rect(
		Rect2(
			c + Vector2(-11.0, -4.0),
			Vector2(22.0, 8.0)
		),
		Color.WHITE
	)

	# river movement indicator
	draw_line(
		c + Vector2(-29.0 * direction, 0.0),
		c + Vector2(-21.0 * direction, 0.0),
		Color(0.58, 1.0, 0.76),
		3.0
	)
