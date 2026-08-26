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
	_draw_cards(5)
	_update_pipe_labels()

func _draw_cards(amount: int) -> void:
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
	if not player.spend_energy(card_data.cost):
		return
	_apply_card_effect(card_data)
	current_hand.erase(card_data)
	discard_pile.append(card_data)
	_refresh_hand()
	_update_pipe_labels()

func _refresh_hand() -> void:
	hand.clear_hand()
	for card in current_hand:
		hand.add_card(card)

func _apply_card_effect(card_data: CardData) -> void:
	if card_data.dmg > 0:
		player.play_attack()
		enemy.take_damage(card_data.dmg)
	if card_data.shild > 0:
		player.add_block(card_data.shild)

func _on_end_turn() -> void:
	discard_pile.append_array(current_hand)
	current_hand.clear()
	hand.clear_hand()
	
	var action = enemy.get_next_action()
	enemy.execute_action(action, player)
	
	if player.hp > 0:
		_start_player_turn()

func _on_player_died() -> void:
	print("игрок мертв") 
	get_tree().change_scene_to_file("res://src/world/test_lvl.tscn")

func _on_enemy_died() -> void:
	print("враг мертв") 
	if GameState.current_enemy:
		GameState.mark_enemy_detected(GameState.current_enemy.id)
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://src/world/test_lvl.tscn")

func _update_pipe_labels() -> void:
	deck_label.text = "Колода: " + str(deck.size())
	discard_label.text = "Сброс: " + str(discard_pile.size())
