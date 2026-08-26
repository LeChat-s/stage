class_name CardUI
extends Control

signal card_played(card_data: CardData)

var card_data: CardData
var is_dragging: bool = false
var is_hovered: bool = false
var original_position: Vector2
var original_rotation: float = 0.0
var drag_offset: Vector2 = Vector2.ZERO

@export var play_treshhold: float = 400.0

func setup(data: CardData) -> void:
	card_data = data
	if has_node("Art") and data.artwork:
		$Art.texture = data.artwork
	original_position = global_position
	original_rotation = rotation_degrees

func _ready() -> void:
	if size == Vector2.ZERO:
		size = Vector2(106, 150)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	pivot_offset = size / 2.0
	original_rotation = rotation_degrees

func _process(delta: float) -> void:
	if is_dragging:
		var target_pos = get_global_mouse_position() - drag_offset
		global_position = global_position.lerp(target_pos, 25 * delta)
		
		rotation_degrees = lerp(rotation_degrees, 0.0, 15 * delta)
		scale = scale.lerp(Vector2.ONE, 15 * delta)
	elif is_hovered:
		var hovered_pos = original_position + Vector2(0, -40)
		global_position = global_position.lerp(hovered_pos, 15 * delta)
		rotation_degrees = lerp(rotation_degrees, 0.0, 15 * delta)
		scale = scale.lerp(Vector2(1.25,1.25), 15 * delta)
	else:
		global_position = global_position.lerp(original_position, 15 * delta)
		rotation_degrees = lerp(rotation_degrees, original_rotation, 15 * delta) 
		scale = scale.lerp(Vector2.ONE, 15 * delta)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = get_global_mouse_position() - global_position
			z_index = 100
		else:
			is_dragging = false
			z_index = 0
			_check_play_condition()
	
func _check_play_condition() -> void:
	if global_position.y < play_treshhold:
		card_played.emit(card_data)
	else:
		_reset_card_state()

func _reset_card_state() -> void:
	if not is_hovered and not is_dragging:
		z_index = 0

func _on_mouse_entered() -> void:
	if not is_dragging:
		is_hovered = true
		z_index = 50

func _on_mouse_exited() -> void:
	if not is_dragging:
		is_hovered = false
		_reset_card_state()
