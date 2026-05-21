#!/usr/bin/env python3
"""
The Matrix — Dashboard Server
Serves the dashboard on http://localhost:2025
Reads state from /tmp/matrix-state.json and /tmp/matrix-events.jsonl

Usage: python3 scripts/matrix-dashboard.py
"""

import glob
import http.server, json, os, re, sys
from urllib.parse import parse_qs, urlparse

# Import DB module from same scripts/ directory
sys.path.insert(0, os.path.dirname(__file__))
try:
    import matrix_db as mdb
    DB_AVAILABLE = True
except ImportError:
    DB_AVAILABLE = False

PORT      = 2025
STATE     = '/tmp/matrix-state.json'
EVENTS    = '/tmp/matrix-events.jsonl'
USAGE     = '/tmp/matrix-usage.json'
USAGE_HISTORY = '/tmp/matrix-usage-history.json'
USAGE_LIVE = '/tmp/matrix-usage-live.json'
DASHBOARD     = os.path.join(os.path.dirname(__file__), '../dashboard/index.html')
DASHBOARD_DIR = os.path.realpath(os.path.join(os.path.dirname(__file__), '../dashboard'))

STATIC_TYPES = {
    '.css': 'text/css; charset=utf-8',
    '.js':  'application/javascript; charset=utf-8',
}


class Handler(http.server.BaseHTTPRequestHandler):

    def log_message(self, *_): pass  # suppress access logs

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)
        session = (query.get('session') or [None])[0]

        if path in ('/', '/index.html'):
            self._file(DASHBOARD, 'text/html; charset=utf-8')
        elif path == '/api/state':
            self._json(self._state(session))
        elif path == '/api/events':
            self._json(self._events(session))
        elif path == '/api/usage':
            self._json(self._usage())
        elif path == '/api/usage-live':
            self._json(self._usage_live(session))
        elif path == '/api/usage-history':
            self._json(self._usage_history())
        elif path == '/api/sessions':
            self._json(self._sessions())
        elif path == '/api/db/history':
            project = (query.get('project') or [None])[0]
            limit   = int((query.get('limit') or ['10'])[0])
            self._json(mdb.get_history(project=project, limit=limit) if DB_AVAILABLE else [])
        elif path == '/api/db/patterns':
            project = (query.get('project') or [None])[0]
            self._json(mdb.get_patterns(project=project) if DB_AVAILABLE else {})
        elif path == '/api/db/notes':
            project = (query.get('project') or [None])[0]
            self._json(mdb.get_notes(project=project) if DB_AVAILABLE else [])
        else:
            self._static(path)

    # ── helpers ────────────────────────────────────────────────────────────

    def _static(self, url_path):
        ext = os.path.splitext(url_path)[1]
        ct  = STATIC_TYPES.get(ext)
        if not ct:
            self.send_error(404)
            return
        # prevent path traversal
        abs_path = os.path.realpath(os.path.join(DASHBOARD_DIR, url_path.lstrip('/')))
        if not abs_path.startswith(DASHBOARD_DIR + os.sep) and abs_path != DASHBOARD_DIR:
            self.send_error(403)
            return
        self._file(abs_path, ct)

    def _file(self, path, ct):
        try:
            with open(path, 'rb') as f:
                body = f.read()
            self._respond(200, ct, body)
        except FileNotFoundError:
            self.send_error(404)

    def _json(self, data):
        body = json.dumps(data, default=str).encode()
        self._respond(200, 'application/json', body)

    def _respond(self, code, ct, body):
        self.send_response(code)
        self.send_header('Content-Type', ct)
        self.send_header('Content-Length', len(body))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(body)

    def _state(self, session=None):
        state_file, _, _ = self._paths(session)
        try:
            with open(state_file) as f:
                return json.load(f)
        except Exception:
            return {
                'status': 'idle',
                'agent': None,
                'project': None,
                'model': None,
                'tool_calls': 0,
                'gate_e_armed': False,
                'last_tool': None,
                'started_at': None,
            }

    def _events(self, session=None):
        _, events_file, _ = self._paths(session)
        try:
            with open(events_file) as f:
                lines = f.readlines()
            events = []
            for line in reversed(lines):
                line = line.strip()
                if not line:
                    continue
                try:
                    events.append(json.loads(line))
                except Exception:
                    pass
                if len(events) >= 100:
                    break
            return events
        except Exception:
            return []

    def _usage(self):
        try:
            with open(USAGE) as f:
                return json.load(f)
        except Exception:
            return {
                'source': None,
                'totals': None,
                'models': [],
            }

    def _usage_live(self, session=None):
        _, _, usage_live_file = self._paths(session)
        try:
            with open(usage_live_file) as f:
                return json.load(f)
        except Exception:
            return {'source': None, 'totals': None, 'timeline': []}

    def _usage_history(self):
        try:
            with open(USAGE_HISTORY) as f:
                data = json.load(f)
                if isinstance(data, list):
                    return data[-365:]
        except Exception:
            pass
        return []

    def _sanitize_session(self, session):
        if not session:
            return None
        safe = re.sub(r'[^A-Za-z0-9_.-]+', '-', str(session)).strip('-')
        return safe or None

    def _latest_session(self):
        latest = None
        latest_ts = -1
        for path in glob.glob('/tmp/matrix-state-*.json'):
            try:
                with open(path) as f:
                    data = json.load(f)
                ts = int(data.get('started_at') or 0)
                sid = data.get('session_id') or os.path.basename(path)[len('matrix-state-'):-len('.json')]
                if ts >= latest_ts:
                    latest_ts = ts
                    latest = sid
            except Exception:
                pass
        return latest

    def _paths(self, session=None):
        sid = self._sanitize_session(session) or self._latest_session()
        if sid:
            return (
                f'/tmp/matrix-state-{sid}.json',
                f'/tmp/matrix-events-{sid}.jsonl',
                f'/tmp/matrix-usage-live-{sid}.json',
            )
        return (STATE, EVENTS, USAGE_LIVE)

    def _sessions(self):
        items = []
        for path in glob.glob('/tmp/matrix-state-*.json'):
            try:
                with open(path) as f:
                    s = json.load(f)
                sid = s.get('session_id') or os.path.basename(path)[len('matrix-state-'):-len('.json')]
                items.append({
                    'session_id': sid,
                    'agent': s.get('agent'),
                    'project': s.get('project'),
                    'model': s.get('model'),
                    'status': s.get('status'),
                    'started_at': s.get('started_at'),
                })
            except Exception:
                pass
        items.sort(key=lambda x: int(x.get('started_at') or 0), reverse=True)
        return items[:30]


if __name__ == '__main__':
    http.server.ThreadingHTTPServer.allow_reuse_address = True
    server = http.server.ThreadingHTTPServer(('localhost', PORT), Handler)
    print(f'\n  ▶  Matrix dashboard running at http://localhost:{PORT}')
    print(f'     Press Ctrl+C to stop\n')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n  ◼  Dashboard stopped')
        sys.exit(0)
