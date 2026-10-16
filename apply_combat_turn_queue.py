from pathlib import Path
import shutil
import sys

ROOT = Path.cwd()
BATTLE = ROOT / "src/battle/battle.gd"
ENEMY = ROOT / "src/battle/enemy_in_battle.gd"

def fail(message: str) -> None:
    print("ERROR:", message)
    sys.exit(1)

if not (ROOT / "project.godot").exists():
    fail("Запусти скрипт из корня Godot-проекта, рядом с project.godot.")
if not BATTLE.exists() or not ENEMY.exists():
    fail("Не найдены src/battle/battle.gd и/или enemy_in_battle.gd.")

for path in (BATTLE, ENEMY):
    backup = path.with_suffix(path.suffix + ".bak_before_turn_queue")
    if not backup.exists():
        shutil.copy2(path, backup)

battle = BATTLE.read_text(encoding="utf-8")

old = '''@export var spawn_positions: Array[Marker2D] = []
@export var enemy_catalog: EnemyCatalog
'''
new = '''@export var spawn_positions: Array[Marker2D] = []
@export var enemy_catalog: EnemyCatalog

@export_category("Enemy Turn Queue")
@export_range(0.05, 1.0, 0.01) var enemy_shift_duration: float = 0.22
@export_range(0.0, 1.0, 0.01) var enemy_action_pause: float = 0.12
'''
if old not in battle:
    fail("battle.gd: не найден блок export spawn_positions/enemy_catalog.")
battle = battle.replace(old, new, 1)

old = '''var _is_battle_ending: bool = false
var _turn_locked: bool = false
var _starting_hand_prepared: bool = false
'''
new = '''var _is_battle_ending: bool = false
var _turn_locked: bool = false
var _starting_hand_prepared: bool = false
var _enemy_phase_running: bool = false
'''
if old not in battle:
    fail("battle.gd: не найден блок внутренних флагов.")
battle = battle.replace(old, new, 1)

old_end_turn = '''func _on_end_turn() -> void:
\tif _turn_locked or _is_battle_ending:
\t\treturn

\t_turn_locked = true
\tend_turn_button.disabled = true

\tvar cards_to_discard: Array[CardData] = []
\tfor card in current_hand:
\t\tif not card.has_effect("exile_on_turn_end"):
\t\t\tcards_to_discard.append(card)
\tdiscard_pile.append_array(cards_to_discard)
\tcurrent_hand.clear()
\thand.clear_hand()
\tplayer.tick_end_turn_statuses()

\tvar current_enemies: Array[EnemyInBattle] = enemies.duplicate()
\tfor current_enemy in current_enemies:
\t\tif _is_battle_ending:
\t\t\treturn
\t\tif not is_instance_valid(current_enemy) or current_enemy.hp <= 0:
\t\t\tcontinue

\t\tawait current_enemy.process_turn_start_statuses()
\t\tif _is_battle_ending or not is_instance_valid(current_enemy) or current_enemy.hp <= 0:
\t\t\tcontinue

\t\tvar action: String = current_enemy.get_next_action()
\t\tcurrent_enemy.execute_action(action, player)
\t\tcurrent_enemy.tick_statuses_end_turn()

\t\tif player.hp <= 0:
\t\t\treturn

\tif not _is_battle_ending and player.hp > 0:
\t\t_start_player_turn()
'''

new_end_turn = '''func _on_end_turn() -> void:
\tif _turn_locked or _is_battle_ending:
\t\treturn

\t_turn_locked = true
\tend_turn_button.disabled = true

\tvar cards_to_discard: Array[CardData] = []
\tfor card in current_hand:
\t\tif not card.has_effect("exile_on_turn_end"):
\t\t\tcards_to_discard.append(card)
\tdiscard_pile.append_array(cards_to_discard)
\tcurrent_hand.clear()
\thand.clear_hand()
\tplayer.tick_end_turn_statuses()

\t_enemy_phase_running = true

\t# В pending попадают только враги, существовавшие в начале вражеской фазы.
\t# Призванные во время этой фазы занимают свободный слот, но ходят со следующего круга.
\tvar pending: Array[EnemyInBattle] = _get_alive_enemy_order()
\tvar acted: Array[EnemyInBattle] = []

\tawait _move_enemy_group_to_front(pending)

\twhile not pending.is_empty():
\t\tif _is_battle_ending:
\t\t\t_enemy_phase_running = false
\t\t\treturn

\t\tvar current_enemy: EnemyInBattle = pending[0]
\t\tif not is_instance_valid(current_enemy) or current_enemy.hp <= 0:
\t\t\tpending.pop_front()
\t\t\tawait _move_enemy_group_to_front(_make_visual_turn_order(pending, acted))
\t\t\tcontinue

\t\tcurrent_enemy.set_turn_active(true)

\t\tawait current_enemy.process_turn_start_statuses()
\t\tif _is_battle_ending:
\t\t\t_enemy_phase_running = false
\t\t\treturn

\t\t# DoT может убить врага до его действия.
\t\tif not is_instance_valid(current_enemy) or current_enemy.hp <= 0:
\t\t\tif is_instance_valid(current_enemy):
\t\t\t\tcurrent_enemy.set_turn_active(false)
\t\t\tpending.pop_front()
\t\t\tawait _move_enemy_group_to_front(_make_visual_turn_order(pending, acted))
\t\t\tcontinue

\t\tvar action: String = current_enemy.get_next_action()
\t\tcurrent_enemy.execute_action(action, player)
\t\tcurrent_enemy.tick_statuses_end_turn()

\t\tif enemy_action_pause > 0.0 and not _is_battle_ending:
\t\t\tawait get_tree().create_timer(enemy_action_pause).timeout

\t\tif is_instance_valid(current_enemy):
\t\t\tcurrent_enemy.set_turn_active(false)

\t\tif player.hp <= 0 or _is_battle_ending:
\t\t\t_enemy_phase_running = false
\t\t\treturn

\t\t# Отходивший враг отправляется в конец визуальной очереди.
\t\tpending.pop_front()
\t\tacted.append(current_enemy)
\t\tawait _move_enemy_group_to_front(_make_visual_turn_order(pending, acted))

\t_enemy_phase_running = false
\tawait _normalize_enemy_slots()

\tif not _is_battle_ending and player.hp > 0:
\t\t_start_player_turn()


func _make_visual_turn_order(
\tpending: Array[EnemyInBattle],
\tacted: Array[EnemyInBattle]
) -> Array[EnemyInBattle]:
\tvar result: Array[EnemyInBattle] = []
\tfor enemy in pending:
\t\tif is_instance_valid(enemy) and enemy.hp > 0:
\t\t\tresult.append(enemy)
\tfor enemy in acted:
\t\tif is_instance_valid(enemy) and enemy.hp > 0:
\t\t\tresult.append(enemy)
\treturn result


func _get_alive_enemy_order() -> Array[EnemyInBattle]:
\tvar result: Array[EnemyInBattle] = []

\tfor marker_index in range(spawn_positions.size()):
\t\tfor enemy in enemies:
\t\t\tif not is_instance_valid(enemy) or enemy.hp <= 0 or result.has(enemy):
\t\t\t\tcontinue
\t\t\tif (
\t\t\t\tenemy.has_meta("spawn_marker_index")
\t\t\t\tand int(enemy.get_meta("spawn_marker_index")) == marker_index
\t\t\t):
\t\t\t\tresult.append(enemy)

\tfor enemy in enemies:
\t\tif is_instance_valid(enemy) and enemy.hp > 0 and not result.has(enemy):
\t\t\tresult.append(enemy)

\treturn result


func _move_enemy_group_to_front(order: Array[EnemyInBattle]) -> void:
\tif order.is_empty() or spawn_positions.is_empty():
\t\treturn

\tvar tween: Tween = create_tween()
\ttween.set_parallel(true)
\tvar has_motion: bool = false

\tvar count: int = mini(order.size(), spawn_positions.size())
\tfor i in range(count):
\t\tvar enemy: EnemyInBattle = order[i]
\t\tif not is_instance_valid(enemy) or enemy.hp <= 0:
\t\t\tcontinue

\t\tvar target_position: Vector2 = spawn_positions[i].global_position
\t\tenemy.set_meta("spawn_marker_index", i)

\t\tif enemy.global_position.distance_to(target_position) <= 0.5:
\t\t\tcontinue

\t\thas_motion = true
\t\ttween.tween_property(
\t\t\tenemy,
\t\t\t"global_position",
\t\t\ttarget_position,
\t\t\tenemy_shift_duration
\t\t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

\tif has_motion:
\t\tawait tween.finished
\telse:
\t\ttween.kill()


func _normalize_enemy_slots() -> void:
\tvar alive_order: Array[EnemyInBattle] = _get_alive_enemy_order()
\tawait _move_enemy_group_to_front(alive_order)
'''

if old_end_turn not in battle:
    fail("battle.gd: не найден ожидаемый _on_end_turn() из v0.35.")
battle = battle.replace(old_end_turn, new_end_turn, 1)

old_enemy_died = '''func _on_enemy_died(dead_enemy: EnemyInBattle) -> void:
\tif is_instance_valid(dead_enemy):
\t\tenemies.erase(dead_enemy)
\tif selected_enemy_target == dead_enemy:
\t\tselected_enemy_target = _get_first_alive_enemy()
\tif current_target == dead_enemy:
\t\tcurrent_target = null
\tcall_deferred("_check_victory")
'''

new_enemy_died = '''func _on_enemy_died(dead_enemy: EnemyInBattle) -> void:
\tif is_instance_valid(dead_enemy):
\t\tenemies.erase(dead_enemy)
\tif selected_enemy_target == dead_enemy:
\t\tselected_enemy_target = _get_first_alive_enemy()
\tif current_target == dead_enemy:
\t\tcurrent_target = null

\tif not _enemy_phase_running:
\t\tcall_deferred("_normalize_enemy_slots")

\tcall_deferred("_check_victory")
'''
if old_enemy_died not in battle:
    fail("battle.gd: не найден ожидаемый _on_enemy_died().")
battle = battle.replace(old_enemy_died, new_enemy_died, 1)
BATTLE.write_text(battle, encoding="utf-8")

enemy = ENEMY.read_text(encoding="utf-8")

old = '''var buffs: Dictionary = {}
var debuffs: Dictionary = {}
'''
new = '''var buffs: Dictionary = {}
var debuffs: Dictionary = {}

var _base_sprite_scale: Vector2 = Vector2.ONE
var _turn_focus_tween: Tween = null
'''
if old not in enemy:
    fail("enemy_in_battle.gd: не найден блок buffs/debuffs.")
enemy = enemy.replace(old, new, 1)

old = '''func _ready() -> void:
\tvar click_zone: Area2D = $Area2D
\tif click_zone:
\t\tclick_zone.input_event.connect(_on_click_zone_input_event)
'''
new = '''func _ready() -> void:
\tif enemy_sprite != null:
\t\t_base_sprite_scale = enemy_sprite.scale

\tvar click_zone: Area2D = $Area2D
\tif click_zone:
\t\tclick_zone.input_event.connect(_on_click_zone_input_event)
'''
if old not in enemy:
    fail("enemy_in_battle.gd: не найден _ready().")
enemy = enemy.replace(old, new, 1)

anchor = '''func emit_signals() -> void:
\thp_changed.emit(hp, max_hp)
\tblock_changed.emit(block)
'''
replacement = '''func set_turn_active(active: bool) -> void:
\t# Selection outline остаётся независимым и продолжает показывать цель игрока.
\t# Активный ход отмечается масштабом, intent-цветом и z-index.
\tz_index = 5 if active else 0

\tif _turn_focus_tween != null and _turn_focus_tween.is_valid():
\t\t_turn_focus_tween.kill()

\t_turn_focus_tween = create_tween()
\t_turn_focus_tween.set_parallel(true)

\tif enemy_sprite != null:
\t\tvar target_scale: Vector2 = _base_sprite_scale * (1.08 if active else 1.0)
\t\t_turn_focus_tween.tween_property(
\t\t\tenemy_sprite,
\t\t\t"scale",
\t\t\ttarget_scale,
\t\t\t0.12
\t\t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

\tif intent_text != null:
\t\tvar target_color: Color = Color(1.0, 0.86, 0.45, 1.0) if active else Color.WHITE
\t\t_turn_focus_tween.tween_property(
\t\t\tintent_text,
\t\t\t"modulate",
\t\t\ttarget_color,
\t\t\t0.12
\t\t)


func emit_signals() -> void:
\thp_changed.emit(hp, max_hp)
\tblock_changed.emit(block)
'''
if anchor not in enemy:
    fail("enemy_in_battle.gd: не найден emit_signals() anchor.")
enemy = enemy.replace(anchor, replacement, 1)
ENEMY.write_text(enemy, encoding="utf-8")

print("OK: очередь врагов установлена.")
print("Изменены:")
print(" -", BATTLE)
print(" -", ENEMY)
print("Backup: *.bak_before_turn_queue")
