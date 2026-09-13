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

var spell_container: Control = null
var enemies: Array[EnemyInBattle] = []
var deck: Array[CardData] = []
var discard_pile: Array[CardData] = []
var current_hand: Array[CardData] = []
var active_infection: String = "none"
var magical_charge: int = 0
var _is_battle_ending: bool = false
var selected_enemy_target: Node2D = null
var _starting_hand_prepared: bool = false
var current_target: Node2D = null
var fireblast_cooldown: int = 0
var is_fireblast_upgraded: bool = false
var is_shield_upgraded: bool = false

func _ready() -> void:
	_setup_battle()
	_start_player_turn()
	if player:
		player.energy_changed.connect(update_energy_display)
		update_energy_display(player.energy)

func _setup_battle() -> void:
	GameState.active_contamination = "none"
	active_infection = "none"
	
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

func _spawn_enemies_from_state() -> void:
	for e in enemies:
		if is_instance_valid(e): e.queue_free()
	enemies.clear()
	var enemy_datas = GameState.current_enemies 
	for i in range(enemy_datas.size()):
		if i >= spawn_positions.size():
			print("Предупреждение: Не хватает Marker2D для спавна врага!")
			break
			
		var enemy_instance = enemy_prefab.instantiate() as EnemyInBattle
		enemy_container.add_child(enemy_instance)
		enemy_instance.global_position = spawn_positions[i].global_position
		
		print("Враг ", i, " заспавнен на маркере '", spawn_positions[i].name, "' с позицией: ", enemy_instance.global_position)
		
		enemy_instance.setup(enemy_datas[i])
		enemy_instance.died.connect(_on_enemy_died.bind(enemy_instance))
		
		if i == 0:
			selected_enemy_target = enemy_instance
		enemies.append(enemy_instance)

func summon_minion(minion_id: int) -> void:
	var free_marker_index: int = -1
	for i in range(spawn_positions.size()):
		var is_occupied = false
		for enemy in enemies:
			if is_instance_valid(enemy):
				if enemy.has_meta("spawn_marker_index") and enemy.get_meta("spawn_marker_index") == i:
					is_occupied = true
					break
				elif enemy.global_position.distance_to(spawn_positions[i].global_position) < 10.0:
					is_occupied = true
					break
		if not is_occupied:
			free_marker_index = i
			break
			
	if free_marker_index == -1:
		print("Не удалось призвать миньона: все маркеры заняты!")
		return
	var minion_data: EnemyData = _get_minion_data_by_id(minion_id)
	if not minion_data:
		print("Ошибка: Не найдены EnemyData для миньона с ID: ", minion_id)
		return
		
	var minion_instance = enemy_prefab.instantiate() as EnemyInBattle
	var target_marker = spawn_positions[free_marker_index]
	minion_instance.global_position = target_marker.global_position
	minion_instance.set_meta("spawn_marker_index", free_marker_index)
	enemy_container.add_child(minion_instance)
	minion_instance.setup(minion_data)
	minion_instance.died.connect(_on_enemy_died.bind(minion_instance))
	enemies.append(minion_instance)
	print("Миньон успешно призван на маркер: ", target_marker.name, " (Индекс: ", free_marker_index, ")")

func _get_minion_data_by_id(id: int) -> EnemyData:
	if enemy_catalog:
		return enemy_catalog.get_enemy_data(id)
	print("enemy_catalog отсутствует")
	return null

func select_new_target(new_target: Node2D) -> void:
	if not is_instance_valid(new_target):
		return
	var actual_creature: Node2D = new_target
	while is_instance_valid(actual_creature) and not actual_creature.has_method("take_damage") and actual_creature.get_parent() is Node2D:
		actual_creature = actual_creature.get_parent() as Node2D
	if is_instance_valid(actual_creature) and actual_creature.has_method("take_damage"):
		if current_target == actual_creature:
			return
		if is_instance_valid(current_target) and current_target.has_method("set_highlight"):
			current_target.set_highlight(false)
		current_target = actual_creature
		selected_enemy_target = actual_creature
		if current_target.has_method("set_highlight"):
			current_target.set_highlight(true)
			
		print("УСПЕШНО выбрана цель существа: ", current_target.name, " [Класс: ", current_target.get_script().get_global_name(), "]")

func _start_player_turn() -> void:
	player.reset_turn()
	draw_cards(5)

	if not _starting_hand_prepared:
		_ensure_infection_cards_in_hand()
		_starting_hand_prepared = true

	_update_pipe_labels()

func _is_infection_card(card: CardData) -> bool:
	if card == null:
		return false
	return card.resource_path.get_file().get_basename().begins_with("con_")

func _ensure_infection_cards_in_hand() -> void:
	for card in deck.duplicate():
		if _is_infection_card(card):
			deck.erase(card)
			current_hand.append(card)
			hand.add_card(card)

func _add_card_to_hand_directly(card_data: CardData) -> void:
	current_hand.append(card_data)
	hand.add_card(card_data)

func draw_cards(amount: int) -> void:
	for i in range(amount):
		if deck.is_empty():
			_reshuffle_discard()
		if deck.is_empty():
			break
		var card = deck.pop_front()
		current_hand.append(card)
		hand.add_card(card)

func _reshuffle_discard() -> void:
	deck = discard_pile.duplicate()
	discard_pile.clear()
	deck.shuffle()

func _on_card_selected(card_data: CardData) -> void:
	var real_cost = CardEffectProcessor.calculate_dynamic_card_cost(card_data, self)
	if not player.spend_energy(real_cost):
		return
	
	var is_infection := _is_infection_card(card_data)
	
	CardEffectProcessor.process_card(card_data, self, selected_enemy_target)
	current_hand.erase(card_data)
	
	if card_data.has_effect("exile_on_turn_end"):
		card_data.queue_free()
	else:
		discard_pile.append(card_data)
	
	if is_infection:
		var file_name := card_data.resource_path.get_file().get_basename()
		var infection_name := file_name.trim_prefix("con_")

		active_infection = infection_name
		GameState.active_contamination = infection_name
		print("[СМЕНА ФОРМЫ] Глобальное заражение изменено на: ", GameState.active_contamination)
		
		_update_infection_ui(card_data)
		_remove_all_infection_cards()
	
	_refresh_hand()
	_update_pipe_labels()

func _update_infection_ui(card_data: CardData) -> void:
	var file_name := card_data.resource_path.get_file().get_basename()
	var infection_name := file_name.trim_prefix("con_")
	var class_icon := $UI/Class/ClassIcon
	var spell_container := $UI/Class/SpellConteiner
	var class_texture_path := "res://assets/icons/class_%s.png" % infection_name
	var class_texture := load(class_texture_path) as Texture2D

	if class_texture:
		class_icon.texture = class_texture
	else:
		push_warning("Не найдена текстура класса: " + class_texture_path)
	var suffixes := ["A", "B", "C"]
	for suffix in suffixes:
		var button_name: String = "SpellButton" + suffix
		var spell_button := spell_container.get_node_or_null(button_name) as TextureButton
		
		if spell_button:
			var spell_texture_path := "res://assets/icons/spell_button_%s_%s.png" % [infection_name, suffix.to_lower()]
			var spell_texture := load(spell_texture_path) as Texture2D

			if spell_texture:
				spell_button.texture_normal = spell_texture
			else:
				push_warning("Не найдена текстура способности для %s: %s" % [button_name, spell_texture_path])
		else:
			push_warning("Узел %s не найден в %s" % [button_name, spell_container.name])

	class_icon.visible = true
	spell_container.visible = true


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

func _refresh_hand() -> void:
	hand.clear_hand()
	for card in current_hand:
		hand.add_card(card)

func _on_end_turn() -> void:
	var cards_to_discard: Array[CardData] = [] 
	for card in current_hand:
		if card.has_effect("exile_on_turn_end"):
			card.queue_free()
		else:
			cards_to_discard.append(card)
			
	discard_pile.append_array(cards_to_discard)
	current_hand.clear()
	hand.clear_hand()
	
	var current_enemies = enemies.duplicate()
	for current_enemy in current_enemies:
		if not is_instance_valid(current_enemy) or current_enemy.hp <= 0:
			continue
			
		var action = current_enemy.get_next_action()
		current_enemy.execute_action(action, player)
		if player.hp <= 0:
			break
	
	if player.hp > 0:
		_start_player_turn()

func _on_player_died() -> void:
	print("игрок мертв") 
	GameState.active_contamination = "none"
	get_tree().change_scene_to_file("res://src/world/prologue.tscn")

func _on_enemy_died(dead_enemy: EnemyInBattle) -> void:
	print("Враг умер: ", dead_enemy.name)
	
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
	if fireblast_cooldown > 0:
		print("Способность на перезарядке! Осталось ходов: ", fireblast_cooldown)
		return
		
	var battle_scene = get_tree().current_scene as Battle
	if not battle_scene or not is_instance_valid(battle_scene.player): return

	battle_scene.player.play_attack()

	if not is_fireblast_upgraded:
		print("Применен Fireblast!")
		for enemy in battle_scene.enemies:
			if is_instance_valid(enemy) and enemy.hp > 0:
				enemy.take_damage(5, "fireblast")
				if enemy.has_method("apply_debuff"):
					enemy.apply_debuff("on_fire", 2)
		fireblast_cooldown = 3
	else:
		if not battle_scene.player.spend_energy(3):
			print("Недостаточно энергии для Fireball (нужно 3)!")
			return
			
		print("Применен Улучшенный Fireball!")
		for enemy in battle_scene.enemies:
			if is_instance_valid(enemy) and enemy.hp > 0:
				enemy.take_damage(20, "fireball")
				if enemy.has_method("apply_debuff"):
					enemy.apply_debuff("on_fire", 2)
		
		is_fireblast_upgraded = false 
	_on_end_turn()

func _on_spell_button_b_pressed() -> void:
	var battle_scene = get_tree().current_scene as Battle
	if not battle_scene or not is_instance_valid(battle_scene.current_target):
		print("Выберите цель (себя или союзника) для наложения щита!")
		return
		
	var target = battle_scene.current_target
	if not target.has_method("apply_buff"):
		print("Эта цель не может принимать баффы!")
		return

	if is_shield_upgraded:
		if not battle_scene.player.spend_energy(5):
			print("Недостаточно энергии для Улучшенного щита (нужно 5)!")
			return
			
		target.apply_buff("shield_lvl_3", 2)
		if target.has_node("ShieldComponent") or "shield_charges" in target:
			target.shield_charges = 2 # Защищает на 2 атаки
		is_shield_upgraded = false # Сбрасываем бафф утилиты
	else:
		# Обычный щит: прокачивает уровни (стакается)
		if target.has_method("get_buff_level"):
			var current_lvl = target.get_buff_level("shield") # Функция проверки текущего лвла щита
			var next_lvl = min(current_lvl + 1, 3)
			target.apply_buff("shield_lvl_" + str(next_lvl), 2) # Накладываем/обновляем до 2 ходов
		else:
			# Если системы уровней еще нет, просто даем 1 уровень
			target.apply_buff("shield_lvl_1", 2)

	_on_end_turn()

func _on_spell_button_c_pressed() -> void:
	if utility_choice_panel:
		utility_choice_panel.visible = true
		print("Открыто меню выбора Utility навыков")
