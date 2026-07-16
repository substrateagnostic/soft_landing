#!/usr/bin/env python3
"""rig_forge.py — Meshy rigging + animation batch driver for THE BIG NAP.

D19 (DIRECTION_V2): characters are rigged and animated. This drives the
Meshy OpenAPI rigging endpoint against the original text-to-3d refine tasks
(recovered task ids below), then applies a curated kid-register clip set
from the public 680-entry animation library (action ids verified against
https://api.meshy.ai/web/public/animations/resources on 2026-07-16).

Outputs (downloaded immediately — Meshy retains task assets only 3 days):
  assets/models/meshy/rigged/<char>/rigged.glb        (skinned character)
  assets/models/meshy/rigged/<char>/anim_<name>.glb   (rig + one clip each)
  tools/meshy/rig_report.json                          (receipt, no key)

The API key is read from .env at runtime and never written to any file,
log, or report. Resume-safe: existing output files are skipped.

Usage: python tools/meshy/rig_forge.py [--dry-run]
"""
from __future__ import annotations

import json
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT_BASE = ROOT / "assets" / "models" / "meshy" / "rigged"
REPORT_PATH = ROOT / "tools" / "meshy" / "rig_report.json"
BASE = "https://api.meshy.ai/openapi/v1"

# Refine task ids. v1 (kept for provenance, superseded by D24 likeness):
#   pip  019f69c2-d1a4-772f-8358-6cf526baaa81  (h 0.9)
#   otto 019f69d1-8fa0-7647-b756-bc2dfca1dd69  (h 1.3)
# v2 = D24 likeness casting (Pip=Ezra, Otto=Caleb, heights 0.9/0.8).
CHARACTERS = {
    # pip_v2 019f6cc0-bc90-7747-82f4-f0ae8e359031 (h 0.9) / otto_v2
    # 019f6cc0-bf13-7bf3-a486-3f4bea3cf8e6 (h 0.8) — rigged, on disk.
    # M2 dreamkeepers (moth's wings are a humanoid-rigger risk — 5cr gamble):
    "lamb_keeper": {"input_task_id": "019f6d0d-12fd-7229-8af4-f0769a2ab2b8", "height_meters": 0.85},
    "moth_shepherd": {"input_task_id": "019f6d0d-15bd-722a-b2e8-d5541787c4ac", "height_meters": 1.0},
}

# Shared clip set (name -> action_id). Kid register only — no combat clips.
# (Players' full set — idle 0, walk 30, run 15, fall 503, wave 28, cheer
# 303, pickup 276, sleep 269, dance 64; pip jump 44/skip 118, otto jump
# 61/carry 551 — already rigged. Dreamkeepers get the NPC subset.)
SHARED_CLIPS = {
    "idle": 0,             # Idle
    "walk": 30,            # Casual Walk
    "wave": 28,            # Big Wave Hello
    "sleep": 269,          # Sleep
    "cheer": 303,          # Cheer with Both Hands
}
PER_CHAR_CLIPS = {}

POLL_INTERVAL = 10.0
POLL_TIMEOUT = 1200.0
MAX_IN_FLIGHT = 8  # stay under the paid-tier queued-task cap


def _load_key() -> str:
    for line in (ROOT / ".env").read_text().splitlines():
        if line.startswith("MESHY_API_KEY="):
            return line.split("=", 1)[1].strip()
    sys.exit("MESHY_API_KEY not found in .env")


def _req(method: str, url: str, key: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("Authorization", f"Bearer {key}")
    if data:
        r.add_header("Content-Type", "application/json")
    for attempt in range(4):
        try:
            with urllib.request.urlopen(r, timeout=60) as resp:
                return json.loads(resp.read().decode())
        except Exception as e:  # noqa: BLE001 — retry then surface
            if attempt == 3:
                raise
            print(f"  retry {attempt + 1} after error: {e}", flush=True)
            time.sleep(5 * (attempt + 1))
    raise RuntimeError("unreachable")


def _download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(url, dest)
    print(f"  downloaded {dest.relative_to(ROOT)} ({dest.stat().st_size // 1024} KB)", flush=True)


def _poll(kind: str, task_id: str, key: str) -> dict:
    deadline = time.time() + POLL_TIMEOUT
    while time.time() < deadline:
        t = _req("GET", f"{BASE}/{kind}/{task_id}", key)
        status = t.get("status")
        if status in ("SUCCEEDED", "FAILED", "CANCELED"):
            return t
        print(f"  {kind} {task_id[:13]} {status} {t.get('progress', '?')}%", flush=True)
        time.sleep(POLL_INTERVAL)
    return {"status": "TIMEOUT", "id": task_id}


def main() -> None:
    dry = "--dry-run" in sys.argv
    key = _load_key()
    report: dict = {"characters": {}, "credits_spent": 0}
    bal = _req("GET", f"{BASE}/balance", key)
    report["balance_before"] = bal.get("balance")
    print(f"balance before: {bal.get('balance')}", flush=True)

    plan = {
        c: dict(SHARED_CLIPS, **PER_CHAR_CLIPS.get(c, {})) for c in CHARACTERS
    }
    total_clips = sum(len(v) for v in plan.values())
    print(f"plan: {len(CHARACTERS)} rigs + {total_clips} clips "
          f"(~{5 * len(CHARACTERS) + 3 * total_clips} credits)", flush=True)
    if dry:
        print(json.dumps(plan, indent=2))
        return

    # Phase 1 — rig both characters (parallel submit, then poll).
    rig_tasks: dict[str, str] = {}
    for char, cfg in CHARACTERS.items():
        rep = report["characters"].setdefault(char, {"clips": {}})
        rigged_glb = OUT_BASE / char / "rigged.glb"
        prior = _prior_rig_task(char)
        if rigged_glb.exists() and prior:
            print(f"[{char}] rigged.glb exists — reusing rig task {prior}", flush=True)
            rep["rig_task"] = prior
            rep["rig_status"] = "SUCCEEDED (resumed)"
            rig_tasks[char] = prior
            continue
        resp = _req("POST", f"{BASE}/rigging", key, {
            "input_task_id": cfg["input_task_id"],
            "height_meters": cfg["height_meters"],
        })
        rig_tasks[char] = resp["result"]
        rep["rig_task"] = resp["result"]
        print(f"[{char}] rigging submitted: {resp['result']}", flush=True)

    for char, task_id in rig_tasks.items():
        rep = report["characters"][char]
        if str(rep.get("rig_status", "")).startswith("SUCCEEDED"):
            continue
        t = _poll("rigging", task_id, key)
        rep["rig_status"] = t.get("status")
        if t.get("status") != "SUCCEEDED":
            rep["error"] = json.dumps(t.get("task_error", t.get("error", "")))[:300]
            print(f"[{char}] RIGGING {t.get('status')}", flush=True)
            continue
        res = t.get("result", {})
        url = res.get("rigged_character_glb_url")
        if url:
            _download(url, OUT_BASE / char / "rigged.glb")
        basics = res.get("basic_animations", {}) or {}
        for bname in ("walking", "running"):
            burl = basics.get(f"{bname}_glb_url") or basics.get(bname, {}).get("glb_url") if isinstance(basics.get(bname), dict) else basics.get(f"{bname}_glb_url")
            if burl:
                _download(burl, OUT_BASE / char / f"anim_basic_{bname}.glb")
        _save(report)

    # Phase 2 — animation clips, MAX_IN_FLIGHT at a time across characters.
    queue: list[tuple[str, str, int]] = []
    for char, clips in plan.items():
        rep = report["characters"][char]
        if not str(rep.get("rig_status", "")).startswith("SUCCEEDED"):
            print(f"[{char}] skipping clips — rig not SUCCEEDED", flush=True)
            continue
        for name, action_id in clips.items():
            dest = OUT_BASE / char / f"anim_{name}.glb"
            if dest.exists():
                rep["clips"][name] = {"status": "SUCCEEDED (resumed)", "glb": str(dest.relative_to(ROOT))}
                continue
            queue.append((char, name, action_id))

    in_flight: list[tuple[str, str, str]] = []  # (char, name, task_id)
    while queue or in_flight:
        while queue and len(in_flight) < MAX_IN_FLIGHT:
            char, name, action_id = queue.pop(0)
            resp = _req("POST", f"{BASE}/animations", key, {
                "rig_task_id": rig_tasks[char],
                "action_id": action_id,
            })
            in_flight.append((char, name, resp["result"]))
            print(f"[{char}] clip '{name}' (action {action_id}) submitted: {resp['result'][:13]}", flush=True)
        time.sleep(POLL_INTERVAL)
        still: list[tuple[str, str, str]] = []
        for char, name, task_id in in_flight:
            t = _req("GET", f"{BASE}/animations/{task_id}", key)
            status = t.get("status")
            if status in ("SUCCEEDED", "FAILED", "CANCELED"):
                rep = report["characters"][char]
                entry = {"task": task_id, "status": status,
                         "credits": t.get("consumed_credits", 3)}
                if status == "SUCCEEDED":
                    url = (t.get("result", {}) or {}).get("animation_glb_url")
                    if url:
                        dest = OUT_BASE / char / f"anim_{name}.glb"
                        _download(url, dest)
                        entry["glb"] = str(dest.relative_to(ROOT))
                else:
                    entry["error"] = json.dumps(t.get("task_error", ""))[:300]
                    print(f"[{char}] clip '{name}' {status}", flush=True)
                rep["clips"][name] = entry
                _save(report)
            else:
                still.append((char, name, task_id))
        in_flight = still

    bal2 = _req("GET", f"{BASE}/balance", key)
    report["balance_after"] = bal2.get("balance")
    report["credits_spent"] = (report.get("balance_before") or 0) - (bal2.get("balance") or 0)
    _save(report)
    print(f"balance after: {bal2.get('balance')} "
          f"(spent {report['credits_spent']})", flush=True)
    print("RIG_FORGE_DONE", flush=True)


def _prior_rig_task(char: str) -> str | None:
    if REPORT_PATH.exists():
        try:
            prior = json.loads(REPORT_PATH.read_text())
            return prior.get("characters", {}).get(char, {}).get("rig_task")
        except Exception:  # noqa: BLE001
            return None
    return None


def _save(report: dict) -> None:
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
