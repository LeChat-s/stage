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

@export var enemy_container: Node2D
@export var enemy_prefab: PackedScene = preload("res://src/battle/enemy_in_battle.tscn")
@export var spawn_positions: Array[Marker2D] = []
@export var enemy_catalog: EnemyCatalog
@export var spell_container_scene: PackedScene = preload("res://src/ui/spell_container.tscn")

var spell_container: Control = null
var enemies: Array[EnemyInBattle] = []
var deck: Array[CardData] = []
var discard_pile: Array[CardData] = []
var current_hand: Array[CardData] = []
var active_infection: String = "none"
var magical_charge: int = 0
var _is_battle_ending: bool = false
var selected_enemy_target: EnemyInBattle
var _starting_hand_prepared: bool = false

func _ready() -> void:
	_setup_battle()
	_start_player_turn()

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

	var class_icon := $UI/ClassIcon
	var spell_container := $UI/SpellConteiner
	var spell_button := $UI/SpellConteiner/SpellButton

	var class_texture_path := "res://assets/icons/class_%s.png" % infection_name
	var spell_texture_path := "res://assets/icons/spell_button_%s.png" % infection_name

	var class_texture := load(class_texture_path) as Texture2D
	var spell_texture := load(spell_texture_path) as Texture2D

	if class_texture:
		class_icon.texture = class_texture
	else:
		push_warning("Не найдена текстура класса: " + class_texture_path)

	if spell_texture:
		spell_button.texture_normal = spell_texture
	else:
		push_warning("Не найдена текстура способности: " + spell_texture_path)

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
