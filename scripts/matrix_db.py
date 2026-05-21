#!/usr/bin/env python3
"""
Matrix DB — SQLite session storage.

Usage:
  python3 scripts/matrix-db.py save <session_id>
  python3 scripts/matrix-db.py history [--project <slug>] [--limit 10]
  python3 scripts/matrix-db.py patterns [--project <slug>]
  python3 scripts/matrix-db.py note <session_id> --signal <signal> --observation <text> --recommendation <text>
"""

import argparse, json, math, os, re, sqlite3, sys
from datetime import datetime, timezone

DB_PATH = os.path.realpath(os.path.join(os.path.dirname(__file__), '..', 'data', 'matrix.db'))

# ── Schema ────────────────────────────────────────────────────────────────────

SCHEMA = """
CREATE TABLE IF NOT EXISTS sessions (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id    TEXT UNIQUE NOT NULL,
    project       TEXT,
    agent         TEXT,
    model         TEXT,
    started_at    INTEGER,
    closed_at     INTEGER,
    duration_min  REAL,
    tool_calls    INTEGER,
    event_count   INTEGER,
    total_tokens  INTEGER,
    input_tokens  INTEGER,
    output_tokens INTEGER,
    cache_read    INTEGER,
    cache_write   INTEGER,
    cache_hit_pct INTEGER
);

CREATE TABLE IF NOT EXISTS bottleneck_snapshots (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id       TEXT NOT NULL REFERENCES sessions(session_id),
    project          TEXT,
    captured_at      INTEGER,
    top_stage        TEXT,
    top_stage_min    REAL,
    wait_pct         INTEGER,
    rework_files     INTEGER,
    total_edit_files INTEGER,
    doom_loop        INTEGER DEFAULT 0,
    doom_loop_detail TEXT,
    read_count       INTEGER,
    edit_count       INTEGER,
    read_edit_ratio  REAL,
    burn_rate        INTEGER,
    verify_count     INTEGER,
    verify_friction  INTEGER,
    tool_hotspot     TEXT,
    tool_hotspot_n   INTEGER,
    blocked_signals  INTEGER,
    context_pressure INTEGER
);

CREATE TABLE IF NOT EXISTS ai_notes (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id     TEXT,
    project        TEXT,
    created_at     INTEGER DEFAULT (CAST(strftime('%s','now') AS INTEGER)),
    signal         TEXT,
    observation    TEXT,
    recommendation TEXT,
    applied        INTEGER DEFAULT 0,
    applied_at     INTEGER,
    result         TEXT
);

CREATE INDEX IF NOT EXISTS idx_sessions_project    ON sessions(project);
CREATE INDEX IF NOT EXISTS idx_sessions_closed     ON sessions(closed_at);
CREATE INDEX IF NOT EXISTS idx_bn_session          ON bottleneck_snapshots(session_id);
CREATE INDEX IF NOT EXISTS idx_bn_project          ON bottleneck_snapshots(project);
CREATE INDEX IF NOT EXISTS idx_notes_project       ON ai_notes(project);
"""

# ── Connection ────────────────────────────────────────────────────────────────

def get_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    con.executescript(SCHEMA)
    con.commit()
    return con

# ── Signal computation (mirrors components/bottleneck.js) ─────────────────────

def _infer_stage(tool, target):
    t = (tool or '').lower()
    x = (target or '').lower()
    if any(k in x for k in ('approved', 'waiting for', 'brief ready')): return 'waiting_approval'
    if 'seraph' in x:                                                     return 'seraph'
    if any(k in x for k in ('verify', 'fixed_when', 'curl', 'playwright')): return 'verify'
    if t in ('edit', 'write'):                                            return 'implement'
    if t == 'agent' and any(k in x for k in ('implementer', 'reviewer', 'security')): return 'implement'
    if t in ('read', 'search'):                                           return 'intake'
    return 'investigation'

def compute_signals(events, usage_live=None):
    # Sort chronologically ascending, take last 120 — ensures ts deltas are positive
    recent = sorted(events, key=lambda e: e.get('ts', 0))[-120:]
    if not recent:
        return {}

    stage_sec, tool_count = {}, {}
    wait_sec = work_sec = 0
    verify_count = verify_fail = blocked = 0

    for i, e in enumerate(recent):
        nxt   = recent[i+1] if i+1 < len(recent) else None
        stage = _infer_stage(e.get('tool'), e.get('target'))
        dt    = max(1, nxt['ts'] - e['ts']) if nxt else 2
        stage_sec[stage] = stage_sec.get(stage, 0) + dt
        if stage == 'waiting_approval': wait_sec += dt
        else:                           work_sec += dt

        tk = (e.get('tool') or 'other').upper()
        tool_count[tk] = tool_count.get(tk, 0) + 1

        tgt = (e.get('target') or '').lower()
        if 'verify' in tgt or 'fixed_when' in tgt:  verify_count += 1
        if any(k in tgt for k in ('no match', 'doom loop', 'investigation stall')): verify_fail += 1
        if any(k in tgt for k in ('waiting', 'stall', 'doom loop')): blocked += 1

    # Stage
    top_stage = max(stage_sec, key=stage_sec.get) if stage_sec else None
    top_stage_min = round(stage_sec[top_stage] / 60, 1) if top_stage else 0

    # Wait/work
    total_ww = max(1, wait_sec + work_sec)
    wait_pct  = round((wait_sec / total_ww) * 100)

    # Verify friction
    vf = round((verify_fail / verify_count) * 100) if verify_count else 0

    # Tool hotspot
    top_tool   = max(tool_count, key=tool_count.get) if tool_count else None
    top_tool_n = tool_count.get(top_tool, 0)

    # Rework
    edit_paths = {}
    for e in recent:
        if (e.get('tool') or '').lower() in ('edit', 'write'):
            p = e.get('target') or ''
            edit_paths[p] = edit_paths.get(p, 0) + 1
    total_edit_files = len(edit_paths)
    rework_files = sum(1 for n in edit_paths.values() if n > 1)

    # Doom loop (last 20)
    loop_count = {}
    for e in recent[-20:]:
        k = f"{(e.get('tool') or '').upper()}:{(e.get('target') or '')[:60]}"
        loop_count[k] = loop_count.get(k, 0) + 1
    top_loop = max(loop_count, key=loop_count.get) if loop_count else None
    doom = loop_count.get(top_loop, 0) >= 3 if top_loop else False
    doom_detail = top_loop if doom else None

    # Read/edit
    read_count = sum(1 for e in recent if (e.get('tool') or '').lower() == 'read')
    edit_count = sum(1 for e in recent if (e.get('tool') or '').lower() in ('edit', 'write'))
    ratio      = round(read_count / edit_count, 1) if edit_count else None

    # Burn rate
    tok_events = [e for e in recent if int(e.get('total_tokens') or e.get('estimated_tokens') or 0) > 0]
    burn_rate = None
    if len(tok_events) >= 2:
        span   = max(1, tok_events[-1]['ts'] - tok_events[0]['ts'])
        total  = sum(int(e.get('total_tokens') or e.get('estimated_tokens') or 0) for e in tok_events)
        burn_rate = round((total / span) * 60)

    # Cache hit
    cache_hit_pct = None
    lt = (usage_live or {}).get('totals') or {}
    if lt.get('input_tokens') or lt.get('cache_read_tokens'):
        eligible      = int(lt.get('input_tokens', 0)) + int(lt.get('cache_read_tokens', 0))
        cache_hit_pct = round((int(lt.get('cache_read_tokens', 0)) / eligible) * 100) if eligible else 0

    return {
        'top_stage':       top_stage.replace('_', ' ') if top_stage else None,
        'top_stage_min':   top_stage_min,
        'wait_pct':        wait_pct,
        'rework_files':    rework_files,
        'total_edit_files':total_edit_files,
        'doom_loop':       1 if doom else 0,
        'doom_loop_detail':doom_detail,
        'read_count':      read_count,
        'edit_count':      edit_count,
        'read_edit_ratio': ratio,
        'burn_rate':       burn_rate,
        'verify_count':    verify_count,
        'verify_friction': vf,
        'tool_hotspot':    top_tool,
        'tool_hotspot_n':  top_tool_n,
        'blocked_signals': blocked,
        'context_pressure':len(events),
    }

# ── Write ─────────────────────────────────────────────────────────────────────

def save_session(session_id):
    """Read /tmp session files, compute signals, write to DB."""
    def _read_json(path, default):
        try:
            with open(path) as f: return json.load(f)
        except Exception: return default

    def _read_jsonl(path):
        rows = []
        try:
            with open(path) as f:
                for line in f:
                    line = line.strip()
                    if line:
                        try: rows.append(json.loads(line))
                        except Exception: pass
        except Exception: pass
        return rows

    sid      = re.sub(r'[^A-Za-z0-9_.-]+', '-', str(session_id)).strip('-')
    state    = _read_json(f'/tmp/matrix-state-{sid}.json',      {})
    events   = _read_jsonl(f'/tmp/matrix-events-{sid}.jsonl')
    ul       = _read_json(f'/tmp/matrix-usage-live-{sid}.json', {})
    lt       = (ul.get('totals') or {})

    project    = state.get('project') or 'unknown'
    started_at = int(state.get('started_at') or 0)
    closed_at  = int(datetime.now(timezone.utc).timestamp())
    dur_min    = round((closed_at - started_at) / 60, 1) if started_at else None

    total_tok  = int(lt.get('total_tokens_including_cache') or 0)
    cache_r    = int(lt.get('cache_read_tokens') or 0)
    eligible   = int(lt.get('input_tokens', 0)) + cache_r
    cache_pct  = round((cache_r / eligible) * 100) if eligible else None

    signals = compute_signals(events, ul)

    con = get_db()
    try:
        con.execute("""
            INSERT INTO sessions
              (session_id, project, agent, model, started_at, closed_at, duration_min,
               tool_calls, event_count, total_tokens, input_tokens, output_tokens,
               cache_read, cache_write, cache_hit_pct)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(session_id) DO UPDATE SET
              closed_at=excluded.closed_at, duration_min=excluded.duration_min,
              tool_calls=excluded.tool_calls, event_count=excluded.event_count,
              total_tokens=excluded.total_tokens, cache_hit_pct=excluded.cache_hit_pct
        """, (
            sid, project, state.get('agent'), state.get('model'),
            started_at, closed_at, dur_min,
            int(state.get('tool_calls') or 0), len(events),
            total_tok,
            int(lt.get('input_tokens') or 0),
            int(lt.get('output_tokens') or 0),
            cache_r,
            int(lt.get('cache_write_tokens') or 0),
            cache_pct,
        ))

        if signals:
            con.execute("""
                INSERT INTO bottleneck_snapshots
                  (session_id, project, captured_at, top_stage, top_stage_min, wait_pct,
                   rework_files, total_edit_files, doom_loop, doom_loop_detail,
                   read_count, edit_count, read_edit_ratio, burn_rate,
                   verify_count, verify_friction, tool_hotspot, tool_hotspot_n,
                   blocked_signals, context_pressure)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, (
                sid, project, closed_at,
                signals.get('top_stage'), signals.get('top_stage_min'), signals.get('wait_pct'),
                signals.get('rework_files'), signals.get('total_edit_files'),
                signals.get('doom_loop'), signals.get('doom_loop_detail'),
                signals.get('read_count'), signals.get('edit_count'), signals.get('read_edit_ratio'),
                signals.get('burn_rate'),
                signals.get('verify_count'), signals.get('verify_friction'),
                signals.get('tool_hotspot'), signals.get('tool_hotspot_n'),
                signals.get('blocked_signals'), signals.get('context_pressure'),
            ))

        con.commit()
        print(f'[matrix-db] saved session {sid} · project={project} · {len(events)} events')
    finally:
        con.close()

def save_note(session_id, signal, observation, recommendation):
    sid = re.sub(r'[^A-Za-z0-9_.-]+', '-', str(session_id)).strip('-')
    con = get_db()
    try:
        row = con.execute('SELECT project FROM sessions WHERE session_id=?', (sid,)).fetchone()
        project = row['project'] if row else None
        con.execute("""
            INSERT INTO ai_notes (session_id, project, signal, observation, recommendation)
            VALUES (?,?,?,?,?)
        """, (sid, project, signal, observation, recommendation))
        con.commit()
        print(f'[matrix-db] note saved · session={sid} · signal={signal}')
    finally:
        con.close()

# ── Read ──────────────────────────────────────────────────────────────────────

def get_history(project=None, limit=10):
    con = get_db()
    try:
        q  = "SELECT s.*, b.* FROM sessions s LEFT JOIN bottleneck_snapshots b ON s.session_id=b.session_id"
        args = []
        if project:
            q += " WHERE s.project=?"
            args.append(project)
        q += " ORDER BY s.closed_at DESC LIMIT ?"
        args.append(limit)
        rows = con.execute(q, args).fetchall()
        return [dict(r) for r in rows]
    finally:
        con.close()

def get_patterns(project=None):
    con = get_db()
    try:
        q    = "SELECT project FROM sessions"
        args = []
        if project:
            q += " WHERE project=?"
            args.append(project)
        q += " GROUP BY project HAVING COUNT(*) > 0"
        projects = [r['project'] for r in con.execute(q, args).fetchall()]
        result = {}
        for p in projects:
            rows = con.execute("""
                SELECT
                  COUNT(*)                        AS session_count,
                  ROUND(AVG(duration_min), 1)     AS avg_duration_min,
                  ROUND(AVG(total_tokens))        AS avg_tokens,
                  ROUND(AVG(cache_hit_pct))       AS avg_cache_hit_pct,
                  ROUND(AVG(b.rework_files), 1)   AS avg_rework,
                  ROUND(AVG(b.burn_rate))         AS avg_burn_rate,
                  ROUND(AVG(b.wait_pct))          AS avg_wait_pct,
                  SUM(b.doom_loop)                AS total_doom_loops,
                  ROUND(AVG(b.read_edit_ratio),1) AS avg_read_edit_ratio,
                  ROUND(AVG(b.context_pressure))  AS avg_event_count
                FROM sessions s
                LEFT JOIN bottleneck_snapshots b ON s.session_id=b.session_id
                WHERE s.project=?
            """, (p,)).fetchone()
            top_hotspot = con.execute("""
                SELECT tool_hotspot, COUNT(*) n
                FROM bottleneck_snapshots
                WHERE project=? AND tool_hotspot IS NOT NULL
                GROUP BY tool_hotspot ORDER BY n DESC LIMIT 1
            """, (p,)).fetchone()
            models = con.execute("""
                SELECT model, COUNT(*) n,
                       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 0) AS pct
                FROM sessions
                WHERE project=? AND model IS NOT NULL
                GROUP BY model ORDER BY n DESC
            """, (p,)).fetchall()
            model_breakdown = ' · '.join(
                f"{r['model']} ({int(r['pct'])}%)" for r in models
            ) if models else None
            result[p] = {
                **dict(rows),
                'top_hotspot':      top_hotspot['tool_hotspot'] if top_hotspot else None,
                'model_breakdown':  model_breakdown,
            }
        return result
    finally:
        con.close()

def get_notes(project=None, unapplied_only=False):
    con = get_db()
    try:
        q = "SELECT * FROM ai_notes"
        clauses, args = [], []
        if project:
            clauses.append("project=?"); args.append(project)
        if unapplied_only:
            clauses.append("applied=0")
        if clauses:
            q += " WHERE " + " AND ".join(clauses)
        q += " ORDER BY created_at DESC LIMIT 50"
        return [dict(r) for r in con.execute(q, args).fetchall()]
    finally:
        con.close()

# ── CLI ───────────────────────────────────────────────────────────────────────

def _fmt_row(r):
    ts  = datetime.fromtimestamp(r.get('closed_at') or 0).strftime('%Y-%m-%d %H:%M') if r.get('closed_at') else '—'
    tok = f"{round((r.get('total_tokens') or 0)/1000)}k" if r.get('total_tokens') else '—'
    return (f"  {ts}  {str(r.get('project') or '?'):<16} {str(r.get('agent') or '?'):<8} "
            f"events={r.get('event_count') or '?'}  tokens={tok}  "
            f"rework={r.get('rework_files') or 0}  doom={r.get('doom_loop') or 0}  "
            f"wait={r.get('wait_pct') or '?'}%")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Matrix DB CLI')
    sub = parser.add_subparsers(dest='cmd')

    p_save = sub.add_parser('save', help='Save a session to DB')
    p_save.add_argument('session_id')

    p_hist = sub.add_parser('history', help='Show recent sessions')
    p_hist.add_argument('--project', default=None)
    p_hist.add_argument('--limit',   type=int, default=10)

    p_pat = sub.add_parser('patterns', help='Show aggregated patterns per project')
    p_pat.add_argument('--project', default=None)

    p_note = sub.add_parser('note', help='Save an AI recommendation note')
    p_note.add_argument('session_id')
    p_note.add_argument('--signal',         required=True)
    p_note.add_argument('--observation',    required=True)
    p_note.add_argument('--recommendation', required=True)

    args = parser.parse_args()

    if args.cmd == 'save':
        save_session(args.session_id)

    elif args.cmd == 'history':
        rows = get_history(project=args.project, limit=args.limit)
        if not rows:
            print('No sessions found.')
        else:
            print(f'\n  {"DATE":<16} {"PROJECT":<16} {"AGENT":<8} SIGNALS')
            print('  ' + '─' * 70)
            for r in rows: print(_fmt_row(r))
            print()

    elif args.cmd == 'patterns':
        data = get_patterns(project=args.project)
        if not data:
            print('No data yet.')
        else:
            for proj, p in data.items():
                print(f'\n  ── {proj} ({p["session_count"]} sessions) ──')
                print(f'     avg duration : {p["avg_duration_min"]}min')
                print(f'     avg tokens   : {p["avg_tokens"]}')
                print(f'     cache hit    : {p["avg_cache_hit_pct"]}%')
                print(f'     avg rework   : {p["avg_rework"]} files')
                print(f'     avg burn rate: {p["avg_burn_rate"]} tok/min')
                print(f'     avg wait     : {p["avg_wait_pct"]}%')
                print(f'     doom loops   : {p["total_doom_loops"]} total')
                print(f'     read/edit    : {p["avg_read_edit_ratio"]}:1')
                print(f'     top hotspot  : {p["top_hotspot"]}')
            print()

    elif args.cmd == 'note':
        save_note(args.session_id, args.signal, args.observation, args.recommendation)

    else:
        parser.print_help()
