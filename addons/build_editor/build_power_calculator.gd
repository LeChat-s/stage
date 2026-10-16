@tool
extends RefCounted

# Editor-only calculator deliberately avoids class_name dependencies so the plugin
# can load even during the first filesystem scan after copying new scripts.
static func calculate(build) -> Dictionary:
	if build == null:
		return _empty()

	var offense: float = 0.0
	var defense: float = 0.0
	var utility: float = 0.0

	var cards = build.get("exclusive_cards")
	if cards != null:
		for card in cards:
			if card == null:
				continue
			var energy: float = maxf(float(card.get("cost")), 1.0)
			var target_type: int = int(card.get("target_type"))
			offense += float(card.get("dmg")) * _target_factor(target_type) / energy
			defense += float(card.get("shild")) * _defense_target_factor(target_type) / energy
			var effects = card.get("effects")
			if effects != null:
				offense += _effects_offense(effects) / energy
				utility += _effects_value(effects) / energy

	var abilities = build.get("abilities")
	if abilities != null:
		for ability in abilities:
			if ability == null:
				continue
			var cooldown: int = int(ability.get("cooldown"))
			var energy_cost: int = int(ability.get("energy_cost"))
			var resource_cost: int = int(ability.get("resource_cost"))
			var tempo: float = 1.0 / (1.0 + float(cooldown) * 0.35 + float(energy_cost) * 0.15 + float(resource_cost) * 0.08)
			var target_type: int = int(ability.get("target_type"))
			offense += float(ability.get("damage")) * _target_factor(target_type) * tempo * 1.25
			defense += float(ability.get("block")) * _defense_target_factor(target_type) * tempo * 1.25
			var effects = ability.get("effects")
			if effects != null:
				offense += _effects_offense(effects) * tempo
				utility += _effects_value(effects) * tempo
			if not bool(ability.get("consumes_turn")):
				utility += 3.0 * tempo

	var balance = build.get("balance")
	if balance != null:
		offense *= float(balance.get("damage_multiplier"))
		defense *= float(balance.get("block_multiplier"))
		defense += maxf(float(balance.get("max_hp_bonus")), 0.0) * 0.45
		var incoming: float = maxf(float(balance.get("incoming_damage_multiplier")), 0.1)
		if incoming < 1.0:
			defense += (1.0 / incoming - 1.0) * 35.0
		utility += float(balance.get("energy_bonus")) * 5.0

	var passives = build.get("passives")
	if passives != null:
		for passive in passives:
			if passive == null:
				continue
			var max_level: int = int(passive.get("max_level"))
			var value: float = float(passive.get("value_per_level")) * float(max_level)
			match int(passive.get("effect_type")):
				0: defense += value * 0.35
				1: offense *= 1.0 + value
				2: defense *= 1.0 + value
				3: utility += value * 4.0
				4, 5, 6, 7: defense += value * 45.0

	var offense_index: float = clampf(offense / 25.0 * 100.0, 0.0, 250.0)
	var defense_index: float = clampf(defense / 25.0 * 100.0, 0.0, 250.0)
	var utility_index: float = clampf(utility / 18.0 * 100.0, 0.0, 250.0)
	var power: float = offense_index * 0.45 + defense_index * 0.40 + utility_index * 0.15
	return {"offense": offense_index, "defense": defense_index, "utility": utility_index, "power": power, "raw_offense": offense, "raw_defense": defense, "raw_utility": utility}

static func _target_factor(target_type: int) -> float:
	match target_type:
		2: return 1.65
		1, 3: return 0.15
	return 1.0

static func _defense_target_factor(target_type: int) -> float:
	match target_type:
		3: return 1.4
		2: return 0.25
	return 1.0

static func _effects_offense(effects) -> float:
	var result: float = 0.0
	for effect in effects:
		if not effect is Dictionary:
			continue
		var effect_id: String = str(effect.get("id", ""))
		match effect_id:
			"apply_on_fire":
				var duration: float = float(effect.get("duration", 2))
				var damage: float = float(effect.get("damage", 3))
				var factor: float = 1.6 if bool(effect.get("all_enemies", false)) else 1.0
				result += duration * damage * factor
			"apply_status":
				var duration: float = float(effect.get("duration", 1))
				var stacks: float = float(effect.get("stacks", 1))
				var tick_damage: float = float(effect.get("tick_damage", 0))
				var per_stack: float = float(effect.get("damage_per_stack", 0))
				var factor: float = 1.6 if bool(effect.get("all_enemies", false)) else 1.0
				result += duration * (tick_damage + stacks * per_stack) * factor
			"damage_per_status_stack": result += float(effect.get("damage_per_stack", 1)) * 3.0
			"trigger_status": result += 5.0 * (1.6 if bool(effect.get("all_enemies", false)) else 1.0)
	return result

static func _effects_value(effects) -> float:
	var result: float = 0.0
	for effect in effects:
		if not effect is Dictionary:
			continue
		var effect_id: String = str(effect.get("id", ""))
		match effect_id:
			"draw_card": result += 3.0
			"draw_3": result += 8.0
			"gain_charge", "gain_charge_2", "gain_charge_per_hit": result += 2.5
			"spend_all_energy_for_charge": result += 4.0
			"apply_on_fire", "apply_status": result += 5.0
			"trigger_status": result += 6.0
			"damage_per_status_stack": result += 5.0
			"extend_status": result += 3.0
			"gain_build_resource", "gain_resource_per_statused_enemy": result += 2.5
			"clean_debuffs": result += 4.0
			"double_dmg_if_charge_5": result += 4.0
			_: result += 1.5 if not effect_id.is_empty() else 0.0
	return result

static func _empty() -> Dictionary:
	return {"offense": 0.0, "defense": 0.0, "utility": 0.0, "power": 0.0}
