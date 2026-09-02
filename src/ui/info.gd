class_name Info
extends Control

@onready var hp_label: Label = $TabContainer/Stats/Paper/VBoxContainer/HPLabel

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	update_hp_display()

func _on_visibility_changed() -> void:
	if visible:
		update_hp_display()

func update_hp_display() -> void:
	if not hp_label:
		return
	hp_label.text = "Физическое состояние — %d" % GameState.player_hp

func _find_player_by_class(node: Node) -> PlayerInBattle:
	if node is PlayerInBattle:
		return node
	for child in node.get_children():
		var result = _find_player_by_class(child)
		if result:
			return result
	return null
