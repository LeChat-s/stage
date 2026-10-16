from pathlib import Path
import shutil, sys

ROOT = Path.cwd()
PROJECT = ROOT / 'project.godot'
if not PROJECT.exists():
    print('ERROR: запусти скрипт из корня проекта рядом с project.godot')
    sys.exit(1)

files = {
    'enemy_gd': ROOT/'src/battle/enemy_in_battle.gd',
    'player_gd': ROOT/'src/battle/player_in_battle.gd',
    'enemy_scene': ROOT/'src/battle/enemy_in_battle.tscn',
    'player_scene': ROOT/'src/battle/player_in_battle.tscn',
}
for p in files.values():
    if not p.exists():
        print('ERROR: не найден', p)
        sys.exit(1)
    b = p.with_suffix(p.suffix + '.bak_before_status_ui')
    if not b.exists(): shutil.copy2(p, b)

ui_dir = ROOT/'src/ui'; battle_dir = ROOT/'src/battle'
ui_dir.mkdir(parents=True, exist_ok=True); battle_dir.mkdir(parents=True, exist_ok=True)

(ui_dir/'combat_status_icon.gd').write_text(r'''class_name CombatStatusIcon
extends PanelContainer

@onready var symbol_label: Label = $Symbol
@onready var value_label: Label = $Value
@onready var duration_label: Label = $Duration
var _style: StyleBoxFlat = StyleBoxFlat.new()

func _ready() -> void:
    custom_minimum_size = Vector2(30.0, 30.0)
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    mouse_filter = Control.MOUSE_FILTER_STOP
    _style.bg_color = Color("#20242b")
    _style.border_color = Color("#6d7582")
    _style.set_border_width_all(1)
    _style.corner_radius_top_left = 2
    _style.corner_radius_top_right = 2
    _style.corner_radius_bottom_left = 2
    _style.corner_radius_bottom_right = 2
    _style.anti_aliasing = false
    add_theme_stylebox_override("panel", _style)

func setup(symbol: String, accent: Color, value_text: String, duration: int, description: String) -> void:
    _style.bg_color = accent.darkened(0.62)
    _style.border_color = accent
    symbol_label.text = symbol
    symbol_label.modulate = accent.lightened(0.28)
    value_label.text = value_text
    value_label.visible = not value_text.is_empty()
    duration_label.text = str(duration)
    duration_label.visible = duration > 0
    tooltip_text = description
''', encoding='utf-8')

(ui_dir/'combat_status_icon.tscn').write_text(r'''[gd_scene format=3]

[ext_resource type="Script" path="res://src/ui/combat_status_icon.gd" id="1_status"]
[ext_resource type="FontFile" path="res://assets/fonts/PixeloidSans.ttf" id="2_font"]

[node name="CombatStatusIcon" type="PanelContainer"]
custom_minimum_size = Vector2(30, 30)
mouse_filter = 0
script = ExtResource("1_status")

[node name="Symbol" type="Label" parent="."]
layout_mode = 2
theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.75)
theme_override_constants/shadow_offset_x = 1
theme_override_constants/shadow_offset_y = 1
theme_override_fonts/font = ExtResource("2_font")
theme_override_font_sizes/font_size = 10
text = "?"
horizontal_alignment = 1
vertical_alignment = 1

[node name="Value" type="Label" parent="."]
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 3
theme_override_fonts/font = ExtResource("2_font")
theme_override_font_sizes/font_size = 8
text = "x3"
horizontal_alignment = 2
vertical_alignment = 2

[node name="Duration" type="Label" parent="."]
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.92, 0.63, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 3
theme_override_fonts/font = ExtResource("2_font")
theme_override_font_sizes/font_size = 8
text = "2"
horizontal_alignment = 2
vertical_alignment = 0
''', encoding='utf-8')

(battle_dir/'combat_status_container.gd').write_text(r'''class_name CombatStatusContainer
extends HBoxContainer

const STATUS_ICON_SCENE := preload("res://src/ui/combat_status_icon.tscn")
var active_icons: Dictionary = {}

func _ready() -> void:
    add_theme_constant_override("separation", 3)

func sync(entries: Array[Dictionary]) -> void:
    var seen: Dictionary = {}
    for entry in entries:
        var status_id: String = str(entry.get("id", ""))
        if status_id.is_empty(): continue
        seen[status_id] = true
        var icon: CombatStatusIcon = null
        if active_icons.has(status_id):
            icon = active_icons[status_id] as CombatStatusIcon
        else:
            icon = STATUS_ICON_SCENE.instantiate() as CombatStatusIcon
            add_child(icon)
            active_icons[status_id] = icon
        var accent: Color = Color("#7b8492")
        if entry.has("color") and entry["color"] is Color: accent = entry["color"]
        icon.setup(str(entry.get("symbol", "?")), accent, str(entry.get("value", "")), int(entry.get("duration", 0)), str(entry.get("tooltip", status_id)))
    for status_id in active_icons.keys().duplicate():
        if seen.has(status_id): continue
        var icon: CombatStatusIcon = active_icons[status_id] as CombatStatusIcon
        if is_instance_valid(icon): icon.queue_free()
        active_icons.erase(status_id)

func clear_statuses() -> void:
    for status_id in active_icons.keys().duplicate():
        var icon: CombatStatusIcon = active_icons[status_id] as CombatStatusIcon
        if is_instance_valid(icon): icon.queue_free()
    active_icons.clear()
''', encoding='utf-8')

def repl(text, old, new, label, count=1):
    if old not in text:
        print('WARN:', label, '— anchor не найден, пропускаю')
        return text
    return text.replace(old, new, count)

enemy = files['enemy_gd'].read_text(encoding='utf-8')
player = files['player_gd'].read_text(encoding='utf-8')
es = files['enemy_scene'].read_text(encoding='utf-8')
ps = files['player_scene'].read_text(encoding='utf-8')

if '@onready var status_ui: CombatStatusContainer' not in enemy:
    enemy = repl(enemy, '@onready var enemy_sprite: Sprite2D = $EnemySprite\n', '@onready var enemy_sprite: Sprite2D = $EnemySprite\n@onready var status_ui: CombatStatusContainer = $HPBar/CombatStatus\n@onready var turn_badge: Label = $TurnBadge\n', 'enemy onready')

# setup/resetup refreshes (first two occurrences)
enemy = enemy.replace('\temit_signals()\n\tshow_intent()\n', '\temit_signals()\n\t_refresh_combat_status_ui()\n\tshow_intent()\n', 2)
enemy = repl(enemy, '\tdebuffs[status_id] = data\n\tshow_intent()\n', '\tdebuffs[status_id] = data\n\t_refresh_combat_status_ui()\n\tshow_intent()\n', 'enemy apply_status', 1)
enemy = repl(enemy, 'func remove_status(status_id: String) -> void:\n\tdebuffs.erase(status_id)\n\tshow_intent()\n', 'func remove_status(status_id: String) -> void:\n\tdebuffs.erase(status_id)\n\t_refresh_combat_status_ui()\n\tshow_intent()\n', 'enemy remove_status')
enemy = repl(enemy, 'func tick_statuses_end_turn() -> void:\n\t_tick_dictionary(buffs)\n\t_tick_dictionary(debuffs)\n\tshow_intent()\n', 'func tick_statuses_end_turn() -> void:\n\t_tick_dictionary(buffs)\n\t_tick_dictionary(debuffs)\n\t_refresh_combat_status_ui()\n\tshow_intent()\n', 'enemy tick')
enemy = repl(enemy, '\tbuffs[buff_name] = data\n', '\tbuffs[buff_name] = data\n\t_refresh_combat_status_ui()\n', 'enemy buff')
status_block='''\tvar status_parts: Array[String] = []\n\tvar poison_stacks: int = get_status_stacks("poison")\n\tif poison_stacks > 0:\n\t\tstatus_parts.append("Яд x%d" % poison_stacks)\n\tif has_status("on_fire"):\n\t\tstatus_parts.append("Горение")\n\tif not status_parts.is_empty():\n\t\ttext += "\\n" + " | ".join(status_parts)\n'''
enemy = enemy.replace(status_block, '', 1)
if 'func set_turn_active(active: bool)' in enemy and '\tturn_badge.visible = active\n' not in enemy:
    enemy = repl(enemy, '\tz_index = 5 if active else 0\n', '\tz_index = 5 if active else 0\n\tturn_badge.visible = active\n', 'turn badge')

if 'func _refresh_combat_status_ui() -> void:' not in enemy:
    helper=r'''func _refresh_combat_status_ui() -> void:
    if status_ui == null: return
    var entries: Array[Dictionary] = []
    if buffs.has("rage"):
        var rage: Dictionary = buffs["rage"]
        var rv: int = int(rage.get("value", 0))
        var rd: int = int(rage.get("duration", 0))
        entries.append({"id":"rage","symbol":"ЯР","color":Color("#c85b62"),"value":"+%d" % rv,"duration":rd,"tooltip":"Ярость\nАтака +%d\nОсталось ходов: %d" % [rv, rd]})
    for key in debuffs.keys():
        var sid: String = str(key)
        var data: Dictionary = debuffs[key]
        var dur: int = int(data.get("duration", 0))
        var stacks: int = int(data.get("stacks", data.get("amount", 1)))
        match sid:
            "poison":
                var tick: int = int(data.get("tick_damage", 0)) + int(data.get("damage_per_stack", 0)) * stacks
                entries.append({"id":sid,"symbol":"ЯД","color":Color("#72a85c"),"value":"x%d" % stacks,"duration":dur,"tooltip":"Яд\nСтаки: %d\nУрон в начале хода: %d\nОсталось ходов: %d" % [stacks,tick,dur]})
            "on_fire":
                var dmg: int = int(data.get("tick_damage", 0))
                entries.append({"id":sid,"symbol":"ОГ","color":Color("#d1764f"),"value":str(dmg) if dmg > 0 else "","duration":dur,"tooltip":"Горение\nУрон в начале хода: %d\nОсталось ходов: %d" % [dmg,dur]})
            _:
                entries.append({"id":sid,"symbol":sid.left(2).to_upper(),"color":Color("#8d78a8"),"value":"x%d" % stacks if stacks > 1 else "","duration":dur,"tooltip":"%s\nСтаки: %d\nОсталось ходов: %d" % [sid,stacks,dur]})
    status_ui.sync(entries)


'''
    enemy = repl(enemy, 'func emit_signals() -> void:\n', helper+'func emit_signals() -> void:\n', 'enemy helper')

if '@onready var combat_status_ui: CombatStatusContainer' not in player:
    player = repl(player, '@onready var effects_ui: EffectContainer = $HPBar/Status\n', '@onready var effects_ui: EffectContainer = $HPBar/Status\n@onready var combat_status_ui: CombatStatusContainer = $HPBar/CombatStatus\n', 'player onready')
player = repl(player, '\tprocessed_damage = buffs.process_damage(processed_damage)\n', '\tprocessed_damage = buffs.process_damage(processed_damage)\n\t_refresh_combat_status_ui()\n', 'shield charge refresh')
player = repl(player, 'func reset_turn() -> void:\n\tbuffs.tick()\n', 'func reset_turn() -> void:\n\tbuffs.tick()\n\t_refresh_combat_status_ui()\n', 'player buff tick')
player = repl(player, '\tfor debuff_id in expired:\n\t\tdebuffs.erase(debuff_id)\n\nfunc apply_debuff', '\tfor debuff_id in expired:\n\t\tdebuffs.erase(debuff_id)\n\t_refresh_combat_status_ui()\n\nfunc apply_debuff', 'player debuff tick')
player = repl(player, '\tdebuffs[debuff_id] = data\n\nfunc clear_debuffs', '\tdebuffs[debuff_id] = data\n\t_refresh_combat_status_ui()\n\nfunc clear_debuffs', 'player apply debuff')
player = repl(player, 'func clear_debuffs() -> void:\n\tdebuffs.clear()\n', 'func clear_debuffs() -> void:\n\tdebuffs.clear()\n\t_refresh_combat_status_ui()\n', 'player clear')
player = repl(player, 'func remove_status(status_id: String) -> void:\n\tdebuffs.erase(status_id)\n', 'func remove_status(status_id: String) -> void:\n\tdebuffs.erase(status_id)\n\t_refresh_combat_status_ui()\n', 'player remove')
player = repl(player, 'func apply_buff(buff_id: String, duration: int = 1, level: int = 0) -> void:\n\tbuffs.apply(buff_id, duration, level)\n', 'func apply_buff(buff_id: String, duration: int = 1, level: int = 0) -> void:\n\tbuffs.apply(buff_id, duration, level)\n\t_refresh_combat_status_ui()\n', 'player buff')
player = repl(player, 'func set_buff_charges(buff_id: String, amount: int) -> void:\n\tbuffs.set_charges(buff_id, amount)\n', 'func set_buff_charges(buff_id: String, amount: int) -> void:\n\tbuffs.set_charges(buff_id, amount)\n\t_refresh_combat_status_ui()\n', 'player charge')

if 'func _refresh_combat_status_ui() -> void:' not in player:
    helper=r'''func _refresh_combat_status_ui() -> void:
    if combat_status_ui == null: return
    var entries: Array[Dictionary] = []
    var lvl: int = buffs.get_level("shield")
    if lvl > 0:
        var dur: int = buffs.get_duration("shield")
        var charges: int = buffs.get_charges("shield")
        var levels: Array[String] = ["", "I", "II", "III"]
        var lt: String = levels[clampi(lvl, 1, 3)]
        var charge_text: String = (" · зарядов %d" % charges) if charges > 0 else ""
        entries.append({"id":"shield","symbol":"Щ","color":Color("#5b91bd"),"value":lt,"duration":dur,"tooltip":"Щит %s\nСнижение урона / защита от статусов%s\nОсталось ходов: %d" % [lt,charge_text,dur]})
    for key in debuffs.keys():
        var sid: String = str(key)
        var data: Dictionary = debuffs[key]
        var dur: int = int(data.get("duration", 0))
        var amount: int = int(data.get("amount", data.get("stacks", 1)))
        if sid == "weak":
            entries.append({"id":sid,"symbol":"СЛ","color":Color("#9278ad"),"value":"-25%","duration":dur,"tooltip":"Слабость\nИсходящий урон -25%\nОсталось ходов: %d" % dur})
        else:
            entries.append({"id":sid,"symbol":sid.left(2).to_upper(),"color":Color("#9a6f78"),"value":"x%d" % amount if amount > 1 else "","duration":dur,"tooltip":"%s\nЗначение: %d\nОсталось ходов: %d" % [sid,amount,dur]})
    combat_status_ui.sync(entries)


'''
    player = repl(player, 'func emit_signals() -> void:\n', helper+'func emit_signals() -> void:\n', 'player helper')

# scenes
if 'path="res://src/battle/combat_status_container.gd"' not in es:
    es = repl(es, '[ext_resource type="FontFile" uid="uid://c35xg7jni7v5p" path="res://assets/fonts/PixeloidSans.ttf" id="2_vm073"]\n', '[ext_resource type="FontFile" uid="uid://c35xg7jni7v5p" path="res://assets/fonts/PixeloidSans.ttf" id="2_vm073"]\n[ext_resource type="Script" path="res://src/battle/combat_status_container.gd" id="99_status"]\n', 'enemy scene resource')
if '[node name="CombatStatus" type="HBoxContainer" parent="HPBar"]' not in es:
    block='''[node name="CombatStatus" type="HBoxContainer" parent="HPBar"]
layout_mode = 0
offset_left = -2.0
offset_top = 32.0
offset_right = 124.0
offset_bottom = 62.0
alignment = 1
theme_override_constants/separation = 3
script = ExtResource("99_status")

[node name="TurnBadge" type="Label" parent="."]
visible = false
offset_left = -34.0
offset_top = -250.0
offset_right = 34.0
offset_bottom = -228.0
theme_override_colors/font_color = Color(1, 0.86, 0.45, 1)
theme_override_colors/font_outline_color = Color(0.08, 0.08, 0.1, 1)
theme_override_constants/outline_size = 4
theme_override_fonts/font = ExtResource("2_vm073")
theme_override_font_sizes/font_size = 12
text = "ХОД"
horizontal_alignment = 1
vertical_alignment = 1

'''
    es = repl(es, '[node name="Intent" type="Label" parent="." unique_id=1175957020]\n', block+'[node name="Intent" type="Label" parent="." unique_id=1175957020]\n', 'enemy scene nodes')
if 'path="res://src/battle/combat_status_container.gd"' not in ps:
    ps = repl(ps, '[ext_resource type="Script" uid="uid://dctrner31anc5" path="res://src/battle/effect_container.gd" id="3_5cdk3"]\n', '[ext_resource type="Script" uid="uid://dctrner31anc5" path="res://src/battle/effect_container.gd" id="3_5cdk3"]\n[ext_resource type="Script" path="res://src/battle/combat_status_container.gd" id="99_status"]\n', 'player scene resource')
if '[node name="CombatStatus" type="HBoxContainer" parent="HPBar"]' not in ps:
    block='''[node name="CombatStatus" type="HBoxContainer" parent="HPBar"]
layout_mode = 0
offset_left = -2.0
offset_top = 58.0
offset_right = 142.0
offset_bottom = 88.0
theme_override_constants/separation = 3
script = ExtResource("99_status")

'''
    ps = repl(ps, '[node name="Sprite2D" type="Sprite2D" parent="." unique_id=1398213391]\n', block+'[node name="Sprite2D" type="Sprite2D" parent="." unique_id=1398213391]\n', 'player scene node')

files['enemy_gd'].write_text(enemy, encoding='utf-8')
files['player_gd'].write_text(player, encoding='utf-8')
files['enemy_scene'].write_text(es, encoding='utf-8')
files['player_scene'].write_text(ps, encoding='utf-8')
print('OK: Battle Status UI установлен. Backup: *.bak_before_status_ui')
