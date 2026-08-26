class_name VelocityComponent
extends Node

@export var speed: float = 275.0         
@export var jump_velocity: float = -600.0 
@export var gravity_scale: float = 2.0 
@export var wall_push: float = 400.0 

var default_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var last_normal: float = 0.0

func handle_movement(body: CharacterBody2D, direction: float, delta: float) -> void:

	if not body.is_on_floor():
		body.velocity.y += default_gravity * gravity_scale * delta
	if direction != 0:
		body.velocity.x = direction * speed
	else:
		body.velocity.x = 0 

func jump(body: CharacterBody2D) -> void:
	if body.is_on_floor():
		body.velocity.y = jump_velocity
		last_normal = 0
	
	elif body.is_on_wall():
		var wall_normal = body.get_wall_normal()
		
		if wall_normal.x != last_normal:
			body.velocity.y = jump_velocity
			body.velocity.x = wall_normal.x * wall_push
			last_normal = wall_normal.x
