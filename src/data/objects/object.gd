extends Node2D

signal player_detected(data: ObjectData)

@export var data: ObjectData 

@onready var interact_label: RichTextLabel = $InteractionLabel
@onready var art: Sprite2D = $Art

var is_player_inside: bool = false

func _ready() -> void:
	interact_label.visible = false
	art.texture = data.artwork
	art.visible = true

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		if is_player_inside == true:
			print("игрок получил карту")
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		is_player_inside = true
		player_detected.emit(data)
		interact_label.text = data.interaction_text
		interact_label.visible = true
		
func _on_body_exited(body: Node2D) -> void:
	interact_label.visible = false
	is_player_inside = false
