class_name EnemyInBattle
extends Node2D

signal hp_changed(curent: int, max_hp: int)
signal block_changed(amount: int)
signal intent_changed(text: String)
signal died

@onready var attack_effect: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: ProgressBar = $HPBar
@onready var block_text: Label = $Block
@onready var intent_text: Label = $Intent
@onready var hp_text: Label = $HPBar/HPText

var hp: int
var max_hp: int
var block: int
var actions: Array[String] = []
var action_index: int = 0
var damage_popup_scene: PackedScene = preload("res://src/ui/dmg_popups.tscn")

func setup(enemy_data: EnemyData) -> void:
	max_hp = enemy_data.max_hp
	hp = max_hp
	actions = enemy_data.actions
	emit_signals()
	show_intent()

func take_damage(amount: int, effect_name: String = "default_attack") -> void:
	if damage_popup_scene:
		var popup = damage_popup_scene.instantiate()
		var ui_node = get_tree().current_scene.get_node("UI")
		var screen_position = $AnimatedSprite2D.get_global_transform_with_canvas().origin
		if ui_node:
			ui_node.add_child(popup)
		else:
			get_tree().current_scene.add_child(popup)
		popup.start(amount, screen_position)
	var remaining = amount
	if block > 0:
		var absorbed = min(block, remaining)
		block -= absorbed
		remaining -= absorbed
	if attack_effect.sprite_frames.has_animation(effect_name):
		attack_effect.visible = true
		attack_effect.play(effect_name)
		await attack_effect.animation_finished
		attack_effect.visible = false
	hp -= remaining
	if hp < 0:
		hp = 0
	emit_signals()
	if hp <= 0:
		died.emit()
	
func add_block(amount: int) -> void:
	block += amount
	emit_signals()

func get_next_action() -> String:
	if actions.is_empty():
		return "attack:5"
	var action = actions[action_index % actions.size()]
	action_index += 1
	return action

func execute_action(action: String, target: PlayerInBattle) -> void:
	var parts = action.split(":")
	var action_type = parts[0]
	var value = int(parts[1])
	match action_type:
		"attack":
			target.take_damage(value)
		"defend":
			add_block(value)
	block = 0
	show_intent()

func show_intent() -> void:
	if actions.is_empty():
		intent_changed.emit("Атака: 5")
		return
	var next_action = actions[action_index % actions.size()]
	var parts = next_action.split(":")
	var text = ""
	match parts[0]:
		"attack":
			text = "Атака: " + parts[1]
		"defend":
			text = "Защита: " + parts[1]
	intent_changed.emit(text)

func emit_signals() -> void:
	hp_changed.emit(hp, max_hp)
	block_changed.emit(block)

func _on_hp_changed(curent: int, maximum_hp) -> void:
	hp_bar.max_value = maximum_hp
	hp_bar.value = curent
	if hp_text:
		hp_text.text = str(curent) + " / " + str(maximum_hp)
func _on_block_changed(amount: int) -> void:
	block_text.text = "Блок: " + str(amount) 

func _on_intent_changed(text: String) -> void:
	intent_text.text = text
