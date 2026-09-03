class_name CardEffectProcessor
extends RefCounted

# База данных эффектов: теперь хранит метод и путь к иконке (или готовую текстуру)
static var effect_registry: Dictionary = {
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
	"draw_card": { "method": _fx_draw_card, "icon": null },
	"draw_3": { "method": _fx_draw_3, "icon": null },
	"clean_debuffs": { "method": _fx_clean_debuffs, "icon": null }
}

static func process_card(card_data: CardData, battle: Battle, selected_target: EnemyInBattle = null) -> void:
	var final_dmg = _calculate_modified_damage(card_data.dmg, battle)
	var final_shield = _calculate_modified_shield(card_data.shild, battle)
	
	if final_dmg > 0:
		battle.player.play_attack()
		match card_data.target_type:
			CardData.TargetType.ENEMY:
				if is_instance_valid(selected_target):
					selected_target.take_damage(final_dmg)
				elif is_instance_valid(battle.selected_enemy_target):
					battle.selected_enemy_target.take_damage(final_dmg)
				else:
					print("Предупреждение: Нет выбранной цели для одиночной атаки!")
					
			CardData.TargetType.ALL_ENEMIES:
				for enemy in battle.enemies:
					if is_instance_valid(enemy) and enemy.hp > 0:
						enemy.take_damage(final_dmg)
						
				if is_instance_valid(selected_target):
					selected_target.take_damage(final_dmg)

	if final_shield > 0:
		battle.player.add_block(final_shield)
		
	for effect_data in card_data.effects:
		if not effect_data is Dictionary:
			print("Ошибка: Элемент эффекта не является Словарем!")
			continue
			
		var effect: Dictionary = effect_data
		var effect_id = effect.get("id", "")
		
		if effect_registry.has(effect_id):
			effect_registry[effect_id]["method"].call(battle, effect, selected_target)
			_update_ui_effects(battle, effect_id)
		else:
			print("Эффект не найден: ", effect_id)

static func _update_ui_effects(battle: Battle, effect_id: String) -> void:
	var effect_info = effect_registry[effect_id]
	var texture = effect_info["icon"]
	
	if texture == null:
		return
		
	if not "effects_ui" in battle.player:
		return
		
	var ui_container = battle.player.effects_ui
	
	if effect_id in ["gain_charge", "gain_charge_2", "gain_charge_per_hit", "spend_all_energy_for_charge"]:
		ui_container.update_effect("magical_charge", battle.magical_charge, texture)
		
	elif effect_id == "double_dmg_if_charge_5":
		var val = -1 if battle.magical_charge > 5 else 0
		ui_container.update_effect(effect_id, val, texture)
		
	elif effect_id == "set_infection_magical_girl":
		var val = -1 if battle.active_infection == "inf_magical_girl" else 0
		ui_container.update_effect(effect_id, val, texture)
	if effect_id in ["gain_charge_2", "gain_charge_per_hit", "spend_all_energy_for_charge"]:
		var double_dmg_texture = effect_registry["double_dmg_if_charge_5"]["icon"]
		if double_dmg_texture:
			var val = -1 if battle.magical_charge > 5 else 0
			ui_container.update_effect("double_dmg_if_charge_5", val, double_dmg_texture)
static func _calculate_modified_damage(base_dmg: int, battle: Battle) -> int:
	if base_dmg <= 0: return 0
	match battle.active_infection:
		"inf_magical_girl": return base_dmg + battle.magical_charge
	return base_dmg

static func _calculate_modified_shield(base_shield: int, battle: Battle) -> int:
	if base_shield <= 0: return 0
	match battle.active_infection:
		"inf_magical_girl": return base_shield + (battle.magical_charge * 2)
	return base_shield

static func calculate_dynamic_card_cost(card_data: CardData, battle: Battle) -> int:
	if card_data.id == "evt_transformation" or card_data.has_effect("reduce_cost_by_charge"):
		var reduction := int(floor(float(battle.magical_charge) / 2.0))
		return max(0, card_data.cost - reduction)
	return card_data.cost

static func _fx_set_infection_magical_girl(battle: Battle, _effect: Dictionary, _target: EnemyInBattle) -> void:
	battle.active_infection = "inf_magical_girl"
	print("Заражение: Девочка-волшебница успешно активировано.")

static func _fx_gain_charge(battle: Battle, _effect: Dictionary, _target: EnemyInBattle) -> void:
	battle.magical_charge += 1
	print(battle.magical_charge)

static func _fx_gain_charge_2(battle: Battle, _effect: Dictionary, _target: EnemyInBattle) -> void:
	battle.magical_charge += 2
	print(battle.magical_charge)

static func _fx_gain_charge_per_hit(battle: Battle, _effect: Dictionary, _target: EnemyInBattle) -> void:
	var alive_enemies_count := 0
	for enemy in battle.enemies:
		if is_instance_valid(enemy) and enemy.hp > 0:
			alive_enemies_count += 1
	battle.magical_charge += alive_enemies_count
	print(alive_enemies_count," ",  battle.magical_charge)

static func _fx_spend_all_energy_for_charge(battle: Battle, _effect: Dictionary, _target: EnemyInBattle) -> void:
	var left_energy = battle.player.energy
	battle.player.spend_energy(left_energy)
	battle.magical_charge += left_energy * 2
	print(battle.magical_charge)

static func _fx_double_dmg_if_charge_5(battle: Battle, _effect: Dictionary, target: EnemyInBattle) -> void:
	if battle.magical_charge > 5:
		battle.magical_charge -= 3
		print(battle.magical_charge)
		var active_target = target if is_instance_valid(target) else battle.selected_enemy_target
		if is_instance_valid(active_target):
			active_target.take_damage(10)

static func _fx_draw_card(battle: Battle, _effect: Dictionary, _target: EnemyInBattle) -> void:
	battle.draw_cards(1)

static func _fx_draw_3(battle: Battle, _effect: Dictionary, _target: EnemyInBattle) -> void:
	battle.draw_cards(3)

static func _fx_clean_debuffs(battle: Battle, _effect: Dictionary, _target: EnemyInBattle) -> void:
	if battle.player.has_method("clear_debuffs"):
		battle.player.clear_debuffs()
