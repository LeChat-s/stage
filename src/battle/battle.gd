class_name Battle
extends Node2D

@onready var player: PlayerInBattle = $PlayerInBattle
@onready var hand: Hand = $UI/Hand
@onready var deck_label: Label = $UI/DeckLabel
@onready var discard_label: Label = $UI/DiscardLabel
@onready var end_turn_button: Button = $UI/EndTurnButton

@export var enemy_container: Node2D
@export var enemy_prefab: PackedScene = preload("res://src/battle/enemy_in_battle.tscn")
@export var spawn_positions: Array[Marker2D] = []

var enemies: Array[EnemyInBattle] = []
var deck: Array[CardData] = []
var discard_pile: Array[CardData] = []
var current_hand: Array[CardData] = []
var active_infection: String = ""
var magical_charge: int = 0
var _is_battle_ending: bool = false
var selected_enemy_target: EnemyInBattle

func _ready() -> void:
	_setup_battle()
	_start_player_turn()

func _setup_battle() -> void:
	player.setup({
		"hp": GameState.player_hp,
		"max_hp": GameState.player_max_hp
	})
	_spawn_enemies_from_state()
	
	deck = GameState.deck.duplicate()
	deck.shuffle()
	discard_pile.clear()
	current_hand.clear()
	
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

func _start_player_turn() -> void:
	player.reset_turn()
	_apply_infection_turn_start_effects()
	draw_cards(5)
	_update_pipe_labels()

func _apply_infection_turn_start_effects() -> void:
	match active_infection:
		"inf_magical_girl":
			player.add_energy(1)
			var concentration_res = load("res://src/data/cards/evt_concentration.tres") as CardData
			if concentration_res:
				_add_card_to_hand_directly(concentration_res.duplicate())

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
		
	CardEffectProcessor.process_card(card_data, self, selected_enemy_target)
	current_hand.erase(card_data)
	
	if card_data.has_effect("exile_on_turn_end"):
		card_data.queue_free()
	else:
		discard_pile.append(card_data)
		
	_refresh_hand()
	_update_pipe_labels()


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
	
	for current_enemy in enemies:
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
	get_tree().change_scene_to_file("res://src/world/test_lvl.tscn")

func _on_enemy_died(dead_enemy: EnemyInBattle) -> void:
	print("Враг умер: ", dead_enemy.name)
	enemies.erase(dead_enemy)
	if selected_enemy_target == dead_enemy:
		if not enemies.is_empty():
			selected_enemy_target = enemies[0]
		else:
			selected_enemy_target = null
	if enemies.is_empty():
		_check_battle_victory()

func _check_battle_victory() -> void:
	if _is_battle_ending:
		return
	_is_battle_ending = true
	print("Все враги мертвы") 
	
	if GameState.current_enemy_node_name != "":
		GameState.mark_enemy_detected(GameState.current_enemy_node_name)
		
	await get_tree().create_timer(1.0).timeout
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.change_scene_to_file("res://src/world/test_lvl.tscn")
	else:
		print("Ошибка: Не удалось получить доступ к SceneTree для смены сцены")

func _update_pipe_labels() -> void:
	deck_label.text = "Колода: " + str(deck.size())
	discard_label.text = "Сброс: " + str(discard_pile.size())

func highlight_targets_for_type(target_type: CardData.TargetType) -> void:
	clear_all_highlights()
	
	match target_type:
		CardData.TargetType.SELF:
			player.set_highlight(true)
			
		CardData.TargetType.ALL_ENEMIES:
			for e in enemies:
				if is_instance_valid(e) and e.hp > 0:
					e.set_highlight(true)
					
		CardData.TargetType.ALL_HEROES:
			player.set_highlight(true)
			for e in enemies:
				if is_instance_valid(e) and e.hp > 0:
					e.set_highlight(true)
					
		CardData.TargetType.ENEMY:
			if is_instance_valid(selected_enemy_target):
				selected_enemy_target.set_highlight(true)

func clear_all_highlights() -> void:
	player.set_highlight(false)
	for e in enemies:
		if is_instance_valid(e):
			e.set_highlight(false)

func select_new_target(new_target: EnemyInBattle) -> void:
	if not is_instance_valid(new_target) or new_target.hp <= 0:
		return
	selected_enemy_target = new_target
	print("Игрок выбрал новую цель: ", new_target.name)
	clear_all_highlights()
	selected_enemy_target.set_highlight(true)
