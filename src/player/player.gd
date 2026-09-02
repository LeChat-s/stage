class_name Player
extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var dash_component: DashComponent = $DashComponent

signal position_changed(position: Vector2)

var face_direction: Vector2 = Vector2.RIGHT

func _physics_process(delta: float) -> void:
	
	var direction := Input.get_axis("move_left", "move_right")
	
	if direction != 0:
		face_direction = Vector2(direction, 0)
		sprite.flip_h = direction < 0 
	
	if Input.is_action_just_pressed("jump"):
		velocity_component.jump(self)
	
	if Input.is_action_just_pressed("dash"):
		dash_component.start_dash(self, face_direction)

	if dash_component.is_dashing:
		move_and_slide()
		position_changed.emit(global_position)
	else:
		velocity_component.handle_movement(self, direction, delta)
		move_and_slide()
		position_changed.emit(global_position)
		_update_animation(direction)

func _update_animation(direction: float) -> void:
	if not is_on_floor():
		_update_jump_animation()
		return
	if direction != 0:
		_play_animation("run")
	else:
		_play_animation("idle")

func _update_jump_animation() -> void:
	if velocity.y < 0:
		_play_animation("jump_up")
		animation_player.speed_scale = clamp(abs(velocity.y) / 600, 0.7, 1.0)
	else:
		if abs(velocity.y) >= 600:
			_play_animation("jump_down_loop")
		else:
			_play_animation("jump_down")
			animation_player.speed_scale = clamp(abs(velocity.y) / 600, 0.7, 1.0)

func _play_animation(anim_name: String) -> void:
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)
		animation_player.speed_scale = 1.0

func _on_dash_started() -> void:
	_play_animation("dash")
