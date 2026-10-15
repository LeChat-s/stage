class_name AbilityExecutor
extends RefCounted

static func execute(ability: AbilityData, battle: Battle, selected_target: Node2D = null) -> bool:
	if ability == null or battle == null or battle.player == null:
		return false

	if ability.resource_cost > 0 and battle.get_active_build_resource() < ability.resource_cost:
		return false
	if not battle.player.spend_energy(ability.energy_cost):
		return false
	if ability.resource_cost > 0:
		battle.spend_active_build_resource(ability.resource_cost)

	var proxy := CardData.new()
	proxy.id = String(ability.id)
	proxy.name = ability.display_name
	proxy.dmg = ability.damage
	proxy.set("damage_type", int(ability.damage_type))
	proxy.shild = ability.block
	proxy.cost = 0
	proxy.set("target_type", int(ability.target_type))
	proxy.effects.clear()
	for effect in ability.effects:
		proxy.effects.append(effect.duplicate(true))

	CardEffectProcessor.process_card(proxy, battle, selected_target)
	return true
