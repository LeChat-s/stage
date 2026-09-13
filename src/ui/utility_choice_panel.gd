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
	if pressed_button == spell_atk: spell_type = "atk"
	elif pressed_button == spell_def: spell_type = "def"
	elif pressed_button == spell_utl: spell_type = "utl"
	_update_description(spell_type, current_infection_name)


func _update_description(spell_type: String, infection: String) -> void:
	if infection.is_empty():
		spell_description.text = ""
		return
	var search_key := "spell_%s_%s" % [spell_type, infection]
	var file_text := _load_file_content(DESCRIPTIONS_FILE_PATH)
	if file_text.is_empty():
		spell_description.text = "Ошибка: не удалось загрузить файл описаний."
		return
		
	var regex := RegEx.new()
	var pattern := "(?s)" + search_key + ":\\s*(.*?)(?=\\s*spell_|$)"
	
	var error := regex.compile(pattern)
	if error != OK:
		push_error("Ошибка компиляции RegEx паттерна!")
		return
		
	var result := regex.search(file_text)
	if result:
		var description := result.get_string(1).strip_edges()
		spell_description.text = description
	else:
		spell_description.text = "Описание для " + search_key + " не найдено."

func _load_file_content(path: String) -> String:
	if not FileAccess.file_exists(path):
		push_warning("Файл не найден по пути: " + path)
		return ""
		
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()
		return content
	return ""

func set_spells(infection_name: String) -> void:
	current_infection_name = infection_name.trim_prefix("inf_")
	spell_description.text = "" 

	var atk_path := "res://assets/icons/spell_atk_%s.png" % current_infection_name
	var def_path := "res://assets/icons/spell_def_%s.png" % current_infection_name
	var utl_path := "res://assets/icons/spell_utl_%s.png" % current_infection_name

	var atk_texture := load(atk_path) as Texture2D
	var def_texture := load(def_path) as Texture2D
	var utl_texture := load(utl_path) as Texture2D

	if atk_texture: spell_atk.texture_normal = atk_texture
	else: push_warning("Не найдена текстура: " + atk_path)

	if def_texture: spell_def.texture_normal = def_texture
	else: push_warning("Не найдена текстура: " + def_path)

	if utl_texture: spell_utl.texture_normal = utl_texture
	else: push_warning("Не найдена текстура: " + utl_path)
