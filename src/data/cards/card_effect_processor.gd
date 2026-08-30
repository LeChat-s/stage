class_name CardEffectProcessor
extends RefCounted

static var effect_registry: Dictionary = {
	"set_infection_magical_girl": _fx_set_infection_magical_girl,
	"gain_charge_2": _fx_gain_charge_2,
	"gain_charge_per_hit": _fx_gain_charge_per_hit,
	"spend_all_energy_for_charge": _fx_spend_all_energy_for_charge,
	"double_dmg_if_charge_5": _fx_double_dmg_if_charge_5,
	
	"draw_card": _fx_draw_card,
	"draw_3": _fx_draw_3,
	"clean_debuffs": _fx_clean_debuffs
}

static func process_card(card_data: CardData, battle: Battle) -> void:
	var final_dmg = _calculate_modified_damage(card_data.dmg, battle)
	var final_shield = _calculate_modified_shield(card_data.shild, battle)
	
	if final_dmg > 0:
		battle.player.play_attack()
		battle.enemy.take_damage(final_dmg)
			
	if final_shield > 0:
		battle.player.add_block(final_shield)
		
	for effect_data in card_data.effects:
		if not effect_data is Dictionary:
			print("Ошибка: Элемент эффекта не является Словарем!")
			continue
			
		var effect: Dictionary = effect_data
		var effect_id = effect.get("id", "")
		
		if effect_registry.has(effect_id):
			effect_registry[effect_id].call(battle, effect)
		else:
			print("Эффект не найден: ", effect_id)

static func _calculate_modified_damage(base_dmg: int, battle: Battle) -> int:
	if base_dmg <= 0: return 0
	match battle.active_infection:
		"inf_magical_girl":
			return base_dmg + battle.magical_charge
	return base_dmg

static func _calculate_modified_shield(base_shield: int, battle: Battle) -> int:
	if base_shield <= 0: return 0
	match battle.active_infection:
		"inf_magical_girl":
			return base_shield + (battle.magical_charge * 2)
	return base_shield

static func calculate_dynamic_card_cost(card_data: CardData, battle: Battle) -> int:
	if card_data.id == "evt_transformation" or card_data.has_effect("reduce_cost_by_charge"):
		var reduction := int(floor(float(battle.magical_charge) / 2.0))
		return max(0, card_data.cost - reduction)
	return card_data.cost

static func _fx_set_infection_magical_girl(battle: Battle, _effect: Dictionary) -> void:
	battle.active_infection = "inf_magical_girl"
	print("Заражение: Девочка-волшебница успешно активировано.")

static func _fx_gain_charge_2(battle: Battle, _effect: Dictionary) -> void:
	battle.magical_charge += 2
	print(battle.magical_charge)
static func _fx_gain_charge_per_hit(battle: Battle, _effect: Dictionary) -> void:
	battle.magical_charge += 1
	print(battle.magical_charge)
static func _fx_spend_all_energy_for_charge(battle: Battle, _effect: Dictionary) -> void:
	var left_energy = battle.player.energy
	battle.player.spend_energy(left_energy)
	battle.magical_charge += left_energy * 2
	print(battle.magical_charge)
static func _fx_double_dmg_if_charge_5(battle: Battle, _effect: Dictionary) -> void:
	if battle.magical_charge > 5:
		battle.magical_charge -= 3
		print(battle.magical_charge)
		battle.enemy.take_damage(10)

static func _fx_draw_card(battle: Battle, _effect: Dictionary) -> void:
	battle.draw_cards(1)

static func _fx_draw_3(battle: Battle, _effect: Dictionary) -> void:
	battle.draw_cards(3)

static func _fx_clean_debuffs(battle: Battle, _effect: Dictionary) -> void:
	if battle.player.has_method("clear_debuffs"):
		battle.player.clear_debuffs()
