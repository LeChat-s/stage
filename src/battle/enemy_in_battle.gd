class_name EnemyInBattle
extends Node2D

signal hp_changed(curent: int, max_hp: int)
signal block_changed(amount: int)
signal intent_changed(text: String)
signal died

@onready var attack_effect: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: ProgressBar = $HPBar
@onready var block_text: Label = $HPBar/Block
@onready var intent_text: Label = $Intent
@onready var hp_text: Label = $HPBar/HPText
@onready var enemy_sprite: Sprite2D = $EnemySprite 

var hp: int
var max_hp: int
var two_phase_hp: int
var phase: int
var block: int
var actions: Array[String] = []
var action_index: int = 0
var damage_popup_scene: PackedScene = preload("res://src/ui/dmg_popups.tscn")
var current_enemy_data: EnemyData 
var buffs: Dictionary = {}
var debuffs: Dictionary = {}

func _ready() -> void:
	var click_zone = $Area2D
	if click_zone:
		click_zone.input_event.connect(_on_click_zone_input_event)

func setup(enemy_data: EnemyData) -> void:
	current_enemy_data = enemy_data
	max_hp = enemy_data.max_hp
	hp = max_hp
	two_phase_hp = enemy_data.two_phase_hp
	phase = enemy_data.phase
	actions = enemy_data.actions
	if enemy_sprite and enemy_data.sprite:
		enemy_sprite.texture = enemy_data.sprite
		enemy_sprite.visible = true
	else:
		print("Предупреждение: Спрайт не найден или в EnemyData отсутствует текстура!")
	emit_signals()
	show_intent()

func resetup(enemy_data:EnemyData) -> void:
	max_hp = enemy_data.two_phase_hp
	hp = max_hp
	phase = 0
	actions = enemy_data.two_phase_actions
	if enemy_sprite and enemy_data.two_phase_sprite:
		enemy_sprite.texture = enemy_data.two_phase_sprite
		enemy_sprite.visible = true
	else:
		print("Предупреждение: Спрайт не найден или в EnemyData отсутствует текстура для второй фазы!")
	emit_signals()
	show_intent()

func _on_click_zone_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var battle_scene = get_tree().current_scene as Battle
		if battle_scene:
			battle_scene.select_new_target(self)

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
		if phase > 0:
			resetup(current_enemy_data) 
			print("вторая фаза")
		else:
			enemy_sprite.visible = false
			attack_effect.visible = true
			attack_effect.play("mushroom_die")
			await attack_effect.animation_finished
			queue_free()
	
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
	block = 0
	var parts = action.split(":")
	var action_type = parts[0]
	var value = int(parts[1])
	
	var battle_scene = get_tree().current_scene as Battle

	match action_type:
		"attack":
			var final_damage = value
			if buffs.has("rage"):
				final_damage += buffs["rage"]
			target.take_damage(final_damage)
			
		"defend":
			add_block(value)
			
		"summon":
			if battle_scene and battle_scene.has_method("summon_minion"):
				battle_scene.summon_minion(value)
				
		"debuff":
			if target.has_method("apply_debuff"):
				target.apply_debuff("weak", value)
				
		"self_buff":
			buffs["rage"] = buffs.get("rage", 0) + value
			print("Босс усилил себя! Текущая ярость: ", buffs["rage"])
			
		"buff_minions":
			if battle_scene and battle_scene.has_node("Enemies"):
				for enemy in battle_scene.get_node("Enemies").get_children():
					if enemy != self and enemy.has_method("add_block"):
						enemy.add_block(value) 
						
	tick_buffs()
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
			var dmg = int(parts[1])
			if buffs.has("rage"):
				dmg += buffs["rage"]
			text = "Атака: " + str(dmg)
		"defend":
			text = "Защита: " + parts[1]
		"summon":
			text = "Призыв миньона"
		"debuff":
			text = "Ослабление игрока (Слабость: " + parts[1] + " х.)"
		"self_buff":
			text = "Концентрация (Атака +" + parts[1] + ")"
		"buff_minions":
			text = "Усиление миньонов (Блок +" + parts[1] + ")"
	intent_changed.emit(text)

func apply_debuff(debuff_name: String, duration: int) -> void:
	debuffs[debuff_name] = debuffs.get(debuff_name, 0) + duration

func tick_buffs() -> void:
	for key in debuffs.keys():
		debuffs[key] -= 1
		if debuffs[key] <= 0:
			debuffs.erase(key)
			
func emit_signals() -> void:
	hp_changed.emit(hp, max_hp)
	block_changed.emit(block)

func _on_hp_changed(curent: int, maximum_hp) -> void:
	hp_bar.max_value = maximum_hp
	hp_bar.value = curent
	if hp_text:
		hp_text.text = str(curent) + " / " + str(maximum_hp)
func _on_block_changed(amount: int) -> void:
	block_text.text = str(amount) 

func _on_intent_changed(text: String) -> void:
	intent_text.text = text

func set_highlight(active: bool) -> void:
	if active:
		modulate = Color(1.5, 1.5, 1.2, 1.0)
	else:
		modulate = Color.WHITE 
