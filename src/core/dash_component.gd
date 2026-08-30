class_name DashComponent
extends Node

signal dash_started
signal dash_teleported
signal dash_finished

@export var dash_distance: float = 250.0 
@export var dash_duration: float = 0.25
@export var recovery_time: float = 0.25  
@export var cooldown_time: float = 0.8  

var is_dashing: bool = false
var can_dash: bool = true

func start_dash(body: CharacterBody2D, face_direction: Vector2) -> void:
	if not can_dash or is_dashing: return
	
	is_dashing = true
	can_dash = false
	dash_started.emit()
	
	body.velocity = Vector2.ZERO
	await get_tree().create_timer(dash_duration).timeout
	
	if face_direction == Vector2.ZERO:
		face_direction = Vector2.RIGHT
	
	body.global_position += face_direction * dash_distance
	dash_teleported.emit()
	
	await get_tree().create_timer(recovery_time).timeout
	is_dashing = false
	dash_finished.emit()
	
	await get_tree().create_timer(cooldown_time).timeout
	can_dash = true
