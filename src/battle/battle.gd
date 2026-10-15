class_name Battle
extends Node2D

@onready var player: PlayerInBattle = $PlayerInBattle
@onready var hand: Hand = $UI/Hand
@onready var end_turn_button: Button = $UI/EndTurnButton
@onready var deck_button: TextureButton = $UI/DeckButton
@onready var discard_button: TextureButton = $UI/DiscardButton
@onready var inspector_panel: PanelContainer = $UI/CardInspector
@onready var deck_count_label: Label = $UI/DeckButton/CountLabel
@onready var discard_count_label: Label = $UI/DiscardButton/CountLabel
@onready var energy_text: Label = $UI/Class/Energy/EnergyLabel
@onready var utility_choice_panel: Control = $UI/UtilityChoicePanel

@export var enemy_container: Node2D
@export var enemy_prefab: PackedScene = preload("res://src/battle/enemy_in_battle.tscn")
@export var spawn_positions: Array[Marker2D] = []
@export var enemy_catalog: EnemyCatalog

var enemies: Array[EnemyInBattle] = []
var deck: Array[CardData] = []
var discard_pile: Array[CardData] = []
var current_hand: Array[CardData] = []

var active_infection: String = "none"
var active_build: ContaminationData = null
var build_resources: Dictionary = {}
var magical_charge: int:
	get:
		return get_build_resource(&"magical_charge")
	set(value):
		set_build_resource(&"magical_charge", value)
var selected_enemy_target: Node2D = null
var current_target: Node2D = null

var fireblast_cooldown: int = 0
var ability_cooldowns: Dictionary = {}
var is_fireblast_upgraded: bool = false
var is_shield_upgraded: bool = false
var block_break_charge_reward: int = 0

var _is_battle_ending: bool = false
var _turn_locked: bool = false
var _starting_hand_prepared: bool = false

func _ready() -> void:
	_setup_battle()
	_start_player_turn()
	player.energy_changed.connect(update_energy_display)
	update_energy_display(player.energy)

func _setup_battle() -> void:
	GameState.active_contamination = "none"
	GameState.active_contamination_data = null
	active_infection = "none"
	active_build = null
	build_resources.clear()
	magical_charge = 0

	player.setup({
		"hp": GameState.player_hp,
		"max_hp": GameState.player_max_hp
	})
	_spawn_enemies_from_state()

	deck = GameState.deck.duplicate()
	deck.shuffle()
	discard_pile.clear()
	current_hand.clear()
	_starting_hand_prepared = false

	end_turn_button.pressed.connect(_on_end_turn)
	hand.card_selected.connect(_on_card_selected)
	player.died.connect(_on_player_died)
	player.block_broken.connect(_on_player_block_broken)

func _spawn_enemies_from_state() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()

	var enemy_datas: Array[EnemyData] = GameState.current_enemies
	for i in range(enemy_datas.size()):
		if i >= spawn_positions.size():
			push_warning("Battle: не хватает Marker2D для спавна врагов.")
			break

		var enemy_instance := enemy_prefab.instantiate() as EnemyInBattle
		enemy_container.add_child(enemy_instance)
		enemy_instance.global_position = spawn_positions[i].global_position
		enemy_instance.set_meta("spawn_marker_index", i)
		enemy_instance.setup(enemy_datas[i])
		enemy_instance.died.connect(_on_enemy_died.bind(enemy_instance))
		enemies.append(enemy_instance)

		if selected_enemy_target == null:
			selected_enemy_target = enemy_instance

func summon_minion(minion_id: int) -> void:
	var free_marker_index: int = -1
	for i in range(spawn_positions.size()):
		var is_occupied: bool = false
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.hp <= 0:
				continue
			if enemy.has_meta("spawn_marker_index") and int(enemy.get_meta("spawn_marker_index")) == i:
				is_occupied = true
				break
			if enemy.global_position.distance_to(spawn_positions[i].global_position) < 10.0:
				is_occupied = true
				break
		if not is_occupied:
			free_marker_index = i
			break

	if free_marker_index == -1:
		push_warning("Battle: все точки призыва заняты.")
		return

	var minion_data: EnemyData = _get_minion_data_by_id(minion_id)
	if minion_data == null:
		return

	var minion_instance := enemy_prefab.instantiate() as EnemyInBattle
	var target_marker: Marker2D = spawn_positions[free_marker_index]
	enemy_container.add_child(minion_instance)
	minion_instance.global_position = target_marker.global_position
	minion_instance.set_meta("spawn_marker_index", free_marker_index)
	minion_instance.setup(minion_data)
	minion_instance.died.connect(_on_enemy_died.bind(minion_instance))
	enemies.append(minion_instance)

func _get_minion_data_by_id(id: int) -> EnemyData:
	if enemy_catalog:
		return enemy_catalog.get_enemy_data(id)
	push_warning("Battle: enemy_catalog не назначен.")
	return null

func select_new_target(new_target: Node2D) -> void:
	if not is_instance_valid(new_target):
		return

	var actual_creature: Node2D = new_target
	while (
		is_instance_valid(actual_creature)
		and not actual_creature.has_method("take_damage")
		and actual_creature.get_parent() is Node2D
	):
		actual_creature = actual_creature.get_parent() as Node2D

	if not is_instance_valid(actual_creature) or not actual_creature.has_method("take_damage"):
		return
	if current_target == actual_creature:
		return

	if is_instance_valid(current_target) and current_target.has_method("set_highlight"):
		current_target.set_highlight(false)

	current_target = actual_creature
	if actual_creature is EnemyInBattle:
		selected_enemy_target = actual_creature
	if current_target.has_method("set_highlight"):
		current_target.set_highlight(true)

func _start_player_turn() -> void:
	if _is_battle_ending:
		return

	_turn_locked = false
	end_turn_button.disabled = false
	# Если блок пережил вражеский ход, триггер Barrier сгорает вместе с блоком.
	block_break_charge_reward = 0
	_tick_cooldowns()
	player.reset_turn()
	draw_cards(5)

	if not _starting_hand_prepared:
		_ensure_infection_cards_in_hand()
		_starting_hand_prepared = true

	_update_pipe_labels()

func _tick_cooldowns() -> void:
	fireblast_cooldown = maxi(0, fireblast_cooldown - 1)
	for ability_id in ability_cooldowns.keys():
		ability_cooldowns[ability_id] = maxi(0, int(ability_cooldowns[ability_id]) - 1)

func _is_infection_card(card: CardData) -> bool:
	if card == null:
		return false
	if card.type == "infection" or card.contamination != null:
		return true
	return card.resource_path.get_file().get_basename().begins_with("con_")

func _ensure_infection_cards_in_hand() -> void:
	for card in deck.duplicate():
		if _is_infection_card(card):
			deck.erase(card)
			_add_card_to_hand_directly(card)

func _add_card_to_hand_directly(card_data: CardData) -> void:
	current_hand.append(card_data)
	hand.add_card(card_data)

func draw_cards(amount: int) -> void:
	for _i in range(amount):
		if deck.is_empty():
			_reshuffle_discard()
		if deck.is_empty():
			break
		var card: CardData = deck.pop_front()
		current_hand.append(card)
		hand.add_card(card)

func _reshuffle_discard() -> void:
	deck = discard_pile.duplicate()
	discard_pile.clear()
	deck.shuffle()

func _on_card_selected(card_data: CardData) -> void:
	if _turn_locked or _is_battle_ending or card_data == null:
		return

	var real_cost: int = CardEffectProcessor.calculate_dynamic_card_cost(card_data, self)
	if not player.spend_energy(real_cost):
		return

	var is_infection: bool = _is_infection_card(card_data)
	CardEffectProcessor.process_card(card_data, self, selected_enemy_target)
	current_hand.erase(card_data)

	if card_data.has_effect("exile_on_turn_end"):
		# Resource из проекта нельзя queue_free; он просто не попадает в discard.
		pass
	else:
		discard_pile.append(card_data)

	if is_infection:
		_activate_contamination(card_data)

	_refresh_hand()
	_update_pipe_labels()

func _activate_contamination(card_data: CardData) -> void:
	var infection_name: String = ""
	active_build = card_data.contamination

	# Infection-карта хранит стабильный build_id. Прямая ссылка на ресурс опциональна:
	# так отсутствующая иконка/спрайт не может убрать саму карту из колоды.
	if active_build == null and card_data.build_id != &"":
		active_build = GameState.get_build_data(String(card_data.build_id))

	if active_build != null:
		infection_name = String(active_build.id)
		GameState.active_contamination_data = active_build
	elif card_data.build_id != &"":
		infection_name = GameState.normalize_build_id(String(card_data.build_id))
		GameState.active_contamination_data = null
	else:
		infection_name = GameState.normalize_build_id(card_data.resource_path.get_file().get_basename().trim_prefix("con_"))
		GameState.active_contamination_data = null

	active_infection = infection_name
	GameState.active_contamination = infection_name
	if active_build != null:
		_initialize_build_resource(active_build)
		player.apply_contamination_build(active_build)
	else:
		player.set_magical_girl_form(infection_name == "magical_girl")
	if player.effects_ui != null:
		player.effects_ui.clear_all()
	_update_infection_ui(card_data)
	_remove_all_infection_cards()
	if active_build != null:
		_apply_build_card_package(active_build)
	_update_build_resource_ui()

func _update_infection_ui(card_data: CardData) -> void:
	var infection_name: String = active_infection
	var class_icon := $UI/Class/ClassIcon as TextureRect
	var spell_container := $UI/Class/SpellConteiner

	if active_build != null and active_build.icon != null:
		class_icon.texture = active_build.icon
	else:
		var class_texture := _load_texture_if_exists("res://assets/icons/class_%s.png" % infection_name)
		if class_texture != null:
			class_icon.texture = class_texture

	var buttons: Array[TextureButton] = []
	buttons.append($UI/Class/SpellConteiner/SpellButtonA as TextureButton)
	buttons.append($UI/Class/SpellConteiner/SpellButtonB as TextureButton)
	buttons.append($UI/Class/SpellConteiner/SpellButtonC as TextureButton)
	var suffixes: Array[String] = ["a", "b", "c"]

	for i in range(buttons.size()):
		var texture: Texture2D = null
		if active_build != null:
			var ability: AbilityData = active_build.get_ability(i)
			if ability != null:
				texture = ability.icon
		if texture == null:
			texture = _load_texture_if_exists("res://assets/icons/spell_button_%s_%s.png" % [infection_name, suffixes[i]])
		if texture != null:
			buttons[i].texture_normal = texture

	class_icon.visible = true
	spell_container.visible = true
	# UtilityChoicePanel относится к старому utility Magical Girl. Для data-driven
	# билдов способность C исполняется напрямую через AbilityData.
	if infection_name == "magical_girl" and utility_choice_panel and utility_choice_panel.has_method("set_spells"):
		utility_choice_panel.set_spells(infection_name)

func _load_texture_if_exists(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _remove_all_infection_cards() -> void:
	for i in range(current_hand.size() - 1, -1, -1):
		if _is_infection_card(current_hand[i]):
			current_hand.remove_at(i)
	for i in range(deck.size() - 1, -1, -1):
		if _is_infection_card(deck[i]):
			deck.remove_at(i)
	for i in range(discard_pile.size() - 1, -1, -1):
		if _is_infection_card(discard_pile[i]):
			discard_pile.remove_at(i)

func _card_build_id(card: CardData) -> StringName:
	if card == null:
		return &""
	if card.build_id != &"":
		return card.build_id
	if card.contamination != null:
		return card.contamination.id
	return &""

func _apply_build_card_package(build: ContaminationData) -> void:
	if build == null:
		return
	var build_id: StringName = build.id
	for pile in [current_hand, deck, discard_pile]:
		for i in range(pile.size() - 1, -1, -1):
			var card: CardData = pile[i]
			var owner: StringName = _card_build_id(card)
			if owner != &"" and owner != build_id and not _is_infection_card(card):
				pile.remove_at(i)

	var present_ids: Dictionary = {}
	for pile in [current_hand, deck, discard_pile]:
		for card in pile:
			if card != null:
				present_ids[card.id] = true

	for resource in build.starting_cards:
		var card := resource as CardData
		if card == null or present_ids.has(card.id):
			continue
		deck.append(card)
		present_ids[card.id] = true
	deck.shuffle()
	var missing_cards: int = maxi(0, 5 - current_hand.size())
	if missing_cards > 0:
		draw_cards(missing_cards)

func _initialize_build_resource(build: ContaminationData) -> void:
	if build == null or build.resource_id == &"":
		return
	if not build_resources.has(build.resource_id):
		build_resources[build.resource_id] = clampi(build.resource_start, 0, maxi(build.resource_max, 0))

func get_build_resource(resource_id: StringName) -> int:
	if resource_id == &"":
		return 0
	return int(build_resources.get(resource_id, 0))

func set_build_resource(resource_id: StringName, value: int) -> void:
	if resource_id == &"":
		return
	var maximum: int = 999
	if active_build != null and active_build.resource_id == resource_id:
		maximum = maxi(active_build.resource_max, 0)
	build_resources[resource_id] = clampi(value, 0, maximum)

func add_build_resource(resource_id: StringName, amount: int) -> int:
	set_build_resource(resource_id, get_build_resource(resource_id) + amount)
	_update_build_resource_ui()
	return get_build_resource(resource_id)

func spend_build_resource(resource_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	var current: int = get_build_resource(resource_id)
	if current < amount:
		return false
	set_build_resource(resource_id, current - amount)
	_update_build_resource_ui()
	return true

func get_active_build_resource() -> int:
	if active_build == null:
		return 0
	return get_build_resource(active_build.resource_id)

func add_active_build_resource(amount: int) -> int:
	if active_build == null:
		return 0
	return add_build_resource(active_build.resource_id, amount)

func spend_active_build_resource(amount: int) -> bool:
	if active_build == null:
		return amount <= 0
	return spend_build_resource(active_build.resource_id, amount)

func _update_build_resource_ui() -> void:
	if active_build == null or active_build.resource_id == &"" or player.effects_ui == null:
		return
	var texture: Texture2D = active_build.resource_icon
	if texture == null and active_build.resource_id == &"magical_charge":
		var info: Dictionary = CardEffectProcessor.effect_registry.get("gain_charge", {})
		texture = info.get("icon", null)
	if texture != null:
		player.effects_ui.update_effect(String(active_build.resource_id), get_active_build_resource(), texture)

func _refresh_hand() -> void:
	hand.clear_hand()
	for card in current_hand:
		hand.add_card(card)

func _on_end_turn() -> void:
	if _turn_locked or _is_battle_ending:
		return

	_turn_locked = true
	end_turn_button.disabled = true

	var cards_to_discard: Array[CardData] = []
	for card in current_hand:
		if not card.has_effect("exile_on_turn_end"):
			cards_to_discard.append(card)
	discard_pile.append_array(cards_to_discard)
	current_hand.clear()
	hand.clear_hand()
	player.tick_end_turn_statuses()

	var current_enemies: Array[EnemyInBattle] = enemies.duplicate()
	for current_enemy in current_enemies:
		if _is_battle_ending:
			return
		if not is_instance_valid(current_enemy) or current_enemy.hp <= 0:
			continue

		await current_enemy.process_turn_start_statuses()
		if _is_battle_ending or not is_instance_valid(current_enemy) or current_enemy.hp <= 0:
			continue

		var action: String = current_enemy.get_next_action()
		current_enemy.execute_action(action, player)
		current_enemy.tick_statuses_end_turn()

		if player.hp <= 0:
			return

	if not _is_battle_ending and player.hp > 0:
		_start_player_turn()

func _on_player_died() -> void:
	if _is_battle_ending:
		return
	_is_battle_ending = true
	GameState.active_contamination = "none"
	GameState.active_contamination_data = null
	get_tree().change_scene_to_file("res://src/world/prologue.tscn")

func _on_enemy_died(dead_enemy: EnemyInBattle) -> void:
	if is_instance_valid(dead_enemy):
		enemies.erase(dead_enemy)
	if selected_enemy_target == dead_enemy:
		selected_enemy_target = _get_first_alive_enemy()
	if current_target == dead_enemy:
		current_target = null
	call_deferred("_check_victory")

func _get_first_alive_enemy() -> EnemyInBattle:
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.hp > 0:
			return enemy
	return null

func _check_victory() -> void:
	if _is_battle_ending:
		return
	if _get_first_alive_enemy() != null:
		return
	_finish_battle_victory()

func _finish_battle_victory() -> void:
	if _is_battle_ending:
		return
	_is_battle_ending = true
	_turn_locked = true
	end_turn_button.disabled = true

	if not GameState.current_enemy_node_name.is_empty():
		GameState.mark_enemy_detected(GameState.current_enemy_node_name)

	GameState.current_enemies.clear()
	GameState.player_hp = mini(GameState.player_hp, GameState.player_max_hp)
	GameState.active_contamination = "none"
	GameState.active_contamination_data = null

	var return_scene: String = GameState.battle_return_scene_path
	if return_scene.is_empty():
		return_scene = "res://src/world/prologue.tscn"
	get_tree().change_scene_to_file(return_scene)

func arm_charge_on_block_break(amount: int) -> void:
	block_break_charge_reward = maxi(amount, 0)

func _on_player_block_broken() -> void:
	if block_break_charge_reward <= 0:
		return
	magical_charge += block_break_charge_reward
	block_break_charge_reward = 0
	_update_charge_icon()

func _update_charge_icon() -> void:
	_update_build_resource_ui()

func _update_pipe_labels() -> void:
	if deck_count_label:
		deck_count_label.text = str(deck.size())
	if discard_count_label:
		discard_count_label.text = str(discard_pile.size())

func update_energy_display(amount: int) -> void:
	if energy_text:
		energy_text.text = str(amount)

func _on_deck_button_pressed() -> void:
	if deck.size() > 0:
		inspector_panel.open("Содержимое колоды", deck)
	else:
		inspector_panel.hide()

func _on_discard_button_pressed() -> void:
	if discard_pile.size() > 0:
		inspector_panel.open("Стопка сброса", discard_pile)
	else:
		inspector_panel.hide()

func _on_spell_button_a_pressed() -> void:
	if active_infection != "magical_girl":
		_use_build_ability(0)
		return
	if fireblast_cooldown > 0:
		print("Fireblast: перезарядка, осталось ходов: ", fireblast_cooldown)
		return

	player.play_attack()
	var damage_multiplier: float = player.get_outgoing_damage_multiplier()
	if not is_fireblast_upgraded:
		var fireblast_damage: int = maxi(0, roundi(5.0 * damage_multiplier))
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.hp > 0:
				enemy.take_damage(fireblast_damage, "fireblast", GameStateClass.DamageType.MAGIC)
				enemy.apply_debuff("on_fire", 2, 3)
		fireblast_cooldown = 3
	else:
		if not player.spend_energy(3):
			return
		var fireball_damage: int = maxi(0, roundi(20.0 * damage_multiplier))
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.hp > 0:
				enemy.take_damage(fireball_damage, "fireball", GameStateClass.DamageType.MAGIC)
				enemy.apply_debuff("on_fire", 2, 3)
		is_fireblast_upgraded = false
		fireblast_cooldown = 3

	_on_end_turn()

func _on_spell_button_b_pressed() -> void:
	if active_infection != "magical_girl":
		_use_build_ability(1)
		return

	var target: Node2D = current_target if is_instance_valid(current_target) else player
	if not target.has_method("apply_buff"):
		return

	if is_shield_upgraded:
		if not player.spend_energy(5):
			return
		target.apply_buff("shield_lvl_3", 2)
		if target.has_method("set_buff_charges"):
			target.set_buff_charges("shield", 2)
		is_shield_upgraded = false
	else:
		var current_lvl: int = 0
		if target.has_method("get_buff_level"):
			current_lvl = target.get_buff_level("shield")
		var next_lvl: int = mini(current_lvl + 1, 3)
		target.apply_buff("shield_lvl_%d" % next_lvl, 2)

	_on_end_turn()

func _on_spell_button_c_pressed() -> void:
	if active_infection != "magical_girl":
		_use_build_ability(2)
		return
	if utility_choice_panel:
		utility_choice_panel.visible = true

func _use_build_ability(index: int) -> void:
	if active_build == null:
		return
	var ability: AbilityData = active_build.get_ability(index)
	if ability == null:
		return
	var cooldown_left: int = int(ability_cooldowns.get(ability.id, 0))
	if cooldown_left > 0:
		print(ability.display_name, ": перезарядка ", cooldown_left)
		return
	if not AbilityExecutor.execute(ability, self, current_target):
		return
	ability_cooldowns[ability.id] = ability.cooldown
	if ability.consumes_turn:
		_on_end_turn()
