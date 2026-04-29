#!/usr/bin/env python3
"""
Synthetic tests for spec-coverage-gate (КТ-1 from the task brief).

Each test sets up a fake project tree with a fake transcript, then invokes
the gate as a subprocess with stdin payload, and asserts on exit code +
stderr.

Run: python tests/test_synthetic.py
"""

import json
import os
import subprocess
import sys
import tempfile
import shutil
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "spec-coverage-gate.py"


def run_gate(payload: dict, project_dir: str, transcript_path: str = "") -> tuple:
    env = os.environ.copy()
    env["CLAUDE_PROJECT_DIR"] = project_dir
    if transcript_path:
        env["CLAUDE_TRANSCRIPT_PATH"] = transcript_path
        payload = {**payload, "transcript_path": transcript_path}
    result = subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env=env,
    )
    return result.returncode, result.stdout, result.stderr


def make_project(files: dict) -> Path:
    root = Path(tempfile.mkdtemp(prefix="spec-gate-"))
    for rel, content in files.items():
        full = root / rel
        full.parent.mkdir(parents=True, exist_ok=True)
        full.write_text(content, encoding="utf-8")
    return root


def make_transcript(events: list) -> str:
    fd, path = tempfile.mkstemp(suffix=".jsonl", prefix="transcript-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        for e in events:
            f.write(json.dumps(e) + "\n")
    return path


def case_1_unread_dto_blocks():
    """Spec mentions SuccessfulJobResponseDTO, transcript empty → exit 2."""
    project = make_project({
        "app/DTO/MyID/Response/SuccessfulJobResponseDTO.php": "<?php class SuccessfulJobResponseDTO {}",
        "app/Services/MyID/MyIDClient.php": "<?php class MyIDClient {}",
    })
    transcript = make_transcript([])
    spec_path = str(project / "epics" / "myid" / "specs" / "01-backend.md")
    spec_content = """# Backend spec

We use SuccessfulJobResponseDTO from MyID integration.
The MyIDClient sends requests.
"""
    payload = {
        "tool_name": "Write",
        "tool_input": {"file_path": spec_path, "content": spec_content},
    }
    rc, _, err = run_gate(payload, str(project), transcript)
    shutil.rmtree(project, ignore_errors=True)
    os.unlink(transcript)
    assert rc == 2, f"expected 2, got {rc}; stderr={err}"
    assert "SuccessfulJobResponseDTO" in err, f"missing entity in stderr: {err}"
    print("✓ case_1_unread_dto_blocks")


def case_2_read_dto_passes():
    """Same spec, but transcript shows Read of the DTO file → exit 0."""
    project = make_project({
        "app/DTO/MyID/Response/SuccessfulJobResponseDTO.php": "<?php class SuccessfulJobResponseDTO {}",
        "app/Services/MyID/MyIDClient.php": "<?php class MyIDClient {}",
    })
    dto_full = str(project / "app" / "DTO" / "MyID" / "Response" / "SuccessfulJobResponseDTO.php")
    client_full = str(project / "app" / "Services" / "MyID" / "MyIDClient.php")
    transcript = make_transcript([
        {"type": "tool_use", "name": "Read", "input": {"file_path": dto_full}},
        {"type": "tool_use", "name": "Read", "input": {"file_path": client_full}},
    ])
    spec_path = str(project / "epics" / "myid" / "specs" / "01-backend.md")
    spec_content = """# Backend spec

We use SuccessfulJobResponseDTO from MyID integration.
The MyIDClient sends requests.
"""
    payload = {
        "tool_name": "Write",
        "tool_input": {"file_path": spec_path, "content": spec_content},
    }
    rc, _, err = run_gate(payload, str(project), transcript)
    shutil.rmtree(project, ignore_errors=True)
    os.unlink(transcript)
    assert rc == 0, f"expected 0, got {rc}; stderr={err}"
    print("✓ case_2_read_dto_passes")


def case_3_external_class_no_false_positive():
    """Spec mentions Stripe\\Customer (no local file) → exit 0 (no false positive)."""
    project = make_project({
        "app/Services/MyService.php": "<?php class MyService {}",
    })
    my_full = str(project / "app" / "Services" / "MyService.php")
    transcript = make_transcript([
        {"type": "tool_use", "name": "Read", "input": {"file_path": my_full}},
    ])
    spec_path = str(project / "epics" / "billing" / "specs" / "01-stripe.md")
    spec_content = """# Stripe integration

We call Stripe\\Customer::create.
The MyService handles persistence.
"""
    payload = {
        "tool_name": "Write",
        "tool_input": {"file_path": spec_path, "content": spec_content},
    }
    rc, _, err = run_gate(payload, str(project), transcript)
    shutil.rmtree(project, ignore_errors=True)
    os.unlink(transcript)
    assert rc == 0, f"expected 0, got {rc}; stderr={err}"
    print("✓ case_3_external_class_no_false_positive")


def case_4_changelog_skipped():
    """README/CHANGELOG with code mentions → exit 0 (path skipped)."""
    project = make_project({
        "app/Services/UnreadService.php": "<?php class UnreadService {}",
    })
    transcript = make_transcript([])
    spec_path = str(project / "CHANGELOG.md")
    spec_content = "## v1.2 — added UnreadService"
    payload = {
        "tool_name": "Write",
        "tool_input": {"file_path": spec_path, "content": spec_content},
    }
    rc, _, err = run_gate(payload, str(project), transcript)
    shutil.rmtree(project, ignore_errors=True)
    os.unlink(transcript)
    assert rc == 0, f"expected 0, got {rc}; stderr={err}"
    print("✓ case_4_changelog_skipped")


def case_5_backticks_prose_codeblock_all_caught():
    """Three mention styles all detected: backticks, plain prose, code block."""
    project = make_project({
        "app/Services/AlphaService.php": "<?php class AlphaService {}",
        "app/Services/BetaService.php": "<?php class BetaService {}",
        "app/Services/GammaService.php": "<?php class GammaService {}",
    })
    transcript = make_transcript([])  # nothing read
    spec_path = str(project / "specs" / "test" / "01-coverage.md")
    spec_content = """# Coverage test

We use `AlphaService` in backticks.
We also rely on BetaService directly in prose.

```php
$service = new GammaService();
```
"""
    payload = {
        "tool_name": "Write",
        "tool_input": {"file_path": spec_path, "content": spec_content},
    }
    rc, _, err = run_gate(payload, str(project), transcript)
    shutil.rmtree(project, ignore_errors=True)
    os.unlink(transcript)
    assert rc == 2, f"expected 2, got {rc}; stderr={err}"
    for name in ("AlphaService", "BetaService", "GammaService"):
        assert name in err, f"missing {name} in stderr: {err}"
    print("✓ case_5_backticks_prose_codeblock_all_caught")


def main():
    cases = [
        case_1_unread_dto_blocks,
        case_2_read_dto_passes,
        case_3_external_class_no_false_positive,
        case_4_changelog_skipped,
        case_5_backticks_prose_codeblock_all_caught,
    ]
    failed = 0
    for c in cases:
        try:
            c()
        except AssertionError as e:
            print(f"✗ {c.__name__}: {e}")
            failed += 1
    print()
    if failed:
        print(f"FAIL: {failed}/{len(cases)} cases")
        sys.exit(1)
    print(f"PASS: {len(cases)}/{len(cases)} cases")


if __name__ == "__main__":
    main()
