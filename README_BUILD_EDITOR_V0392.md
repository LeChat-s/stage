# Build Editor v0.39.2

Исправлена синтаксическая ошибка в `build_card_editor.gd`.

Повреждённые строки вида:

```gdscript
grid.get_child(...)PickerButton
```

восстановлены до:

```gdscript
grid.get_child(...) as ColorPickerButton
```

Исправлены строки 349, 352, 355 и 358.

После загрузки в Output должно быть:

```text
Build Editor 0.39.2 loaded
```
