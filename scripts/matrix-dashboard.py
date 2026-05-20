#!/usr/bin/env python3
"""
Matrix Dashboard Server — serves dashboard/index.html on localhost:2025.
Python stdlib only. No pip installs required.
"""
import http.server, socketserver, os, sys

PORT = 2025
DASHBOARD_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'dashboard')

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DASHBOARD_DIR, **kwargs)

    def log_message(self, fmt, *args):
        pass  # Suppress request logs

if __name__ == '__main__':
    os.chdir(DASHBOARD_DIR)
    with socketserver.TCPServer(('', PORT), Handler) as httpd:
        print(f'  Matrix dashboard → http://localhost:{PORT}')
        print(f'  Press Ctrl+C to stop')
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print('\n  Dashboard stopped.')
            sys.exit(0)
