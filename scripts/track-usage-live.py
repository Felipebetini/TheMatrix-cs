#!/usr/bin/env python3
import json, time, sys, os

sid = (os.environ.get('MATRIX_SESSION_ID') or '').strip()
suffix = f'-{sid}' if sid else ''
OUT = os.environ.get('MATRIX_USAGE_LIVE_FILE') or f'/tmp/matrix-usage-live{suffix}.json'

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)


def flatten(obj, prefix=''):
    items = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            p = f'{prefix}.{k}' if prefix else str(k)
            items.update(flatten(v, p))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            p = f'{prefix}[{i}]'
            items.update(flatten(v, p))
    else:
        items[prefix] = obj
    return items


def pick_num(flat, keys):
    for path, val in flat.items():
        low = path.lower()
        if any(k in low for k in keys):
            if isinstance(val, (int, float)):
                return int(val)
            if isinstance(val, str):
                s = val.strip()
                if s.isdigit():
                    return int(s)
    return None

flat = flatten(payload)
input_tokens = pick_num(flat, ['input_tokens', 'prompt_tokens'])
output_tokens = pick_num(flat, ['output_tokens', 'completion_tokens'])
cache_read = pick_num(flat, ['cache_read_tokens'])
cache_write = pick_num(flat, ['cache_write_tokens'])
total_tokens = pick_num(flat, ['total_tokens'])

if total_tokens is None and (input_tokens is not None or output_tokens is not None or cache_read is not None or cache_write is not None):
    total_tokens = (input_tokens or 0) + (output_tokens or 0) + (cache_read or 0) + (cache_write or 0)

if total_tokens is None:
    sys.exit(0)

try:
    state = json.load(open(OUT))
    if not isinstance(state, dict):
        state = {}
except Exception:
    state = {}

state.setdefault('source', 'live_hook')
state.setdefault('started_at', int(time.time()))
state.setdefault('updated_at', int(time.time()))
if sid:
    state['session_id'] = sid
state.setdefault('totals', {
    'input_tokens': 0,
    'output_tokens': 0,
    'cache_read_tokens': 0,
    'cache_write_tokens': 0,
    'total_tokens_including_cache': 0,
})
state.setdefault('timeline', [])

state['totals']['input_tokens'] += int(input_tokens or 0)
state['totals']['output_tokens'] += int(output_tokens or 0)
state['totals']['cache_read_tokens'] += int(cache_read or 0)
state['totals']['cache_write_tokens'] += int(cache_write or 0)
state['totals']['total_tokens_including_cache'] += int(total_tokens or 0)

bucket = int(time.time() // 60 * 60)
added = False
for row in state['timeline']:
    if row.get('ts') == bucket:
        row['tokens'] = int(row.get('tokens', 0)) + int(total_tokens or 0)
        added = True
        break
if not added:
    state['timeline'].append({'ts': bucket, 'tokens': int(total_tokens or 0)})

state['timeline'] = sorted(state['timeline'], key=lambda x: x.get('ts', 0))[-240:]
state['updated_at'] = int(time.time())

with open(OUT, 'w') as f:
    json.dump(state, f)
