class_name ObjectData
extends Resource

enum TargetType { NOTE, CARD, CHEST}

@export var id: String
@export var name: String
@export var type: String
@export var effects: Array[String] = []
@export var interaction_text: String
@export var description: String
@export var artwork: Texture2D
