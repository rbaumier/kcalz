#!/usr/bin/env bun

import { Database } from "bun:sqlite";
import { readFileSync } from "fs";
import { join } from "path";

const ROOT = join(import.meta.dir, "../..");
const offDb = new Database(join(ROOT, "data/off_fr.sqlite"), { readonly: true });
const DIR = import.meta.dir;

const searchStmt = offDb.prepare(`
  SELECT p.code, p.name, p.brands, p.kcal, p.proteins, p.carbs, p.fat, p.sugars, p.salt
  FROM products_fts fts
  JOIN products p ON p.rowid = fts.rowid
  WHERE products_fts MATCH ?
  ORDER BY rank
  LIMIT 12
`);

function toFts(text: string): string | null {
  const words = text
    .replace(/[^\w\sàâäéèêëïîôùûüÿçœæ'-]/gi, " ")
    .replace(/\s+/g, " ")
    .trim()
    .split(/\s+/)
    .filter(w => w.length > 1);
  if (!words.length) return null;
  return words.map(w => `"${w.replace(/"/g, "")}"`).join(" ");
}

const MIME: Record<string, string> = {
  ".html": "text/html",
  ".json": "application/json",
  ".js": "text/javascript",
};

Bun.serve({
  port: 8123,
  async fetch(req) {
    const url = new URL(req.url);

    // API: search OFF
    if (url.pathname === "/api/search") {
      const q = url.searchParams.get("q") || "";
      const fts = toFts(q);
      if (!fts) return Response.json([]);
      try {
        const results = searchStmt.all(fts) as any[];
        return new Response(JSON.stringify(results), {
          headers: { "Content-Type": "application/json" },
        });
      } catch {
        return Response.json([]);
      }
    }

    // API: lookup by code (try exact, padded, and LIKE variants)
    if (url.pathname === "/api/product") {
      const code = url.searchParams.get("code") || "";
      const sql = "SELECT code, name, brands, kcal, proteins, carbs, fat, sugars, salt FROM products WHERE code = ?";
      let row = offDb.query(sql).get(code);
      if (!row) row = offDb.query(sql).get("0" + code);
      if (!row) row = offDb.query(sql).get(code + "00");
      if (!row) row = offDb.query(sql).get("0" + code + "00");
      if (!row) {
        const likeRow = offDb.query(
          "SELECT code, name, brands, kcal, proteins, carbs, fat, sugars, salt FROM products WHERE code LIKE ? LIMIT 1"
        ).get(`%${code}%`);
        if (likeRow) row = likeRow;
      }
      return new Response(JSON.stringify(row || null), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Static files
    let path = url.pathname === "/" ? "/mapping.html" : url.pathname;
    const filePath = join(DIR, path);
    try {
      return new Response(Bun.file(filePath));
    } catch {
      return new Response("Not found", { status: 404 });
    }
  },
});

console.log("http://localhost:8123/");
