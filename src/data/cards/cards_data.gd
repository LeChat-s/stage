class_name CardData
extends Resource

enum TargetType { ENEMY, SELF, ALL_ENEMIES, ALL_HEROES }

@export var id: String
@export var name: String
@export var dmg: int = 0
@export var shild: int = 0
@export var cost: int = 1
@export var type: String
@export var effects: Array[String] = []
@export var description: String

@export var effect_type: String
@export var artwork: Texture2D
