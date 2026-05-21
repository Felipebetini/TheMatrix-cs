#!/usr/bin/env python3
"""
Matrix DB — SQLite session storage.

Usage:
  python3 scripts/matrix-db.py save <session_id>
  python3 scripts/matrix-db.py history [--project <slug>] [--limit 10]
  python3 scripts/matrix-db.py patterns [--project <slug>]
  python3 scripts/matrix-db.py note <session_id> --signal <signal> --observation <text> --recommendation <text>
"""

import argparse, json, os, re, sqlite3, sys
from datetime import datetime, timezone

DB_PATH    = os.path.realpath(os.path.join(os.path.dirname(__file__), '..', 'data', 'matrix.db'))
VAULT_PATH = os.path.realpath(os.path.join(os.path.dirname(__file__), '..'))

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

CREATE TABLE IF NOT EXISTS projects (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    slug             TEXT UNIQUE NOT NULL,
    project_name     TEXT,
    url              TEXT,
    language         TEXT,
    multisite        INTEGER DEFAULT 0,
    critical_flows   TEXT,
    risk_zones       TEXT,
    primary_playbooks TEXT,
    do_not_touch     TEXT,
    special_notes    TEXT,
    rsi_updated_at   INTEGER,
    first_seen       INTEGER DEFAULT (CAST(strftime('%s','now') AS INTEGER)),
    last_session_at  INTEGER
);

CREATE INDEX IF NOT EXISTS idx_sessions_project    ON sessions(project);
CREATE INDEX IF NOT EXISTS idx_sessions_closed     ON sessions(closed_at);
CREATE INDEX IF NOT EXISTS idx_bn_session          ON bottleneck_snapshots(session_id);
CREATE INDEX IF NOT EXISTS idx_bn_project          ON bottleneck_snapshots(project);
CREATE INDEX IF NOT EXISTS idx_notes_project       ON ai_notes(project);
CREATE INDEX IF NOT EXISTS idx_projects_slug       ON projects(slug);
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

    # Auto-ingest RSI and update last_session_at
    ingest_rsi(project)
    _update_last_session(project, closed_at)

def _update_last_session(slug, ts):
    con = get_db()
    try:
        con.execute("""
            INSERT INTO projects (slug, last_session_at)
            VALUES (?, ?)
            ON CONFLICT(slug) DO UPDATE SET last_session_at=excluded.last_session_at
        """, (slug, ts))
        con.commit()
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

# ── RSI ingestion ─────────────────────────────────────────────────────────────

def _parse_yaml(path):
    """Parse RSI.yaml — tries PyYAML, falls back to a simple line reader."""
    try:
        import yaml
        with open(path) as f:
            return yaml.safe_load(f) or {}
    except ImportError:
        pass
    except Exception:
        return {}
    # Simple fallback parser — handles scalars, booleans, and block lists
    result, current_key = {}, None
    try:
        with open(path) as f:
            for raw in f:
                line = raw.rstrip()
                if not line or line.lstrip().startswith('#'):
                    continue
                if line.startswith(' ') or line.startswith('\t'):
                    # Indented — could be a list item
                    stripped = line.strip()
                    if stripped.startswith('- ') and current_key is not None:
                        item = stripped[2:].strip().strip('"').strip("'")
                        if isinstance(result.get(current_key), list):
                            result[current_key].append(item)
                else:
                    # Top-level key
                    current_key = None
                    if ':' not in line:
                        continue
                    colon = line.index(':')
                    key = line[:colon].strip()
                    val = line[colon+1:].strip().strip('"').strip("'")
                    if val == '' or val.startswith('#'):
                        result[key] = []
                        current_key = key
                    elif val.lower() == 'true':
                        result[key] = True
                    elif val.lower() == 'false':
                        result[key] = False
                    else:
                        result[key] = val
    except Exception:
        pass
    return result

def ingest_rsi(slug, vault_path=None):
    """Read RSI.yaml for a project and upsert into the projects table."""
    vault = vault_path or VAULT_PATH
    rsi_path = os.path.join(vault, 'projects', slug, 'RSI.yaml')
    if not os.path.exists(rsi_path):
        return False

    rsi = _parse_yaml(rsi_path)
    if not rsi:
        return False

    def _str(val):
        """Scalar field — coerce lists to string, None if empty."""
        if isinstance(val, list): return ', '.join(val) if val else None
        return str(val).strip() if val else None

    def _json(val):
        """List field — store as JSON array string."""
        if isinstance(val, list): return json.dumps(val) if val else None
        if val: return json.dumps([str(val)])
        return None

    con = get_db()
    try:
        con.execute("""
            INSERT INTO projects
              (slug, project_name, url, language, multisite,
               critical_flows, risk_zones, primary_playbooks, do_not_touch,
               special_notes, rsi_updated_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(slug) DO UPDATE SET
              project_name=excluded.project_name,
              url=excluded.url, language=excluded.language,
              multisite=excluded.multisite,
              critical_flows=excluded.critical_flows,
              risk_zones=excluded.risk_zones,
              primary_playbooks=excluded.primary_playbooks,
              do_not_touch=excluded.do_not_touch,
              special_notes=excluded.special_notes,
              rsi_updated_at=excluded.rsi_updated_at
        """, (
            slug,
            _str(rsi.get('project_name')),
            _str(rsi.get('url')),
            _str(rsi.get('language')),
            1 if rsi.get('multisite') else 0,
            _json(rsi.get('critical_flows')),
            _json(rsi.get('risk_zones')),
            _json(rsi.get('primary_playbooks')),
            _json(rsi.get('do_not_touch')),
            _json(rsi.get('special_notes')),
            int(datetime.now(timezone.utc).timestamp()),
        ))
        con.commit()
        print(f'[matrix-db] RSI ingested · project={slug}')
        return True
    finally:
        con.close()

def ingest_all_rsi(vault_path=None):
    """Ingest RSI for every project directory that has an RSI.yaml."""
    vault    = vault_path or VAULT_PATH
    proj_dir = os.path.join(vault, 'projects')
    count    = 0
    for slug in sorted(os.listdir(proj_dir)):
        rsi_path = os.path.join(proj_dir, slug, 'RSI.yaml')
        if os.path.exists(rsi_path):
            if ingest_rsi(slug, vault_path=vault):
                count += 1
    print(f'[matrix-db] ingested {count} RSI files')
    return count

# ── Cross-project insights ─────────────────────────────────────────────────────

def get_cross_project_insights():
    con = get_db()
    try:
        total_sessions = con.execute('SELECT COUNT(*) FROM sessions').fetchone()[0]
        total_projects = con.execute('SELECT COUNT(DISTINCT project) FROM sessions').fetchone()[0]

        # Signal heatmap — how often each signal fires across all sessions
        heatmap = con.execute("""
            SELECT
              SUM(CASE WHEN b.doom_loop=1        THEN 1 ELSE 0 END) AS doom_count,
              SUM(CASE WHEN b.rework_files>0     THEN 1 ELSE 0 END) AS rework_count,
              SUM(CASE WHEN b.burn_rate>20000    THEN 1 ELSE 0 END) AS high_burn_count,
              SUM(CASE WHEN b.wait_pct>30        THEN 1 ELSE 0 END) AS high_wait_count,
              SUM(CASE WHEN s.cache_hit_pct<50   THEN 1 ELSE 0 END) AS low_cache_count,
              SUM(CASE WHEN b.read_edit_ratio>10 THEN 1 ELSE 0 END) AS high_ratio_count,
              COUNT(*) AS total
            FROM bottleneck_snapshots b
            JOIN sessions s ON s.session_id=b.session_id
        """).fetchone()

        # Per-project signal summary (top 10 by doom + rework)
        hot_projects = con.execute("""
            SELECT s.project,
              COUNT(*)                        AS sessions,
              SUM(b.doom_loop)               AS doom_total,
              ROUND(AVG(b.rework_files),1)   AS avg_rework,
              ROUND(AVG(b.burn_rate))        AS avg_burn,
              ROUND(AVG(s.cache_hit_pct))    AS avg_cache,
              ROUND(AVG(b.wait_pct))         AS avg_wait
            FROM sessions s
            JOIN bottleneck_snapshots b ON s.session_id=b.session_id
            GROUP BY s.project
            ORDER BY doom_total DESC, avg_rework DESC
            LIMIT 10
        """).fetchall()

        # Cross-project RSI flow correlations
        # Projects that share a critical_flows keyword and have high rework
        flow_rework = con.execute("""
            SELECT p.critical_flows, ROUND(AVG(b.rework_files),1) AS avg_rework, COUNT(*) AS n
            FROM projects p
            JOIN sessions s ON s.project=p.slug
            JOIN bottleneck_snapshots b ON b.session_id=s.session_id
            WHERE p.critical_flows IS NOT NULL
            GROUP BY p.critical_flows
            HAVING n >= 1
            ORDER BY avg_rework DESC
            LIMIT 5
        """).fetchall()

        # Pending AI notes (unapplied)
        pending = con.execute("""
            SELECT project, COUNT(*) AS n
            FROM ai_notes WHERE applied=0
            GROUP BY project ORDER BY n DESC
        """).fetchall()

        return {
            'total_sessions':  total_sessions,
            'total_projects':  total_projects,
            'signal_heatmap':  dict(heatmap) if heatmap else {},
            'hot_projects':    [dict(r) for r in hot_projects],
            'flow_rework':     [dict(r) for r in flow_rework],
            'pending_notes':   [dict(r) for r in pending],
        }
    finally:
        con.close()

# ── AI report ─────────────────────────────────────────────────────────────────

def get_report(project=None):
    """
    Compact, structured report for AI consumption.
    Smith reads this at session start to front-load knowledge.
    """
    con = get_db()
    lines = []
    now   = datetime.now().strftime('%Y-%m-%d %H:%M')

    try:
        header = f'PROJECT: {project}' if project else 'CROSS-PROJECT REPORT'
        lines += [f'=== MATRIX REPORT: {header} ===', f'Generated: {now}', '']

        # ── Session history for this project ──────────────────────────────────
        hist = get_history(project=project, limit=5)
        if hist:
            lines.append(f'SESSION HISTORY (last {len(hist)}):')
            for r in hist:
                ts  = datetime.fromtimestamp(r['closed_at']).strftime('%Y-%m-%d') if r.get('closed_at') else '?'
                tok = f"{round((r.get('total_tokens') or 0)/1000)}k" if r.get('total_tokens') else '—'
                lines.append(
                    f"  {ts}  agent:{r.get('agent','?'):<8} events:{r.get('event_count','?'):<4} "
                    f"tok:{tok:<6} cache:{r.get('cache_hit_pct','?')}%  "
                    f"rework:{r.get('rework_files') or 0}  doom:{r.get('doom_loop') or 0}  "
                    f"wait:{r.get('wait_pct','?')}%"
                )
            lines.append('')
        else:
            lines += ['SESSION HISTORY: no sessions saved yet', '']

        # ── Averages vs cross-project benchmarks ──────────────────────────────
        if project and hist:
            pat = get_patterns(project=project)
            if pat.get(project):
                p = pat[project]
                lines.append('AVERAGES (all sessions for this project):')
                lines.append(f"  tokens: {p.get('avg_tokens','?')}  cache: {p.get('avg_cache_hit_pct','?')}%  "
                             f"burn: {p.get('avg_burn_rate','?')}/min  rework: {p.get('avg_rework','?')}  "
                             f"doom: {p.get('total_doom_loops',0)}  wait: {p.get('avg_wait_pct','?')}%")
                lines.append('')

        # ── Cross-project benchmarks ───────────────────────────────────────────
        global_pat = get_patterns()
        if global_pat:
            all_rework = [v['avg_rework'] for v in global_pat.values() if v.get('avg_rework') is not None]
            all_cache  = [v['avg_cache_hit_pct'] for v in global_pat.values() if v.get('avg_cache_hit_pct') is not None]
            all_doom   = [v['total_doom_loops'] for v in global_pat.values() if v.get('total_doom_loops') is not None]
            if all_rework:
                avg_rework_global = round(sum(all_rework)/len(all_rework), 1)
                avg_cache_global  = round(sum(all_cache)/len(all_cache), 1) if all_cache else None
                avg_doom_global   = round(sum(all_doom)/len(all_doom), 1) if all_doom else 0
                lines.append(f'CROSS-PROJECT BENCHMARKS ({len(global_pat)} projects):')
                lines.append(f'  avg rework:    {avg_rework_global} files/session')
                if avg_cache_global is not None:
                    lines.append(f'  avg cache hit: {avg_cache_global}%')
                lines.append(f'  avg doom loops:{avg_doom_global}/project')
                # Flags for current project
                if project and pat.get(project):
                    p = pat[project]
                    flags = []
                    if (p.get('avg_rework') or 0) > avg_rework_global * 1.5:
                        flags.append(f"⚠ rework ({p['avg_rework']}) above global avg ({avg_rework_global})")
                    if (p.get('avg_cache_hit_pct') or 100) < (avg_cache_global or 100) * 0.8:
                        flags.append(f"⚠ cache hit ({p.get('avg_cache_hit_pct')}%) below global avg ({avg_cache_global}%)")
                    if flags:
                        lines.append('  FLAGS:')
                        for f in flags: lines.append(f'    {f}')
                lines.append('')

        # ── RSI context ────────────────────────────────────────────────────────
        if project:
            row = con.execute('SELECT * FROM projects WHERE slug=?', (project,)).fetchone()
            if row:
                row = dict(row)
                lines.append('PROJECT CONTEXT (from RSI.yaml):')
                if row.get('critical_flows'):
                    flows = json.loads(row['critical_flows'])
                    lines.append(f"  critical flows: {', '.join(flows[:3])}")
                if row.get('risk_zones'):
                    zones = json.loads(row['risk_zones'])
                    lines.append(f"  risk zones:     {', '.join(zones[:2])}")
                if row.get('primary_playbooks'):
                    pbs = json.loads(row['primary_playbooks'])
                    lines.append(f"  playbooks:      {', '.join(pbs)}")
                lines.append('')
            else:
                lines += [f'RSI: not yet ingested — run: matrix_db.py ingest-rsi {project}', '']

        # ── Pending AI recommendations ─────────────────────────────────────────
        notes = get_notes(project=project, unapplied_only=True)
        if notes:
            lines.append(f'PENDING RECOMMENDATIONS ({len(notes)}):')
            for n in notes[:5]:
                ts = datetime.fromtimestamp(n['created_at']).strftime('%Y-%m-%d') if n.get('created_at') else '?'
                lines.append(f"  [{n['id']}] {ts} | signal:{n.get('signal','?')} | {n.get('observation','')[:80]}")
                lines.append(f"       → {n.get('recommendation','')[:100]}")
            lines.append('')
        else:
            lines += ['PENDING RECOMMENDATIONS: none', '']

        # ── Hot signals across all projects ───────────────────────────────────
        insights = get_cross_project_insights()
        hm = insights.get('signal_heatmap', {})
        total = hm.get('total') or 1
        if total > 0:
            lines.append(f'SIGNAL FREQUENCY ACROSS ALL PROJECTS ({insights["total_sessions"]} sessions, {insights["total_projects"]} projects):')
            signals = [
                ('doom loop',   hm.get('doom_count',0)),
                ('rework',      hm.get('rework_count',0)),
                ('high burn',   hm.get('high_burn_count',0)),
                ('high wait',   hm.get('high_wait_count',0)),
                ('low cache',   hm.get('low_cache_count',0)),
                ('high R/E',    hm.get('high_ratio_count',0)),
            ]
            for name, count in sorted(signals, key=lambda x: -x[1]):
                pct = round((count/total)*100)
                bar = '█' * (pct // 10) + '░' * (10 - pct // 10)
                lines.append(f'  {name:<14} {bar} {pct}% ({count}/{total} sessions)')
            lines.append('')

    finally:
        con.close()

    return '\n'.join(lines)

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

    p_rsi = sub.add_parser('ingest-rsi', help='Ingest RSI.yaml for a project (or all projects)')
    p_rsi.add_argument('project', nargs='?', default=None, help='Project slug (omit to ingest all)')

    p_rep = sub.add_parser('report', help='Print AI-readable session + pattern report')
    p_rep.add_argument('--project', default=None)

    p_ins = sub.add_parser('insights', help='Show cross-project signal insights')

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

    elif args.cmd == 'ingest-rsi':
        if args.project:
            ingest_rsi(args.project)
        else:
            ingest_all_rsi()

    elif args.cmd == 'report':
        print(get_report(project=args.project))

    elif args.cmd == 'insights':
        data = get_cross_project_insights()
        print(f"\n  Total sessions: {data['total_sessions']}  Projects: {data['total_projects']}")
        hm = data.get('signal_heatmap', {})
        total = hm.get('total') or 1
        print('\n  Signal frequency:')
        for sig, key in [('Doom Loop','doom_count'),('Rework','rework_count'),
                         ('High Burn','high_burn_count'),('High Wait','high_wait_count'),
                         ('Low Cache','low_cache_count'),('High R/E','high_ratio_count')]:
            n = hm.get(key, 0)
            print(f'    {sig:<14} {round((n/total)*100):>3}%  ({n}/{total})')
        if data.get('hot_projects'):
            print('\n  Hot projects (doom + rework):')
            for p in data['hot_projects'][:5]:
                print(f"    {p['project']:<20} sessions:{p['sessions']}  doom:{p['doom_total']}  rework:{p['avg_rework']}")
        if data.get('pending_notes'):
            print('\n  Pending recommendations:')
            for n in data['pending_notes']:
                print(f"    {n['project']}: {n['n']} unapplied note(s)")
        print()

    else:
        parser.print_help()
