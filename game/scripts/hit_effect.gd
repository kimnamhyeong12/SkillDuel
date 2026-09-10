extends Node2D

var damage_amount: int = 0
var effect_color: Color = Color.WHITE
var lifetime: float = 0.34
var total_lifetime: float = 0.34
var velocity: Vector2 = Vector2(0.0, -36.0)


func setup(
	new_position: Vector2,
	damage: int,
	color: Color
) -> void:
	global_position = new_position
	damage_amount = damage
	effect_color = color
	queue_redraw()


func _process(delta: float) -> void:
	lifetime -= delta
	position += velocity * delta
	velocity *= 0.93
	queue_redraw()

	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	var t: float = clampf(
		lifetime / total_lifetime,
		0.0,
		1.0
	)

	var progress: float = 1.0 - t
	var radius: float = 12.0 + progress * 34.0

	for i in range(8):
		var a: float = float(i) * TAU / 8.0
		var dir := Vector2(cos(a), sin(a))
		var center := dir * radius

		draw_rect(
			Rect2(
				center - Vector2(3.0, 3.0),
				Vector2(6.0, 6.0)
			),
			Color(
				effect_color.r,
				effect_color.g,
				effect_color.b,
				t
			)
		)

	draw_circle(
		Vector2.ZERO,
		12.0 + progress * 8.0,
		Color(
			1.0,
			1.0,
			1.0,
			t * 0.35
		)
	)

	var font: Font = ThemeDB.fallback_font

	draw_string(
		font,
		Vector2(-30.0, -24.0 - progress * 12.0),
		"-" + str(damage_amount),
		HORIZONTAL_ALIGNMENT_CENTER,
		60.0,
		18,
		Color(1.0, 0.92, 0.92, t)
	)
