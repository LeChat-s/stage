extends Control

@onready var spell_atk: TextureButton = $PanelContainer/HBoxContainer/SpellAtk
@onready var spell_def: TextureButton = $PanelContainer/HBoxContainer/SpellDef
@onready var spell_utl: TextureButton = $PanelContainer/HBoxContainer/SpellUtl
@onready var spell_description: Label = $PanelContainer/SpellDescription

const DESCRIPTIONS_FILE_PATH := "res://src/data/spells_data.txt"

var selected_spell: TextureButton = null
var current_infection_name := ""

func _ready() -> void:
	visible = false
	_setup_button_group()

func _setup_button_group() -> void:
	var group := ButtonGroup.new()
	var buttons: Array[TextureButton] = [spell_atk, spell_def, spell_utl]
	for btn in buttons:
		btn.toggle_mode = true
		btn.button_group = group
		btn.pressed.connect(_on_spell_pressed.bind(btn))

func _on_spell_pressed(pressed_button: TextureButton) -> void:
	selected_spell = pressed_button
	var spell_type := ""
	if pressed_button == spell_atk:
		spell_type = "atk"
	elif pressed_button == spell_def:
		spell_type = "def"
	elif pressed_button == spell_utl:
		spell_type = "utl"
	_update_description(spell_type, current_infection_name)

func _update_description(spell_type: String, infection: String) -> void:
	if infection.is_empty():
		spell_description.text = ""
		return
	var search_key := "spell_%s_%s" % [spell_type, infection]
	var file_text := _load_file_content(DESCRIPTIONS_FILE_PATH)
	if file_text.is_empty():
		spell_description.text = "Описание недоступно."
		return
	var regex := RegEx.new()
	var pattern := "(?s)" + search_key + ":\\s*(.*?)(?=\\s*spell_|$)"
	if regex.compile(pattern) != OK:
		return
	var result := regex.search(file_text)
	spell_description.text = result.get_string(1).strip_edges() if result else "Описание пока не добавлено."

func _load_file_content(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content

func set_spells(infection_name: String) -> void:
	current_infection_name = infection_name.trim_prefix("inf_")
	spell_description.text = ""

	# В репозитории используются spell_button_<build>_a/b/c.png. Старые пути
	# spell_atk/def/utl_<build>.png никогда не существовали и засоряли Output.
	var buttons: Array[TextureButton] = [spell_atk, spell_def, spell_utl]
	var suffixes: Array[String] = ["a", "b", "c"]
	for i in range(buttons.size()):
		var path := "res://assets/icons/spell_button_%s_%s.png" % [current_infection_name, suffixes[i]]
		if not ResourceLoader.exists(path):
			continue
		var texture := load(path) as Texture2D
		if texture != null:
			buttons[i].texture_normal = texture
