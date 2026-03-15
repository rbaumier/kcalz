#!/usr/bin/env python3
"""Mini serveur de recherche OFF — sert le HTML + une API /search?q=..."""

import json
import sqlite3
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import os

DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'data', 'off_fr.sqlite')

db = sqlite3.connect(DB_PATH, check_same_thread=False)
db.row_factory = sqlite3.Row

HTML = """<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>kcalz — recherche OFF</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: system-ui, -apple-system, sans-serif; background: #f7f7f7; padding: 24px; }
h1 { font-size: 1.4rem; font-weight: 700; color: #333; margin-bottom: 16px; }
input {
  width: 100%; max-width: 500px; padding: 12px 16px; font-size: 1rem;
  border: 2px solid #ddd; border-radius: 12px; outline: none;
  transition: border-color .2s;
}
input:focus { border-color: #58CC02; }
#status { color: #999; font-size: .85rem; margin-top: 8px; }
#results { margin-top: 16px; max-width: 500px; }
.item {
  background: #fff; border-radius: 12px; padding: 12px 16px; margin-bottom: 8px;
  box-shadow: 0 2px 6px rgba(0,0,0,.05);
}
.item-name { font-weight: 600; color: #333; }
.item-brand { font-size: .85rem; color: #888; }
.item-macros { display: flex; gap: 12px; margin-top: 6px; font-size: .8rem; flex-wrap: wrap; }
.macro { padding: 2px 8px; border-radius: 6px; font-weight: 600; }
.macro-kcal { background: #FFF3E0; color: #FF9600; }
.macro-p { background: #FFEBEE; color: #FF4B4B; }
.macro-c { background: #E3F2FD; color: #1CB0F6; }
.macro-f { background: #FFFDE7; color: #F9A825; }
.item-meta { font-size: .75rem; color: #bbb; margin-top: 4px; }
</style>
</head>
<body>
<h1>🔍 Recherche OpenFoodFacts</h1>
<input id="search" type="text" placeholder="Chercher un aliment..." autofocus>
<div id="status">785k produits. Tapez pour chercher.</div>
<div id="results"></div>
<script>
let t;
document.getElementById('search').addEventListener('input', e => {
  clearTimeout(t);
  t = setTimeout(() => search(e.target.value), 100);
});

async function search(q) {
  const el = document.getElementById('results');
  if (!q.trim()) { el.innerHTML = ''; return; }
  const t0 = performance.now();
  const r = await fetch('/search?q=' + encodeURIComponent(q));
  const data = await r.json();
  const ms = (performance.now() - t0).toFixed(0);
  document.getElementById('status').textContent = `${data.length} résultats en ${ms}ms`;
  el.innerHTML = data.map(p => `
    <div class="item">
      <div class="item-name">${esc(p.name)}</div>
      ${p.brands ? `<div class="item-brand">${esc(p.brands)}</div>` : ''}
      <div class="item-macros">
        ${p.kcal != null ? `<span class="macro macro-kcal">${Math.round(p.kcal)} kcal</span>` : ''}
        ${p.proteins != null ? `<span class="macro macro-p">P ${Math.round(p.proteins)}g</span>` : ''}
        ${p.carbs != null ? `<span class="macro macro-c">G ${Math.round(p.carbs)}g</span>` : ''}
        ${p.fat != null ? `<span class="macro macro-f">L ${Math.round(p.fat)}g</span>` : ''}
      </div>
      <div class="item-meta">${p.code}${p.nutriscore ? ' · Nutriscore ' + p.nutriscore.toUpperCase() : ''}${p.scans ? ' · ' + p.scans + ' scans' : ''}</div>
    </div>
  `).join('');
}

function esc(s) { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }
</script>
</body>
</html>"""


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == '/' or parsed.path == '/index.html':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(HTML.encode())
            return

        if parsed.path == '/search':
            q = parse_qs(parsed.query).get('q', [''])[0].strip()
            results = do_search(q) if q else []
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(results, ensure_ascii=False).encode())
            return

        self.send_error(404)

    def log_message(self, format, *args):
        pass  # silence logs


def do_search(q):
    fts_query = ' '.join(f'"{w}"*' for w in q.split())
    rows = db.execute("""
        SELECT p.code, p.name, p.brands, p.kcal, p.proteins, p.carbs, p.fat, p.nutriscore, p.scans
        FROM products_fts f
        JOIN products p ON p.rowid = f.rowid
        WHERE products_fts MATCH ?
        ORDER BY p.scans DESC
        LIMIT 20
    """, [fts_query]).fetchall()
    return [dict(r) for r in rows]


if __name__ == '__main__':
    print('http://localhost:3000')
    HTTPServer(('', 3000), Handler).serve_forever()
