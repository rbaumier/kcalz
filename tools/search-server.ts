import { Database } from "bun:sqlite";

const db = new Database("data/off_fr.sqlite", { readonly: true });
db.exec("PRAGMA mmap_size = 268435456");

const search = db.prepare(`
  SELECT p.code, p.name, p.brands, p.kcal, p.proteins, p.carbs, p.fat, p.nutriscore, p.scans
  FROM products_fts f
  JOIN products p ON p.rowid = f.rowid
  WHERE products_fts MATCH ?
  ORDER BY p.scans DESC
  LIMIT 20
`);

const HTML = `<!DOCTYPE html>
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
document.getElementById('search').addEventListener('input', async e => {
  const q = e.target.value.trim();
  const el = document.getElementById('results');
  if (!q) { el.innerHTML = ''; document.getElementById('status').textContent = '785k produits. Tapez pour chercher.'; return; }
  const r = await fetch('/search?q=' + encodeURIComponent(q));
  const data = await r.json();
  document.getElementById('status').textContent = data.count + ' résultats — SQLite: ' + data.ms.toFixed(2) + 'ms';
  el.innerHTML = data.results.map(p => \`
    <div class="item">
      <div class="item-name">\${esc(p.name)}</div>
      \${p.brands ? \`<div class="item-brand">\${esc(p.brands)}</div>\` : ''}
      <div class="item-macros">
        \${p.kcal != null ? \`<span class="macro macro-kcal">\${Math.round(p.kcal)} kcal</span>\` : ''}
        \${p.proteins != null ? \`<span class="macro macro-p">P \${Math.round(p.proteins)}g</span>\` : ''}
        \${p.carbs != null ? \`<span class="macro macro-c">G \${Math.round(p.carbs)}g</span>\` : ''}
        \${p.fat != null ? \`<span class="macro macro-f">L \${Math.round(p.fat)}g</span>\` : ''}
      </div>
      <div class="item-meta">\${p.code}\${p.nutriscore ? ' · Nutriscore ' + p.nutriscore.toUpperCase() : ''}\${p.scans ? ' · ' + p.scans + ' scans' : ''}</div>
    </div>
  \`).join('');
});
function esc(s) { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }
</script>
</body>
</html>`;

Bun.serve({
  port: 3000,
  fetch(req) {
    const url = new URL(req.url);

    if (url.pathname === "/" || url.pathname === "/index.html") {
      return new Response(HTML, { headers: { "Content-Type": "text/html; charset=utf-8" } });
    }

    if (url.pathname === "/search") {
      const q = url.searchParams.get("q")?.trim();
      if (!q) return Response.json({ results: [], count: 0, ms: 0 });

      const ftsQuery = q.split(/\s+/).map(w => `"${w}"*`).join(" ");
      const t0 = Bun.nanoseconds();
      const results = search.all(ftsQuery);
      const ms = (Bun.nanoseconds() - t0) / 1_000_000;

      return Response.json({ results, count: results.length, ms });
    }

    return new Response("Not found", { status: 404 });
  },
});

console.log("http://localhost:3000");
