class_name PlayerInBattle
extends Node2D

signal hp_changed(curent: int, max_hp: int)
signal block_changed(amount: int)
signal energy_changed(amount: int)
signal died

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hp_bar: ProgressBar = $HPBar
@onready var block_text: Label = $HPBar/Block
@onready var hp_text: Label = $HPBar/HPText
@onready var catch_up_bar: ProgressBar = $CatchUpBar
@onready var effects_ui: EffectContainer = $HPBar/Status
@onready var magical_girl_sprite: Sprite2D = $MagicalGirlSprite

var is_magical_girl: bool = false
var hp: int
var clas: String
var max_hp: int
var block: int
var energy: int
var max_energy: int = 5
var damage_popup_scene: PackedScene = preload("res://src/ui/dmg_popups.tscn")
var buffs: Buff = Buff.new()

func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	var click_zone = $Area2D
	if click_zone:
		click_zone.input_event.connect(_on_click_zone_input_event)

func setup(player_data: Dictionary) -> void:
	hp = GameState.player_hp
	max_hp = player_data["max_hp"]

	if has_node("CatchUpBar"):
		$CatchUpBar.value = max_hp

	energy = max_energy
	is_magical_girl = false

	if magical_girl_sprite:
		magical_girl_sprite.visible = false

	emit_signals()
	animation_player.play("idle_battle")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack_battle":
		if is_magical_girl:
			animation_player.play("idle_magical_girl")
		else:
			animation_player.play("idle_battle")

func play_attack() -> void:
	animation_player.play("attack_battle")

func set_magical_girl_form(active: bool) -> void:
	is_magical_girl = active

	if magical_girl_sprite:
		magical_girl_sprite.visible = active

	$Sprite2D.visible = not active

	if active:
		animation_player.play("idle_magical_girl")
	else:
		animation_player.play("idle_battle")
		
func take_damage(amount: int, type: GameStateClass.DamageType = GameStateClass.DamageType.PHYSICAL) -> void:
	var processed_damage: int = GameState.calculate_incoming_damage(amount, int(type))
	processed_damage = buffs.process_damage(processed_damage)
	if damage_popup_scene:
		var popup = damage_popup_scene.instantiate()
		get_tree().current_scene.add_child(popup)
		popup.start_with_type(processed_damage, $Sprite2D.global_position, type)
	var remaining = processed_damage
	if block > 0:
		var absorbed = min(block, remaining)
		block -= absorbed
		remaining -= absorbed
	hp -= remaining
	if hp < 0:
		hp = 0
		
	GameState.player_hp = hp
	print("Оставшееся HP игрока: ", GameState.player_hp)
	
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
	buffs.tick()
	block = 0
	var bonus = GameState.get_bonus_energy()
	energy = max_energy + bonus
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

func add_energy(value: int) -> void:
	print(energy)
	energy = energy + value
	print(energy)

func set_highlight(active: bool) -> void:
	var my_sprite = $Sprite2D 
	if not my_sprite: return
		
	if active:
		if not my_sprite.material is ShaderMaterial:
			var shader_res = load("res://src/shaders/outline.gdshader") as Shader
			if shader_res:
				var shader_mat = ShaderMaterial.new()
				shader_mat.shader = shader_res
				my_sprite.material = shader_mat
		
		if my_sprite.material is ShaderMaterial:
			my_sprite.material.set_shader_parameter("width", 2.0)
			my_sprite.material.set_shader_parameter("outline_color", Color(0.816, 0.725, 0.329, 1.0)) 
	else:
		if my_sprite.material is ShaderMaterial:
			my_sprite.material.set_shader_parameter("width", 0.0)

func _on_click_zone_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var battle_scene = get_tree().current_scene as Battle
		if battle_scene:
			battle_scene.select_new_target(self)

func apply_buff(buff_id: String, duration: int = 1, level: int = 0) -> void:
	buffs.apply(buff_id, duration, level)
