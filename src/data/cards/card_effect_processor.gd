class_name CardEffectProcessor
extends RefCounted

static var effect_registry: Dictionary = {}

static func _static_init() -> void:
	effect_registry = {
		"set_infection_magical_girl": {
			"method": _fx_set_infection_magical_girl,
			"icon": preload("res://assets/icons/contamination_magical_girl.png")
		},
		"gain_charge": {
			"method": _fx_gain_charge,
			"icon": preload("res://assets/icons/charge.png")
		},
		"gain_charge_2": {
			"method": _fx_gain_charge_2,
			"icon": preload("res://assets/icons/charge.png")
		},
		"gain_charge_per_hit": {
			"method": _fx_gain_charge_per_hit,
			"icon": preload("res://assets/icons/charge.png")
		},
		"spend_all_energy_for_charge": {
			"method": _fx_spend_all_energy_for_charge,
			"icon": preload("res://assets/icons/charge.png")
		},
		"double_dmg_if_charge_5": {
			"method": _fx_double_dmg_if_charge_5,
			"icon": preload("res://assets/icons/double_damage.png")
		},
		"draw_card": {
			"method": _fx_draw_card,
			"icon": null
		},
		"draw_3": {
			"method": _fx_draw_3,
			"icon": null
		},
		"clean_debuffs": {
			"method": _fx_clean_debuffs,
			"icon": null
		},
		"charge_on_block_break": {
			"method": _fx_charge_on_block_break,
			"icon": preload("res://assets/icons/charge.png")
		},
		"apply_on_fire": {
			"method": _fx_apply_on_fire,
			"icon": null
		},
		"apply_status": {
			"method": _fx_apply_status,
			"icon": null
		},
		"trigger_status": {
			"method": _fx_trigger_status,
			"icon": null
		},
		"damage_per_status_stack": {
			"method": _fx_damage_per_status_stack,
			"icon": null
		},
		"extend_status": {
			"method": _fx_extend_status,
			"icon": null
		},
		"gain_build_resource": {
			"method": _fx_gain_build_resource,
			"icon": null
		},
		"gain_resource_per_statused_enemy": {
			"method": _fx_gain_resource_per_statused_enemy,
			"icon": null
		},
		# Служебные эффекты читаются другими системами и не требуют действия при розыгрыше.
		"exile_on_turn_end": {
			"method": _fx_noop,
			"icon": null
		},
		"reduce_cost_by_charge": {
			"method": _fx_noop,
			"icon": null
		}
	}

static func process_card(card_data: CardData, battle: Battle, selected_target: Node2D = null) -> void:
	var final_dmg: int = _calculate_modified_damage(card_data.dmg, battle)
	var final_shield: int = _calculate_modified_shield(card_data.shild, battle)
	var active_target: Node2D = _resolve_target(card_data, battle, selected_target)

	if final_dmg > 0:
		battle.player.play_attack()

		match card_data.target_type:
			CardData.TargetType.ENEMY:
				if is_instance_valid(active_target) and active_target.has_method("take_damage"):
					active_target.take_damage(final_dmg, card_data.id, card_data.damage_type)
				else:
					push_warning("CardEffectProcessor: нет цели для одиночной атаки.")

			CardData.TargetType.ALL_ENEMIES:
				for enemy in battle.enemies:
					if is_instance_valid(enemy) and enemy.hp > 0:
						enemy.take_damage(final_dmg, card_data.id, card_data.damage_type)

			CardData.TargetType.SELF, CardData.TargetType.ALL_HEROES:
				battle.player.take_damage(final_dmg, card_data.damage_type)

	if final_shield > 0:
		match card_data.target_type:
			CardData.TargetType.SELF:
				battle.player.add_block(final_shield)

			CardData.TargetType.ENEMY:
				if is_instance_valid(active_target) and active_target.has_method("add_block"):
					active_target.add_block(final_shield)

			CardData.TargetType.ALL_ENEMIES:
				for enemy in battle.enemies:
					if is_instance_valid(enemy) and enemy.has_method("add_block"):
						enemy.add_block(final_shield)

			CardData.TargetType.ALL_HEROES:
				battle.player.add_block(final_shield)
				if battle.has_node("Summons"):
					for summon in battle.get_node("Summons").get_children():
						if summon.has_method("add_block"):
							summon.add_block(final_shield)

	_apply_card_effects(card_data, battle, active_target)

static func _resolve_target(card_data: CardData, battle: Battle, selected_target: Node2D) -> Node2D:
	match card_data.target_type:
		CardData.TargetType.SELF, CardData.TargetType.ALL_HEROES:
			return battle.player

		CardData.TargetType.ENEMY:
			if (
				is_instance_valid(selected_target)
				and selected_target != battle.player
				and selected_target.has_method("take_damage")
			):
				return selected_target

		CardData.TargetType.ALL_ENEMIES:
			if is_instance_valid(selected_target) and selected_target is EnemyInBattle:
				return selected_target

	for enemy in battle.enemies:
		if is_instance_valid(enemy) and enemy.hp > 0 and enemy.has_method("take_damage"):
			return enemy
	return null

static func _apply_card_effects(card_data: CardData, battle: Battle, active_target: Node2D) -> void:
	for effect in card_data.effects:
		var effect_id: String = str(effect.get("id", ""))
		if effect_id.is_empty():
			continue
		if not effect_registry.has(effect_id):
			push_warning("CardEffectProcessor: эффект не зарегистрирован: %s" % effect_id)
			continue

		var effect_info: Dictionary = effect_registry[effect_id]
		var effect_method: Callable = effect_info.get("method", Callable())
		if not effect_method.is_valid():
			continue

		effect_method.call(battle, effect, active_target)
		_update_ui_effects(battle, effect_id)

static func _update_ui_effects(battle: Battle, effect_id: String) -> void:
	if not effect_registry.has(effect_id):
		return

	var effect_info: Dictionary = effect_registry[effect_id]
	var texture: Texture2D = effect_info.get("icon", null)
	if texture == null or battle.player.effects_ui == null:
		return

	if effect_id in [
		"gain_charge",
		"gain_charge_2",
		"gain_charge_per_hit",
		"spend_all_energy_for_charge",
		"charge_on_block_break"
	]:
		battle.player.effects_ui.update_effect("magical_charge", battle.magical_charge, texture)

	elif effect_id == "double_dmg_if_charge_5":
		battle.player.effects_ui.update_effect(effect_id, -1 if battle.magical_charge > 5 else 0, texture)

	elif effect_id == "set_infection_magical_girl":
		battle.player.effects_ui.update_effect(effect_id, -1 if battle.active_infection == "magical_girl" else 0, texture)

static func _calculate_modified_damage(base_dmg: int, battle: Battle) -> int:
	if base_dmg <= 0:
		return 0

	var result: int = base_dmg
	if battle.active_infection == "magical_girl":
		result += battle.magical_charge

	if battle.player.has_method("get_outgoing_damage_multiplier"):
		result = maxi(0, roundi(float(result) * battle.player.get_outgoing_damage_multiplier()))

	return result

static func _calculate_modified_shield(base_shield: int, battle: Battle) -> int:
	if base_shield <= 0:
		return 0

	var result: int = base_shield
	if battle.active_infection == "magical_girl":
		result += battle.magical_charge * 2

	result = maxi(0, roundi(float(result) * GameState.get_active_block_multiplier()))
	return result

static func calculate_dynamic_card_cost(card_data: CardData, battle: Battle) -> int:
	if card_data.id == "evt_transformation" or card_data.has_effect("reduce_cost_by_charge"):
		var reduction: int = int(floor(float(battle.magical_charge) / 2.0))
		return maxi(0, card_data.cost - reduction)
	return card_data.cost

static func _fx_set_infection_magical_girl(battle: Battle, _effect: Dictionary, _target: Node2D) -> void:
	battle.active_infection = "magical_girl"
	GameState.active_contamination = "magical_girl"
	battle.player.set_magical_girl_form(true)

static func _fx_gain_charge(battle: Battle, effect: Dictionary, _target: Node2D) -> void:
	battle.add_build_resource(&"magical_charge", int(effect.get("amount", 1)))

static func _fx_gain_charge_2(battle: Battle, effect: Dictionary, _target: Node2D) -> void:
	battle.add_build_resource(&"magical_charge", int(effect.get("amount", 2)))

static func _fx_gain_charge_per_hit(battle: Battle, effect: Dictionary, _target: Node2D) -> void:
	var per_target: int = int(effect.get("amount", 1))
	var alive_enemies_count: int = 0
	for enemy in battle.enemies:
		if is_instance_valid(enemy) and enemy.hp > 0:
			alive_enemies_count += 1
	battle.add_build_resource(&"magical_charge", alive_enemies_count * per_target)

static func _fx_spend_all_energy_for_charge(battle: Battle, effect: Dictionary, _target: Node2D) -> void:
	var multiplier: int = int(effect.get("multiplier", 2))
	var left_energy: int = battle.player.energy
	if left_energy <= 0:
		return
	battle.player.spend_energy(left_energy)
	battle.add_build_resource(&"magical_charge", left_energy * multiplier)

static func _fx_double_dmg_if_charge_5(battle: Battle, effect: Dictionary, target: Node2D) -> void:
	var threshold: int = int(effect.get("threshold", 5))
	var charge_cost: int = int(effect.get("charge_cost", 3))
	var extra_damage: int = int(effect.get("extra_damage", 10))
	if battle.player.has_method("get_outgoing_damage_multiplier"):
		extra_damage = maxi(0, roundi(float(extra_damage) * battle.player.get_outgoing_damage_multiplier()))
	if battle.magical_charge <= threshold:
		return

	battle.spend_build_resource(&"magical_charge", charge_cost)
	var active_target: Node2D = target if is_instance_valid(target) else battle.selected_enemy_target
	if is_instance_valid(active_target) and active_target.has_method("take_damage"):
		active_target.take_damage(extra_damage, "charge_burst", GameStateClass.DamageType.MAGIC)

static func _fx_draw_card(battle: Battle, effect: Dictionary, _target: Node2D) -> void:
	battle.draw_cards(int(effect.get("amount", 1)))

static func _fx_draw_3(battle: Battle, effect: Dictionary, _target: Node2D) -> void:
	battle.draw_cards(int(effect.get("amount", 3)))

static func _fx_clean_debuffs(battle: Battle, _effect: Dictionary, _target: Node2D) -> void:
	battle.player.clear_debuffs()

static func _fx_charge_on_block_break(battle: Battle, effect: Dictionary, _target: Node2D) -> void:
	battle.arm_charge_on_block_break(int(effect.get("amount", 2)))

static func _fx_apply_on_fire(battle: Battle, effect: Dictionary, target: Node2D) -> void:
	var generic: Dictionary = effect.duplicate(true)
	generic["status"] = "on_fire"
	generic["stacks"] = 1
	generic["max_stacks"] = 1
	generic["tick_damage"] = int(effect.get("damage", 3))
	generic["damage_type"] = int(GameStateClass.DamageType.MAGIC)
	_fx_apply_status(battle, generic, target)

static func _fx_apply_status(battle: Battle, effect: Dictionary, target: Node2D) -> void:
	var status_id: String = str(effect.get("status", ""))
	if status_id.is_empty():
		return
	var duration: int = maxi(1, int(effect.get("duration", 1)))
	var stacks: int = maxi(0, int(effect.get("stacks", 1)))
	var tick_damage: int = maxi(0, int(effect.get("tick_damage", 0)))
	var damage_per_stack: int = maxi(0, int(effect.get("damage_per_stack", 0)))
	var max_stacks: int = maxi(1, int(effect.get("max_stacks", 99)))
	var damage_type: int = int(effect.get("damage_type", GameStateClass.DamageType.PHYSICAL))
	var scale_with_player: bool = bool(effect.get("scale_with_damage", true))
	if scale_with_player and battle.player.has_method("get_outgoing_damage_multiplier"):
		var multiplier: float = battle.player.get_outgoing_damage_multiplier()
		tick_damage = maxi(0, roundi(float(tick_damage) * multiplier))
		damage_per_stack = maxi(0, roundi(float(damage_per_stack) * multiplier))

	if bool(effect.get("all_enemies", false)):
		for enemy in battle.enemies:
			if is_instance_valid(enemy) and enemy.hp > 0 and enemy.has_method("apply_status"):
				enemy.apply_status(status_id, duration, stacks, tick_damage, damage_per_stack, damage_type, max_stacks)
	elif is_instance_valid(target) and target.has_method("apply_status"):
		target.apply_status(status_id, duration, stacks, tick_damage, damage_per_stack, damage_type, max_stacks)
	elif is_instance_valid(target) and target.has_method("apply_debuff"):
		target.apply_debuff(status_id, duration, maxi(stacks, 1))

static func _fx_trigger_status(battle: Battle, effect: Dictionary, target: Node2D) -> void:
	var status_id: String = str(effect.get("status", ""))
	if status_id.is_empty():
		return
	if bool(effect.get("all_enemies", false)):
		for enemy in battle.enemies:
			if is_instance_valid(enemy) and enemy.hp > 0 and enemy.has_method("trigger_status"):
				enemy.trigger_status(status_id)
	elif is_instance_valid(target) and target.has_method("trigger_status"):
		target.trigger_status(status_id)

static func _fx_damage_per_status_stack(battle: Battle, effect: Dictionary, target: Node2D) -> void:
	if not is_instance_valid(target) or not target.has_method("get_status_stacks"):
		return
	var status_id: String = str(effect.get("status", ""))
	var stacks: int = target.get_status_stacks(status_id)
	if stacks <= 0:
		return
	var damage_per_stack: int = maxi(0, int(effect.get("damage_per_stack", 1)))
	var damage: int = stacks * damage_per_stack
	if battle.player.has_method("get_outgoing_damage_multiplier"):
		damage = maxi(0, roundi(float(damage) * battle.player.get_outgoing_damage_multiplier()))
	if damage > 0 and target.has_method("take_damage"):
		target.take_damage(damage, str(effect.get("source", "status_burst")), int(effect.get("damage_type", GameStateClass.DamageType.PSYCHIC)))
	if bool(effect.get("consume", false)) and target.has_method("remove_status"):
		target.remove_status(status_id)

static func _fx_extend_status(_battle: Battle, effect: Dictionary, target: Node2D) -> void:
	if not is_instance_valid(target) or not target.has_method("extend_status"):
		return
	var status_id: String = str(effect.get("status", ""))
	target.extend_status(status_id, int(effect.get("turns", 1)))

static func _fx_gain_build_resource(battle: Battle, effect: Dictionary, _target: Node2D) -> void:
	battle.add_active_build_resource(int(effect.get("amount", 1)))

static func _fx_gain_resource_per_statused_enemy(battle: Battle, effect: Dictionary, _target: Node2D) -> void:
	var status_id: String = str(effect.get("status", ""))
	var per_enemy: int = int(effect.get("amount", 1))
	var count: int = 0
	for enemy in battle.enemies:
		if is_instance_valid(enemy) and enemy.hp > 0 and enemy.has_method("has_status") and enemy.has_status(status_id):
			count += 1
	if count > 0:
		battle.add_active_build_resource(count * per_enemy)

static func _fx_noop(_battle: Battle, _effect: Dictionary, _target: Node2D) -> void:
	pass
