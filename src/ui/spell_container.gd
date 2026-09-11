extends Control

@onready var spell_atk: TextureButton = $PanelContainer/HBoxContainer/SpellAtk
@onready var spell_def: TextureButton = $PanelContainer/HBoxContainer/SpellDef
@onready var spell_utl: TextureButton = $PanelContainer/HBoxContainer/SpellUtl


func _ready() -> void:
	visible = false


func set_spells(infection_name: String) -> void:
	var spell_name := infection_name.trim_prefix("inf_")

	var atk_path := "res://assets/icons/spell_atk_%s.png" % spell_name
	var def_path := "res://assets/icons/spell_def_%s.png" % spell_name
	var utl_path := "res://assets/icons/spell_utl_%s.png" % spell_name

	var atk_texture := load(atk_path) as Texture2D
	var def_texture := load(def_path) as Texture2D
	var utl_texture := load(utl_path) as Texture2D

	if atk_texture:
		spell_atk.texture_normal = atk_texture
	else:
		push_warning("Не найдена текстура: " + atk_path)

	if def_texture:
		spell_def.texture_normal = def_texture
	else:
		push_warning("Не найдена текстура: " + def_path)

	if utl_texture:
		spell_utl.texture_normal = utl_texture
	else:
		push_warning("Не найдена текстура: " + utl_path)
