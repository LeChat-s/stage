class_name PlayerInBattle
extends Node2D

signal hp_changed(curent: int, max_hp: int)
signal block_changed(amount: int)
signal block_broken
signal energy_changed(amount: int)
signal died

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hp_bar: ProgressBar = $HPBar
@onready var block_text: Label = $HPBar/Block
@onready var hp_text: Label = $HPBar/HPText
@onready var catch_up_bar: ProgressBar = $CatchUpBar
@onready var effects_ui: EffectContainer = $HPBar/Status
@onready var main_sprite: Sprite2D = $Sprite2D
@onready var magical_girl_sprite: Sprite2D = $MagicalGirlSprite

var is_magical_girl: bool = false
var hp: int
var clas: String
var max_hp: int
var block: int = 0
var energy: int
var max_energy: int = 5
var damage_popup_scene: PackedScene = preload("res://src/ui/dmg_popups.tscn")
var buffs: Buff = Buff.new()
var debuffs: Dictionary = {}

var active_build: ContaminationData = null
var _base_max_hp: int = 0
var _base_texture: Texture2D
var _base_hframes: int = 1
var _base_vframes: int = 1
var _base_position: Vector2
var _base_scale: Vector2
var _base_frame: int = 0

var _build_frames: PackedInt32Array = PackedInt32Array()
var _build_frame_index: int = 0
var _build_elapsed: float = 0.0
var _build_fps: float = 8.0
var _build_animation_once: bool = false

func _ready() -> void:
	_base_texture = main_sprite.texture
	_base_hframes = main_sprite.hframes
	_base_vframes = main_sprite.vframes
	_base_position = main_sprite.position
	_base_scale = main_sprite.scale
	_base_frame = main_sprite.frame
	animation_player.animation_finished.connect(_on_animation_finished)
	var click_zone: Area2D = $Area2D
	if click_zone:
		click_zone.input_event.connect(_on_click_zone_input_event)
	set_process(true)

func _process(delta: float) -> void:
	if active_build == null or active_build.player_sprite_sheet == null or _build_frames.is_empty():
		return
	_build_elapsed += delta
	var frame_time: float = 1.0 / maxf(_build_fps, 1.0)
	if _build_elapsed < frame_time:
		return
	_build_elapsed = fmod(_build_elapsed, frame_time)
	_build_frame_index += 1

	if _build_frame_index >= _build_frames.size():
		if _build_animation_once:
			_play_build_idle()
			return
		_build_frame_index = 0

	_apply_build_frame()

func setup(player_data: Dictionary) -> void:
	_base_max_hp = int(player_data["max_hp"])
	hp = GameState.player_hp
	max_hp = _base_max_hp
	block = 0
	debuffs.clear()
	buffs.clear()
	active_build = null
	_restore_base_appearance()

	if has_node("CatchUpBar"):
		$CatchUpBar.value = max_hp

	energy = max_energy
	is_magical_girl = false
	if magical_girl_sprite:
		magical_girl_sprite.visible = false

	emit_signals()
	animation_player.play("idle_battle")

func _on_animation_finished(anim_name: StringName) -> void:
	if active_build != null and active_build.player_sprite_sheet != null:
		return
	if anim_name == &"attack_battle":
		animation_player.play("idle_magical_girl" if is_magical_girl else "idle_battle")

func play_attack() -> void:
	if active_build != null and active_build.player_sprite_sheet != null:
		if not active_build.attack_frames.is_empty():
			_play_build_animation(active_build.attack_frames, active_build.attack_fps, true)
		return
	animation_player.play("attack_battle")

func apply_contamination_build(build: ContaminationData) -> void:
	active_build = build
	is_magical_girl = build != null and String(build.id) == "magical_girl"
	_apply_build_max_hp_bonus()

	if build == null or build.player_sprite_sheet == null:
		if is_magical_girl:
			_set_legacy_magical_girl(true)
		else:
			_restore_base_appearance()
		return

	animation_player.stop()
	magical_girl_sprite.visible = false
	main_sprite.visible = true
	main_sprite.texture = build.player_sprite_sheet
	main_sprite.hframes = maxi(build.player_hframes, 1)
	main_sprite.vframes = maxi(build.player_vframes, 1)
	main_sprite.position = build.sprite_offset
	main_sprite.scale = build.sprite_scale
	_play_build_idle()

func clear_contamination_build() -> void:
	active_build = null
	is_magical_girl = false
	_apply_build_max_hp_bonus()
	_restore_base_appearance()
	animation_player.play("idle_battle")

func set_magical_girl_form(active: bool) -> void:
	if active and GameState.active_contamination_data != null:
		apply_contamination_build(GameState.active_contamination_data)
		return
	active_build = null
	is_magical_girl = active
	_apply_build_max_hp_bonus()
	_set_legacy_magical_girl(active)

func _set_legacy_magical_girl(active: bool) -> void:
	if magical_girl_sprite:
		magical_girl_sprite.visible = active
	main_sprite.visible = not active
	animation_player.play("idle_magical_girl" if active else "idle_battle")

func _restore_base_appearance() -> void:
	_build_frames = PackedInt32Array()
	main_sprite.visible = true
	main_sprite.texture = _base_texture
	main_sprite.hframes = _base_hframes
	main_sprite.vframes = _base_vframes
	main_sprite.position = _base_position
	main_sprite.scale = _base_scale
	main_sprite.frame = _base_frame
	if magical_girl_sprite:
		magical_girl_sprite.visible = false

func _play_build_idle() -> void:
	if active_build == null:
		return
	var frames := active_build.idle_frames
	if frames.is_empty():
		frames = PackedInt32Array([0])
	_play_build_animation(frames, active_build.idle_fps, false)

func _play_build_animation(frames: PackedInt32Array, fps: float, once: bool) -> void:
	_build_frames = frames
	_build_fps = maxf(fps, 1.0)
	_build_animation_once = once
	_build_frame_index = 0
	_build_elapsed = 0.0
	_apply_build_frame()

func _apply_build_frame() -> void:
	if _build_frames.is_empty():
		return
	var total_frames: int = maxi(main_sprite.hframes * main_sprite.vframes, 1)
	var frame: int = _build_frames[clampi(_build_frame_index, 0, _build_frames.size() - 1)]
	main_sprite.frame = clampi(frame, 0, total_frames - 1)

func _apply_build_max_hp_bonus() -> void:
	if _base_max_hp <= 0:
		return
	var previous_max: int = max_hp
	var bonus: int = GameState.get_active_max_hp_bonus() if GameState.active_contamination_data != null else 0
	max_hp = maxi(1, _base_max_hp + bonus)
	var delta: int = max_hp - previous_max
	if delta > 0:
		hp += delta
	else:
		hp = mini(hp, max_hp)
	GameState.player_hp = hp
	emit_signals()

func take_damage(amount: int, type: GameStateClass.DamageType = GameStateClass.DamageType.PHYSICAL) -> void:
	var processed_damage: int = GameState.calculate_incoming_damage(amount, int(type))
	processed_damage = buffs.process_damage(processed_damage)

	if damage_popup_scene:
		var popup = damage_popup_scene.instantiate()
		get_tree().current_scene.add_child(popup)
		popup.start_with_type(processed_damage, _get_visual_sprite().global_position, type)

	var remaining: int = processed_damage
	var previous_block: int = block
	if block > 0:
		var absorbed: int = mini(block, remaining)
		block -= absorbed
		remaining -= absorbed

	if previous_block > 0 and block <= 0 and remaining >= 0:
		block_broken.emit()

	hp = maxi(0, hp - remaining)
	GameState.player_hp = hp
	emit_signals()

	if hp <= 0:
		died.emit()

func add_block(amount: int) -> void:
	block += maxi(amount, 0)
	emit_signals()

func spend_energy(amount: int) -> bool:
	if amount <= 0:
		return true
	if energy < amount:
		return false
	energy -= amount
	emit_signals()
	return true

func add_energy(value: int) -> void:
	energy += value
	emit_signals()

func reset_turn() -> void:
	buffs.tick()
	block = 0
	energy = max_energy + GameState.get_bonus_energy()
	emit_signals()

func tick_end_turn_statuses() -> void:
	var expired: Array[String] = []
	for debuff_id in debuffs.keys():
		var data: Dictionary = debuffs[debuff_id]
		data["duration"] = int(data.get("duration", 1)) - 1
		if int(data["duration"]) <= 0:
			expired.append(str(debuff_id))
		else:
			debuffs[debuff_id] = data
	for debuff_id in expired:
		debuffs.erase(debuff_id)

func apply_debuff(debuff_id: String, duration: int, amount: int = 1) -> void:
	if buffs.blocks_debuff():
		print("Щит II+ уровня заблокировал негативный статус: ", debuff_id)
		return

	var data: Dictionary = debuffs.get(debuff_id, {})
	data["duration"] = maxi(int(data.get("duration", 0)), duration)
	data["amount"] = maxi(int(data.get("amount", 0)), amount)
	debuffs[debuff_id] = data

func clear_debuffs() -> void:
	debuffs.clear()

func has_debuff(debuff_id: String) -> bool:
	return debuffs.has(debuff_id)

func has_status(status_id: String) -> bool:
	return debuffs.has(status_id)

func get_status_stacks(status_id: String) -> int:
	if not debuffs.has(status_id):
		return 0
	var data: Dictionary = debuffs[status_id]
	return int(data.get("stacks", data.get("amount", 1)))

func get_status_data(status_id: String) -> Dictionary:
	if not debuffs.has(status_id):
		return {}
	var data: Dictionary = debuffs[status_id]
	return data.duplicate(true)

func remove_status(status_id: String) -> void:
	debuffs.erase(status_id)

func extend_status(status_id: String, turns: int) -> void:
	if not debuffs.has(status_id):
		return
	var data: Dictionary = debuffs[status_id]
	data["duration"] = maxi(0, int(data.get("duration", 0)) + turns)
	debuffs[status_id] = data

func get_outgoing_damage_multiplier() -> float:
	var result: float = GameState.get_active_damage_multiplier()
	if debuffs.has("weak"):
		result *= 0.75
	return result

func apply_buff(buff_id: String, duration: int = 1, level: int = 0) -> void:
	buffs.apply(buff_id, duration, level)

func get_buff_level(buff_id: String) -> int:
	return buffs.get_level(buff_id)

func set_buff_charges(buff_id: String, amount: int) -> void:
	buffs.set_charges(buff_id, amount)

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
		hp_text.text = "%d / %d" % [curent, p_max_hp]
	if catch_up_bar:
		var tween: Tween = create_tween()
		tween.tween_interval(0.5)
		tween.tween_property(catch_up_bar, "value", curent, 0.4)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)

func _on_block_changed(amount: int) -> void:
	if amount > 0:
		block_text.visible = true
		block_text.text = str(amount)
		var tween: Tween = create_tween()
		block_text.pivot_offset = block_text.size / 2.0
		tween.tween_property(block_text, "scale", Vector2(1.2, 1.2), 0.05)
		tween.tween_property(block_text, "scale", Vector2.ONE, 0.05)
	else:
		block_text.visible = false

func set_highlight(active: bool) -> void:
	var visual := _get_visual_sprite()
	if visual == null:
		return

	if active:
		if not visual.material is ShaderMaterial:
			var shader_res = load("res://src/shaders/outline.gdshader") as Shader
			if shader_res:
				var shader_mat := ShaderMaterial.new()
				shader_mat.shader = shader_res
				visual.material = shader_mat
		if visual.material is ShaderMaterial:
			visual.material.set_shader_parameter("width", 2.0)
			visual.material.set_shader_parameter("outline_color", Color(0.816, 0.725, 0.329, 1.0))
	else:
		if visual.material is ShaderMaterial:
			visual.material.set_shader_parameter("width", 0.0)

func _get_visual_sprite() -> Sprite2D:
	if magical_girl_sprite != null and magical_girl_sprite.visible:
		return magical_girl_sprite
	return main_sprite

func _on_click_zone_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var battle_scene := get_tree().current_scene as Battle
		if battle_scene:
			battle_scene.select_new_target(self)
