# Баффы, дебаффы и статусы боя

> База: Stage `v0.35` + визуальная очередь врагов.

## 1. Архитектура эффектов

Сейчас в бою существуют четыре контейнера:

| Носитель | Положительные | Отрицательные |
|---|---|---|
| Игрок | `Buff` (`player.buffs`) | `player.debuffs` |
| Враг | `enemy.buffs` | `enemy.debuffs` / status |

Это не одна универсальная система, поэтому timing различается.

## 2. Порядок полного раунда

```text
START PLAYER TURN
├─ cooldown -1
├─ Player Buff.tick()
├─ player.block = 0
├─ восстановление энергии
└─ добор

PLAYER ACTIONS

END PLAYER TURN
├─ Player Debuff duration -1
├─ сброс руки
└─ ENEMY PHASE
   ├─ активный враг находится в Marker[0]
   ├─ Enemy Status trigger
   ├─ Enemy Action
   ├─ Enemy Buff/Status duration -1
   ├─ визуальная ротация
   └─ после всех врагов → START PLAYER TURN
```

## 3. Player Buff

Файл: `src/battle/buff.gd`.

Структура:

```gdscript
{
    "level": int,
    "duration": int,
    "charges": int
}
```

`duration` уменьшается в `PlayerInBattle.reset_turn()`, то есть **в начале хода игрока**.

Если Shield duration=2 получен до вражеской фазы:

```text
enemy phase #1: 2
next player start: 2 -> 1
enemy phase #2: 1
next player start: 1 -> 0, remove
```

### Повторное применение

- level: сохраняется максимальный;
- duration: `max(old, new)`;
- duration не суммируется;
- Shield III может восстановить charge при повторном применении.

## 4. Shield

### Shield I

`level >= 1`

До обычного Block:

```text
incoming damage × 0.8
```

Используется `ceili()`.

### Shield II

`level >= 2`

`blocks_debuff()` возвращает true. Вызовы `player.apply_debuff()` блокируются полностью.

### Shield III

`level >= 3` и `charges > 0`

Один удар превращается в `0 damage`, затем `charges -= 1`.

Усиленная версия может выставить `charges = 2`.

### Порядок обработки урона игроку

```text
GameState.calculate_incoming_damage()
→ Shield / Buff.process_damage()
→ обычный Block
→ HP
```

## 5. Player Debuff

Формат:

```gdscript
{
    "duration": int,
    "amount": int
}
```

Уменьшается в `player.tick_end_turn_statuses()` **при завершении хода игрока**.

Поэтому Weak, наложенный врагом во время enemy phase, не теряет duration сразу и гарантированно влияет на следующий ход игрока.

### Повторное применение

```text
duration = max(old, new)
amount   = max(old, new)
```

Не стакается суммой.

## 6. Weak

В `get_outgoing_damage_multiplier()`:

```text
Weak → ×0.75
```

Штраф применяется поверх множителя текущего билда.

Пример:

```text
build ×1.2
weak ×0.75
итог ×0.9
```

## 7. Enemy Buff

Формат:

```gdscript
{
    "value": int,
    "duration": int
}
```

Тикает после собственного действия врага в `tick_statuses_end_turn()`.

### Rage

`self_buff` вызывает:

```gdscript
_apply_timed_buff("rage", value, 2)
```

Повторное применение:

```text
value += value
duration = max(old, new)
```

Rage добавляется к атаке и к отображаемому intent.

## 8. Enemy Status / Debuff

Общий API:

```gdscript
apply_status(
    status_id,
    duration,
    stacks,
    tick_damage,
    damage_per_stack,
    damage_type,
    max_stacks
)
```

Хранилище:

```gdscript
{
    "duration": int,
    "stacks": int,
    "tick_damage": int,
    "damage_per_stack": int,
    "damage_type": int
}
```

### Формула тика

```text
tick_damage + damage_per_stack × stacks
```

### Timing

Перед действием врага:

```text
Marker[0]
→ process_turn_start_statuses()
→ trigger_status()
→ если жив: execute_action()
```

После действия:

```text
duration -= 1
```

Следовательно status duration=2 даёт два естественных тика.

## 9. Повторное наложение Enemy Status

- stacks: складываются до `max_stacks`;
- duration: `max(old, new)`;
- tick_damage: `max(old, new)`;
- damage_per_stack: `max(old, new)`;
- damage_type заменяется новым значением.

Для явного продления используется `extend_status`.

## 10. Poison

Poison — stack-based status.

Пример:

```gdscript
{
    "id": "apply_status",
    "status": "poison",
    "duration": 3,
    "stacks": 2,
    "damage_per_stack": 2,
    "max_stacks": 20
}
```

Повторные применения увеличивают stacks, но не суммируют duration.

## 11. On Fire

Legacy `apply_debuff("on_fire", duration, amount)` переводится в общий status:

```text
stacks = 1
max_stacks = 1
tick_damage = max(amount, 3)
damage_type = MAGIC
```

Горение не стакается, но может обновлять duration и усиливаться более мощным применением.

## 12. CardEffectProcessor

Поддерживаются:

### `apply_status`
Накладывает generic status.

### `trigger_status`
Немедленно вызывает тик и **не уменьшает duration**.

### `damage_per_status_stack`
Наносит отдельный burst:

```text
stacks × damage_per_stack
```

При `consume=true` статус удаляется.

### `extend_status`
Реально добавляет turns к duration.

## 13. Block — не Buff

### Player Block

Сбрасывается в начале хода игрока.

### Enemy Block

Сбрасывается в начале следующего `execute_action()` этого врага.

Поэтому `defend` врага защищает его во время следующего хода игрока.

## 14. Визуальная очередь врагов

`spawn_positions[0]` — активная позиция.

Для A/B/C:

```text
A[0] B[1] C[2]
A действует
B[0] C[1] A[2]
B действует
C[0] A[1] B[2]
C действует
A[0] B[1] C[2]
→ ход игрока
```

Если DoT убивает A до действия:

```text
A погиб
B[0] C[1]
```

Фаза продолжается с B.

Миньон, призванный во время enemy phase, занимает свободный Marker, но получает первый ход только в следующей enemy phase.

## 15. Рекомендуемые правила для новых эффектов

Использовать:

- простой debuff игрока → `PlayerInBattle.apply_debuff()`;
- stack-based DoT врага → `EnemyInBattle.apply_status()`;
- многоуровневый buff игрока → `Buff`;
- явное продление → `extend_status`;
- немедленный дополнительный тик → `trigger_status`.

## 16. Текущие ограничения

Система пока разделена между:

```text
Buff
Player debuffs
Enemy buffs
Enemy statuses
```

Следующий архитектурный шаг в будущем — единый `StatusInstance` с событиями:

```text
TURN_START
TURN_END
BEFORE_ACTION
AFTER_ACTION
BEFORE_DAMAGE
AFTER_DAMAGE
```

До такой миграции этот документ стоит использовать как источник истины по timing.
