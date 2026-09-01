class_name Battle
extends Node2D

@onready var player: PlayerInBattle = $PlayerInBattle
@onready var enemy: EnemyInBattle = $EnemyInBattle
@onready var hand: Hand = $UI/Hand
@onready var deck_label: Label = $UI/DeckLabel
@onready var discard_label: Label = $UI/DiscardLabel
@onready var end_turn_button: Button = $UI/EndTurnButton

var deck: Array[CardData] = []
var discard_pile: Array[CardData] = []
var current_hand: Array[CardData] = []
var active_infection: String = ""
var magical_charge: int = 0
var _is_battle_ending: bool = false

func _ready() -> void:
	_setup_battle()
	_start_player_turn()

func _setup_battle() -> void:
	player.setup({
		"hp": GameState.player_hp,
		"max_hp": GameState.player_max_hp
	})
	enemy.setup(GameState.current_enemy)
	
	deck = GameState.deck.duplicate()
	deck.shuffle()
	discard_pile.clear()
	current_hand.clear()
	
	end_turn_button.pressed.connect(_on_end_turn)
	hand.card_selected.connect(_on_card_selected)
	player.died.connect(_on_player_died)
	enemy.died.connect(_on_enemy_died)

func _start_player_turn() -> void:
	player.reset_turn()
	_apply_infection_turn_start_effects()
	draw_cards(5)
	_update_pipe_labels()

func _apply_infection_turn_start_effects() -> void:
	match active_infection:
		"inf_magical_girl":
			player.add_energy(1)
			var concentration_res = load("res://src/cards/evt_concentration.tres") as CardData
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
		
	CardEffectProcessor.process_card(card_data, self)
	current_hand.erase(card_data)
	
	if card_data.has_effect("exile_on_turn_end") or card_data.id == "evt_concentration":
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
		if card.has_effect("exile_on_turn_end") or card.id == "evt_concentration":
			card.queue_free()
		else:
			cards_to_discard.append(card)
			
	discard_pile.append_array(cards_to_discard)
	current_hand.clear()
	hand.clear_hand()
	
	var action = enemy.get_next_action()
	var block_before_hit = player.block
	
	enemy.execute_action(action, player)
	
	if active_infection == "inf_magical_girl" and block_before_hit > 0 and player.block == 0:
		magical_charge += 2
		print("Барьер сломан! Получено +2 заряда.")
	
	if player.hp > 0:
		_start_player_turn()

func _on_player_died() -> void:
	print("игрок мертв") 
	get_tree().change_scene_to_file("res://src/world/test_lvl.tscn")

func _on_enemy_died() -> void:
	if _is_battle_ending:
		return
	_is_battle_ending = true
	print("враг мертв") 
	if GameState.current_enemy:
		GameState.mark_enemy_detected(GameState.current_enemy.id)
	await get_tree().create_timer(1.0).timeout
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.change_scene_to_file("res://src/world/test_lvl.tscn")
	else:
		print("Ошибка: Не удалось получить доступ к SceneTree для смены сцены")
func _update_pipe_labels() -> void:
	deck_label.text = "Колода: " + str(deck.size())
	discard_label.text = "Сброс: " + str(discard_pile.size())
