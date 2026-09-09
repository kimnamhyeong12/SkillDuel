extends Node2D

const SCREEN_SIZE: Vector2 = Vector2(1280.0, 720.0)

func _ready() -> void:
    print("River Duel starter project loaded.")

func _draw() -> void:
    # Temporary prototype field.
    draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.16, 0.32, 0.16))
    draw_rect(Rect2(Vector2(0.0, 280.0), Vector2(1280.0, 160.0)), Color(0.10, 0.40, 0.65))
    draw_line(Vector2(0.0, 280.0), Vector2(1280.0, 280.0), Color.WHITE, 2.0)
    draw_line(Vector2(0.0, 440.0), Vector2(1280.0, 440.0), Color.WHITE, 2.0)
