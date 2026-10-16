class_name CombatStatusContainer
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
