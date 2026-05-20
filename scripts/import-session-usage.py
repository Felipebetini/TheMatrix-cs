#!/usr/bin/env python3
"""
Import Claude session usage summary text from stdin and write /tmp/matrix-usage.json.

Usage:
  pbpaste | ./scripts/import-session-usage.py
  cat usage.txt | ./scripts/import-session-usage.py
"""

import json
import re
import sys
import time

OUT = "/tmp/matrix-usage.json"
HISTORY = "/tmp/matrix-usage-history.json"


def parse_num(value):
    s = value.strip().lower().replace(",", "")
    mult = 1
    if s.endswith("k"):
        mult = 1000
        s = s[:-1]
    elif s.endswith("m"):
        mult = 1000000
        s = s[:-1]
    return int(float(s) * mult)


def main():
    text = sys.stdin.read()
    if not text.strip():
        print("No input received on stdin.", file=sys.stderr)
        return 1

    cost = None
    m = re.search(r"Total cost:\s*\$\s*([0-9]+(?:\.[0-9]+)?)", text, re.I)
    if m:
        cost = float(m.group(1))

    api_duration = None
    m = re.search(r"Total duration \(API\):\s*([^\n]+)", text, re.I)
    if m:
        api_duration = m.group(1).strip()

    wall_duration = None
    m = re.search(r"Total duration \(wall\):\s*([^\n]+)", text, re.I)
    if m:
        wall_duration = m.group(1).strip()

    models = []
    pattern = re.compile(
        r"^\s*([A-Za-z0-9._:-]+):\s*([0-9.,]+[km]?)\s+input,\s*([0-9.,]+[km]?)\s+output,\s*"
        r"([0-9.,]+[km]?)\s+cache read,\s*([0-9.,]+[km]?)\s+cache write\s*\(\$([0-9.]+)\)",
        re.I,
    )
    for line in text.splitlines():
        mm = pattern.search(line)
        if not mm:
            continue
        model = mm.group(1)
        input_tokens = parse_num(mm.group(2))
        output_tokens = parse_num(mm.group(3))
        cache_read_tokens = parse_num(mm.group(4))
        cache_write_tokens = parse_num(mm.group(5))
        cost_usd = float(mm.group(6))
        models.append(
            {
                "model": model,
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
                "cache_read_tokens": cache_read_tokens,
                "cache_write_tokens": cache_write_tokens,
                "cost_usd": cost_usd,
                "total_tokens_including_cache": (
                    input_tokens + output_tokens + cache_read_tokens + cache_write_tokens
                ),
            }
        )

    totals = {
        "input_tokens": sum(m["input_tokens"] for m in models),
        "output_tokens": sum(m["output_tokens"] for m in models),
        "cache_read_tokens": sum(m["cache_read_tokens"] for m in models),
        "cache_write_tokens": sum(m["cache_write_tokens"] for m in models),
    }
    totals["total_tokens_including_cache"] = sum(totals.values())

    out = {
        "source": "manual_session_report",
        "captured_at": int(time.time()),
        "total_cost_usd": cost,
        "total_duration_api": api_duration,
        "total_duration_wall": wall_duration,
        "models": models,
        "totals": totals,
    }

    with open(OUT, "w") as f:
        json.dump(out, f)

    day_key = time.strftime("%Y-%m-%d", time.localtime(out["captured_at"]))
    history = []
    try:
        with open(HISTORY) as f:
            history = json.load(f)
            if not isinstance(history, list):
                history = []
    except Exception:
        history = []

    history.append(
        {
            "day": day_key,
            "captured_at": out["captured_at"],
            "total_tokens_including_cache": totals["total_tokens_including_cache"],
            "total_cost_usd": cost,
            "models": [
                {
                    "model": x["model"],
                    "total_tokens_including_cache": x["total_tokens_including_cache"],
                }
                for x in models
            ],
        }
    )
    history = sorted(history, key=lambda x: x.get("captured_at", 0))
    history = history[-365:]
    with open(HISTORY, "w") as f:
        json.dump(history, f)

    print(f"Wrote {OUT}")
    print(f"Wrote {HISTORY}")
    print(
        f"Totals: {totals['total_tokens_including_cache']} tokens "
        f"(input {totals['input_tokens']}, output {totals['output_tokens']}, "
        f"cache read {totals['cache_read_tokens']}, cache write {totals['cache_write_tokens']})"
    )
    if cost is not None:
        print(f"Cost: ${cost:.4f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
