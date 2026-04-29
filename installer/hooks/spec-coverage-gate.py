#!/usr/bin/env python3
"""
spec-coverage-gate — PreToolUse hook for Claude Code.

Reads the tool payload from stdin and blocks Write/Edit on spec markdown
files when entities mentioned in the new content (PHP classes, migrations)
have not been read in the current session.

Exit codes:
  0 — pass
  2 — block, stderr contains the reason

Reads optional config:
  $CLAUDE_PROJECT_DIR/.claude/spec-coverage.config.json (project override)
  ~/.claude/hooks/spec-coverage.config.json             (default, shipped with hook)
"""

import sys
import json
import os
import re
import glob
import fnmatch
from pathlib import Path


def load_config():
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    candidates = [
        Path(project_dir) / ".claude" / "spec-coverage.config.json",
        Path.home() / ".claude" / "hooks" / "spec-coverage.config.json",
        Path(__file__).parent / "spec-coverage.config.json",
    ]
    for path in candidates:
        if path.exists():
            try:
                return json.loads(path.read_text(encoding="utf-8"))
            except Exception:
                continue
    return {}


def matches_any(path: str, patterns: list) -> bool:
    return any(fnmatch.fnmatch(path, p) for p in patterns)


def extract_content(tool_name: str, tool_input: dict) -> str:
    if tool_name == "Write":
        return tool_input.get("content", "") or ""
    if tool_name == "Edit":
        return tool_input.get("new_string", "") or ""
    return ""


def extract_entities(content: str, config: dict) -> dict:
    """Returns dict {entity_name: [suffix1, suffix2]} for PHP classes by suffix,
    plus a separate set of migration tokens."""
    entities: dict = {}
    suffixes = config.get("entity_suffixes", [])
    if suffixes:
        suffix_alt = "|".join(re.escape(s) for s in suffixes)
        # PascalCase + suffix, anchored on word boundaries; strip optional namespace prefix.
        pattern = re.compile(rf"\b([A-Z][a-zA-Z0-9]+(?:{suffix_alt}))\b")
        ignore_prefixes = config.get("ignore_namespace_prefixes", [])
        for m in pattern.finditer(content):
            name = m.group(1)
            # context check: avoid namespaced foreign classes
            start = max(0, m.start() - 40)
            ctx = content[start:m.start()]
            skip = False
            for prefix in ignore_prefixes:
                if f"{prefix}\\" in ctx or f"use {prefix}\\" in ctx:
                    skip = True
                    break
            if skip:
                continue
            for suffix in suffixes:
                if name.endswith(suffix):
                    entities.setdefault(name, []).append(suffix)
                    break

    migrations: set = set()
    for mig_pattern in config.get("migration_patterns", []):
        for m in re.finditer(mig_pattern, content):
            migrations.add(m.group(0))

    return {"classes": entities, "migrations": migrations}


def find_entity_files(entities: dict, project_dir: str, config: dict) -> dict:
    """For each entity, try to locate a file in the project. Returns
    {entity_name: relative_path} for entities that were found locally.
    Entities not found locally are dropped (treated as external)."""
    found: dict = {}
    entity_globs = config.get("entity_globs", {})

    for name, suffixes in entities.get("classes", {}).items():
        for suffix in suffixes:
            globs = entity_globs.get(suffix, [])
            for g in globs:
                pattern = g.replace("{name}", name)
                full = os.path.join(project_dir, pattern)
                matches = glob.glob(full, recursive=True)
                if matches:
                    rel = os.path.relpath(matches[0], project_dir).replace("\\", "/")
                    found[name] = rel
                    break
            if name in found:
                break

    mig_glob = config.get("migration_glob", "database/migrations/*{name}*.php")
    for mig in entities.get("migrations", set()):
        pattern = mig_glob.replace("{name}", mig)
        full = os.path.join(project_dir, pattern)
        matches = glob.glob(full, recursive=True)
        if matches:
            rel = os.path.relpath(matches[0], project_dir).replace("\\", "/")
            found[mig] = rel

    return found


def collect_read_paths(transcript_path: str) -> set:
    """Parse session transcript JSONL and collect all file paths that were
    read via Read or code_read_file, plus successful code_find_symbol results."""
    paths: set = set()
    if not transcript_path or not os.path.exists(transcript_path):
        return paths

    try:
        with open(transcript_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except Exception:
                    continue
                # tool_use events can be nested under message.content[].
                # walk the structure to be tolerant of schema variants.
                _collect_tool_paths(event, paths)
    except Exception:
        pass
    return paths


def _collect_tool_paths(node, paths: set):
    if isinstance(node, dict):
        if node.get("type") == "tool_use":
            tool = node.get("name", "")
            inp = node.get("input", {}) or {}
            if tool in ("Read",):
                p = inp.get("file_path") or inp.get("path")
                if p:
                    paths.add(_normalize(p))
            elif tool.endswith("code_read_file") or tool == "code_read_file":
                p = inp.get("path") or inp.get("file_path")
                if p:
                    paths.add(_normalize(p))
            elif tool.endswith("code_find_symbol") or tool == "code_find_symbol":
                # we don't know if it found anything from input alone;
                # tool_result lookup happens below
                pass
        for v in node.values():
            _collect_tool_paths(v, paths)
    elif isinstance(node, list):
        for item in node:
            _collect_tool_paths(item, paths)


def _normalize(path: str) -> str:
    return path.replace("\\", "/").lstrip("./")


def compute_diff(found_files: dict, read_paths: set) -> dict:
    """Return entities whose target file is NOT among read_paths."""
    missing: dict = {}
    read_normalized = {_normalize(p) for p in read_paths}
    for name, path in found_files.items():
        norm = _normalize(path)
        # match if any read path ends with our target or vice versa
        hit = False
        for rp in read_normalized:
            if rp.endswith(norm) or norm.endswith(rp):
                hit = True
                break
        if not hit:
            missing[name] = path
    return missing


def main():
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except Exception as e:
        print(f"spec-coverage-gate: cannot parse stdin payload: {e}", file=sys.stderr)
        sys.exit(0)

    tool_name = payload.get("tool_name", "")
    if tool_name not in ("Write", "Edit"):
        sys.exit(0)

    tool_input = payload.get("tool_input", {}) or {}
    file_path = tool_input.get("file_path") or ""
    if not file_path:
        sys.exit(0)

    config = load_config()
    matchers = config.get("matchers", [])
    skip_paths = config.get("skip_paths", [])

    fp_normalized = file_path.replace("\\", "/")
    if matchers and not matches_any(fp_normalized, matchers):
        sys.exit(0)
    if skip_paths and matches_any(fp_normalized, skip_paths):
        sys.exit(0)

    content = extract_content(tool_name, tool_input)
    if not content.strip():
        sys.exit(0)

    entities = extract_entities(content, config)
    if not entities["classes"] and not entities["migrations"]:
        sys.exit(0)

    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    found = find_entity_files(entities, project_dir, config)
    if not found:
        # Mentioned things, but none of them resolve to local files (all external).
        sys.exit(0)

    transcript_path = (
        payload.get("transcript_path")
        or os.environ.get("CLAUDE_TRANSCRIPT_PATH")
        or ""
    )
    read_paths = collect_read_paths(transcript_path)
    missing = compute_diff(found, read_paths)

    if not missing:
        sys.exit(0)

    lines = ["⛔ Spec coverage gate: следующие сущности упомянуты в спеке, но не верифицированы в этой сессии:"]
    for name, path in sorted(missing.items()):
        lines.append(f"  • {name:<35s} → {path}")
    lines.append("")
    lines.append("Прочитай эти файлы (Read или code_read_file) и попробуй снова.")
    lines.append("Verification-first — про чтение, не про догадку по имени.")
    print("\n".join(lines), file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
