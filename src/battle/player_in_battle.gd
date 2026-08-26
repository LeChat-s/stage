class_name PlayerInBattle
extends Node2D

signal hp_changed(curent: int, max_hp: int)
signal block_changed(amount: int)
signal energy_changed(amount: int)
signal died

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hp_bar: ProgressBar = $HPBar
@onready var block_text: Label = $HPBar/Block
@onready var energy_text: Label = $Energy
@onready var hp_text: Label = $HPBar/HPText
@onready var catch_up_bar: ProgressBar = $CatchUpBar

var hp: int
var max_hp: int
var block: int
var energy: int
var max_energy: int = 3
var damage_popup_scene: PackedScene = preload("res://src/ui/dmg_popups.tscn")

func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	
func setup(player_data: Dictionary) -> void:
	hp = player_data["hp"]
	max_hp = player_data["max_hp"]
	if has_node("CatchUpBar"):
		$CatchUpBar.value = max_hp
	energy = max_energy
	emit_signals()
	animation_player.play("idle_battle")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack_battle":
		animation_player.play("idle_battle")

func play_attack()-> void:
	animation_player.play("attack_battle")

func take_damage(amount: int) -> void:
	if damage_popup_scene:
		var popup = damage_popup_scene.instantiate()
		get_tree().current_scene.add_child(popup)
		popup.start(amount, $Sprite2D.global_position)
	
	var remaining = amount
	if block > 0:
		var absorbed = min(block, remaining)
		block -= remaining
		remaining -= absorbed
	hp -= remaining
	if hp < 0:
		hp = 0
	emit_signals()
	if hp <= 0:
		died.emit()
	
func add_block(amount: int) -> void:
	block += amount
	emit_signals()

func spend_energy(amount: int) -> bool:
	if energy >= amount:
		energy -= amount
		emit_signals()
		return true
	return false

func reset_turn() -> void:
	block = 0
	energy = max_energy
	emit_signals()

func emit_signals() -> void:
	hp_changed.emit(hp, max_hp)
	block_changed.emit(block)
	energy_changed.emit(energy)

func _on_hp_changed(curent: int, p_max_hp: int) -> void:
	hp_bar.max_value = p_max_hp
	if catch_up_bar:
		catch_up_bar.max_value = p_max_hp
	
	hp_bar.value = curent
	
	if hp_text:
		hp_text.text = str(curent) + " / " + str(p_max_hp)
	if catch_up_bar:
		var tween = create_tween()
		tween.tween_interval(0.5)
		tween.tween_property(catch_up_bar, "value", curent, 0.4)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)

func _on_block_changed(amount: int) -> void:
	if amount > 0:
		block_text.visible = true
		block_text.text = str(amount)
		var tween = create_tween()
		block_text.pivot_offset = block_text.size / 2.0
		tween.tween_property(block_text, "scale", Vector2(1.2, 1.2), 0.05)
		tween.tween_property(block_text, "scale", Vector2.ONE, 0.05)
	else:
		block_text.visible = false

func _on_energy_changed(amount: int) -> void:
	energy_text.text = str(amount) 
