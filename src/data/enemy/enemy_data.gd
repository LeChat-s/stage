class_name EnemyData
extends Resource

@export var id: String
@export var name: String
@export var max_hp: int = 50
@export var actions: Array[String] = []
@export var sprite: Texture2D
@export var phase: int
@export var two_phase_hp: int = 70
@export var two_phase_actions: Array[String] = []
@export var two_phase_sprite: Texture2D
