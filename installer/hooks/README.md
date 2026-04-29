# spec-coverage-gate — PreToolUse hook

Hard-gate против instruction drift в `/spec`. Блокирует `Write`/`Edit` на спек-файлы (`**/specs/**/*.md` и аналогах), если контент упоминает PHP-классы или миграции, которые **не были прочитаны** в текущей сессии (через `Read` или `code_read_file`).

## Зачем

Soft-инструкции внутри скилла `/spec` не предотвращают instruction drift на длинных сессиях. Документ `task-brief-spec-coverage-gate.md` фиксирует реальный failure case (FINSOLVE-494): 3 из 7 сущностей попали в спеку без верификации. Hook закрывает эту дыру жёстко — на уровне tool-call контракта Claude Code.

## Как устанавливается

Через `payfin-mcp/installer/setup.ps1` (Windows) или `setup.sh` (Mac/Linux):
1. Скрипты копируются в `~/.claude/hooks/`
2. Регистрируется PreToolUse-matcher `Write|Edit` в `~/.claude/settings.json`

## Файлы

| Файл | Назначение |
|------|------------|
| `spec-coverage-gate.sh` | bash entry — читает stdin, форвардит в python |
| `spec-coverage-gate.py` | основная логика: парсинг payload, regex по сущностям, glob-lookup, чтение transcript JSONL, diff |
| `spec-coverage.config.json` | дефолтный конфиг с Laravel-конвенциями. Override per-project: `.claude/spec-coverage.config.json` |
| `tests/test_synthetic.py` | 5 синтетических кейсов (КТ-1) |

## Конфиг

```json
{
  "matchers": ["**/specs/**/*.md", "**/spec-*.md"],
  "skip_paths": ["**/CHANGELOG*.md", "**/README*.md"],
  "entity_suffixes": ["Service", "Controller", "DTO", "Enum", ...],
  "entity_globs": {
    "Service": ["app/Services/**/{name}.php", "app/Services/V1/**/{name}.php"],
    ...
  },
  "ignore_namespace_prefixes": ["Stripe", "Symfony", "Illuminate", ...]
}
```

CoreNasiya использует `app/Services/V1/` — паттерн уже включён в дефолте.

## Поведение

| Условие | Exit code |
|---------|-----------|
| `tool_name` не Write/Edit | 0 |
| `file_path` не матчит spec-pattern или матчит skip_paths | 0 |
| В контенте нет упоминаний PHP-классов и миграций | 0 |
| Все упомянутые классы — внешние (Stripe, Symfony, ...) или не находятся в проекте | 0 |
| Все упомянутые сущности были прочитаны в transcript | 0 |
| Часть упомянутых сущностей не прочитана | **2** + список в stderr |

## Bypass

**Запрещён.** Если hook сработал — прочитать упомянутые файлы и повторить запись. Не обходить через переименование классов или удаление упоминаний из спеки.

## Тестирование

```bash
cd payfin-mcp/installer/hooks
py tests/test_synthetic.py        # Windows
python3 tests/test_synthetic.py   # Mac/Linux
```

## Интеграция с settings.json

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "command",
          "command": "$HOME/.claude/hooks/spec-coverage-gate.sh"
        }]
      }
    ]
  }
}
```

На Windows `setup.ps1` подставляет полный путь через `$env:USERPROFILE`.

## Ограничения текущей версии

- Только Laravel-конвенции (PHP). Mobile/FE проекты не проверяются.
- Regex-extractor может ловить false positives на синтетических примерах в шаблонах. Если конкретный класс — пример из шаблона, а не реальная зависимость — переименовать в шаблоне (`MyExampleService` вместо `MyService`) или добавить в `ignore_namespace_prefixes`.
- Transcript path определяется через payload `transcript_path` или env `CLAUDE_TRANSCRIPT_PATH`. При отсутствии — гейт пропускает (fail-open).
