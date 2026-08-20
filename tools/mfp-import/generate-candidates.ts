#!/usr/bin/env bun

import { Database } from "bun:sqlite";

const MFP_DIR = process.env.MFP_DIR ?? "data/mfp-export";
const OFF_PATH = "data/off_fr.sqlite";
const OUT_PATH = "tools/mfp-import/candidates.json";

// === Types ===
interface MfpDay {
  date: string;
  meals: { name: string; entries: { name: string; totals: Totals }[] }[];
}

interface Totals {
  calories: number;
  carbohydrates: number;
  fat: number;
  protein: number;
  sodium: number;
  sugar: number;
}

interface OffRow {
  code: string;
  name: string;
  brands: string | null;
  kcal: number | null;
  proteins: number | null;
  carbs: number | null;
  fat: number | null;
  sugars: number | null;
  salt: number | null;
}

// === Parsing ===
function parseName(raw: string) {
  const lastComma = raw.lastIndexOf(",");
  let namePart = raw;
  let qty: number | null = null;
  let unit: string | null = null;

  if (lastComma !== -1) {
    const qtyPart = raw.slice(lastComma + 1).trim();
    const m = qtyPart.match(/^([\d.]+)\s*(.+)$/);
    if (m) {
      qty = parseFloat(m[1]);
      const u = m[2].trim().toLowerCase();
      // Normalize gram units
      if (/^(g|gr|gram|gramme|grammes)$/i.test(u)) {
        unit = "g";
      } else {
        unit = u;
      }
      namePart = raw.slice(0, lastComma).trim();
    }
  }

  let brand: string | null = null;
  let name = namePart;
  const dash = namePart.indexOf(" - ");
  if (dash !== -1) {
    brand = namePart.slice(0, dash).replace(/[*+]+/g, "").trim() || null;
    name = namePart.slice(dash + 3).replace(/[*+]+/g, "").trim();
  } else {
    name = name.replace(/[*+]+/g, "").trim();
  }

  const grams = unit === "g" ? qty : null;

  return { name, brand, grams, qty, unit };
}

// === FTS5 ===
function clean(t: string) {
  return t
    .replace(/[^\w\sàâäéèêëïîôùûüÿçœæ'-]/gi, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function toFts(text: string): string | null {
  const words = clean(text)
    .split(/\s+/)
    .filter((w) => w.length > 1);
  if (!words.length) return null;
  return words.map((w) => `"${w.replace(/"/g, "")}"`).join(" ");
}

const FTS_SQL = `
  SELECT p.code, p.name, p.brands, p.kcal, p.proteins, p.carbs, p.fat, p.sugars, p.salt
  FROM products_fts fts
  JOIN products p ON p.rowid = fts.rowid
  WHERE products_fts MATCH ?
  ORDER BY rank
  LIMIT ?`;

function searchOff(db: Database, name: string, brand: string | null): OffRow[] {
  // Try with brand first
  if (brand) {
    const q = toFts(`${brand} ${name}`);
    if (q) {
      try {
        const r = db.query(FTS_SQL).all(q, 5) as OffRow[];
        if (r.length) return r;
      } catch {}
    }
  }

  // Name only
  const q = toFts(name);
  if (!q) return [];
  try {
    return db.query(FTS_SQL).all(q, 5) as OffRow[];
  } catch {
    return [];
  }
}

function searchBroad(db: Database, name: string): OffRow[] {
  const words = clean(name)
    .split(/\s+/)
    .filter((w) => w.length > 2);
  for (let n = Math.min(words.length, 2); n >= 1; n--) {
    const q = toFts(words.slice(0, n).join(" "));
    if (!q) continue;
    try {
      const r = db.query(FTS_SQL).all(q, 5) as OffRow[];
      if (r.length) return r;
    } catch {
      continue;
    }
  }
  return [];
}

// === Main ===
console.log("Lecture MFP...");
const diary: MfpDay[] = await Bun.file(`${MFP_DIR}/food_diary.json`).json();

// Deduplicate by MFP name, count occurrences, keep first totals
const foodMap = new Map<
  string,
  { count: number; totals: Totals }
>();

for (const day of diary) {
  for (const meal of day.meals) {
    for (const entry of meal.entries) {
      const t = entry.totals;
      if (t.calories === 0 && t.protein === 0 && t.carbohydrates === 0 && t.fat === 0) continue;
      const existing = foodMap.get(entry.name);
      if (existing) {
        existing.count++;
      } else {
        foodMap.set(entry.name, { count: 1, totals: t });
      }
    }
  }
}

// Sort by frequency
const sorted = [...foodMap.entries()].sort((a, b) => b[1].count - a[1].count);
console.log(`  ${sorted.length} aliments uniques\n`);

const offDb = new Database(OFF_PATH, { readonly: true });

const results: any[] = [];

for (let i = 0; i < sorted.length; i++) {
  const [mfpName, { count, totals }] = sorted[i];

  if ((i + 1) % 50 === 0) {
    process.stderr.write(`\r  ${i + 1}/${sorted.length}...`);
  }

  const parsed = parseName(mfpName);

  // Search candidates
  let candidates = searchOff(offDb, parsed.name, parsed.brand);
  if (!candidates.length) {
    candidates = searchBroad(offDb, parsed.name);
  }

  // Deduplicate candidates by code
  const seen = new Set<string>();
  candidates = candidates.filter((c) => {
    if (seen.has(c.code)) return false;
    seen.add(c.code);
    return true;
  });

  results.push({
    mfpName,
    count,
    mfp: {
      cal: totals.calories,
      prot: totals.protein,
      carbs: totals.carbohydrates,
      fat: totals.fat,
      sugar: totals.sugar,
      sodium: totals.sodium,
    },
    parsed: {
      name: parsed.name,
      brand: parsed.brand,
      grams: parsed.grams,
      qty: parsed.qty,
      unit: parsed.unit,
    },
    candidates: candidates.map((c) => ({
      code: c.code,
      name: c.name,
      brands: c.brands,
      kcal: c.kcal,
      proteins: c.proteins,
      carbs: c.carbs,
      fat: c.fat,
      sugars: c.sugars,
      salt: c.salt,
    })),
  });
}

offDb.close();

await Bun.write(OUT_PATH, JSON.stringify(results, null, 2));

console.log(`\n\n${results.length} aliments → ${OUT_PATH}`);
const withCandidates = results.filter((r) => r.candidates.length > 0).length;
const without = results.length - withCandidates;
console.log(`  ${withCandidates} avec candidats OFF`);
console.log(`  ${without} sans candidat`);
