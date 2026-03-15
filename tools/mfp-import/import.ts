#!/usr/bin/env bun

import { Database } from "bun:sqlite";
import { unlinkSync } from "fs";

// === Config ===
const MFP_DIR = "/Users/rbaumier/www/myfitnesspal-export/output";
const OFF_PATH = "data/off_fr.sqlite";
const OUT_PATH = "data/user.sqlite";
const MAPPING_PATH = "tools/mfp-import/mapping.json";

// === Mapping ===
interface MappingEntry {
  off_code: string;
  off_name: string;
  off_brands: string | null;
  off_kcal: number | null;
  off_prot: number | null;
  off_carbs: number | null;
  off_fat: number | null;
  off_sugars: number | null;
  off_salt: number | null;
  grams_per_unit?: number;
}

let mapping: Record<string, MappingEntry> = {};
try {
  mapping = await Bun.file(MAPPING_PATH).json();
  console.log(`Mapping: ${Object.keys(mapping).length} entrées chargées\n`);
} catch {
  console.log("Pas de mapping.json — fallback FTS5 uniquement\n");
}

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
  name: string;
  brands: string | null;
  kcal: number | null;
  proteins: number | null;
  carbs: number | null;
  fat: number | null;
  sugars: number | null;
  salt: number | null;
}

// === Name Parsing ===
// "Brand - Product, 200 g" → { name, brand, grams, qty, unit }
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

// === FTS5 Search ===
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
  SELECT p.name, p.brands, p.kcal, p.proteins, p.carbs, p.fat, p.sugars, p.salt
  FROM products_fts fts
  JOIN products p ON p.rowid = fts.rowid
  WHERE products_fts MATCH ?
  ORDER BY rank
  LIMIT ?`;

function searchExact(
  db: Database,
  name: string,
  brand: string | null,
): OffRow[] {
  const q = brand ? toFts(`${brand} ${name}`) : toFts(name);
  if (!q) return [];
  try {
    return db.query(FTS_SQL).all(q, 10) as OffRow[];
  } catch {
    return [];
  }
}

function searchBroad(db: Database, name: string): OffRow[] {
  const words = clean(name)
    .split(/\s+/)
    .filter((w) => w.length > 2);
  for (let n = Math.min(words.length, 3); n >= 1; n--) {
    const q = toFts(words.slice(0, n).join(" "));
    if (!q) continue;
    try {
      const r = db.query(FTS_SQL).all(q, 20) as OffRow[];
      if (r.length) return r;
    } catch {
      continue;
    }
  }
  return [];
}

// === Nutritional Distance ===
// Squared euclidean on per-100g (kcal scaled by /50 to normalize vs grams)
type Per100 = { kcal: number; prot: number; carbs: number; fat: number };

function dist(mfp: Per100, off: OffRow) {
  const dk = (mfp.kcal - (off.kcal ?? 0)) / 50;
  const dp = mfp.prot - (off.proteins ?? 0);
  const dc = mfp.carbs - (off.carbs ?? 0);
  const df = mfp.fat - (off.fat ?? 0);
  return dk * dk + dp * dp + dc * dc + df * df;
}

function bestMatch(
  rows: OffRow[],
  mfp: Per100,
): { row: OffRow; dist: number } | null {
  if (!rows.length) return null;
  let b = { row: rows[0], dist: dist(mfp, rows[0]) };
  for (let i = 1; i < rows.length; i++) {
    const d = dist(mfp, rows[i]);
    if (d < b.dist) b = { row: rows[i], dist: d };
  }
  return b;
}

// === Main ===
console.log("Lecture des fichiers MFP...");
const diary: MfpDay[] = await Bun.file(`${MFP_DIR}/food_diary.json`).json();
const weights: { date: string; weight: number }[] = await Bun.file(
  `${MFP_DIR}/weight_history.json`,
).json();

const totalEntries = diary.reduce(
  (s, d) => s + d.meals.reduce((s2, m) => s2 + m.entries.length, 0),
  0,
);
console.log(
  `  ${diary.length} jours, ${totalEntries} entrées, ${weights.length} pesées\n`,
);

// Open OFF (read-only) and create fresh user.sqlite
const offDb = new Database(OFF_PATH, { readonly: true });
try {
  unlinkSync(OUT_PATH);
} catch {}
const db = new Database(OUT_PATH);

db.exec(`
  PRAGMA journal_mode = WAL;
  PRAGMA synchronous = NORMAL;

  CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY);
  INSERT INTO grdb_migrations VALUES ('v1'), ('v2'), ('v3'), ('v4'), ('v5'), ('v6'), ('v7'), ('v8'), ('v9');

  CREATE TABLE food_entry (
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL,
    meal_type TEXT NOT NULL,
    name TEXT NOT NULL,
    brands TEXT,
    grams REAL NOT NULL,
    kcal_per_100g REAL NOT NULL,
    proteins_per_100g REAL NOT NULL,
    carbs_per_100g REAL NOT NULL,
    fat_per_100g REAL NOT NULL,
    sugars_per_100g REAL,
    salt_per_100g REAL,
    fiber_per_100g REAL,
    sort_order INTEGER NOT NULL DEFAULT 0
  );
  CREATE INDEX idx_food_entry_date ON food_entry(date);
  CREATE INDEX idx_food_entry_name ON food_entry(name);

  CREATE TABLE goals (kcal REAL, proteins REAL, carbs REAL, fat REAL, sugars REAL, salt REAL);
  CREATE TABLE weight_entry (date TEXT PRIMARY KEY, weight_kg REAL NOT NULL);
  CREATE TABLE product_override (
    code TEXT PRIMARY KEY,
    kcal REAL NOT NULL,
    proteins REAL,
    carbs REAL,
    fat REAL,
    sugars REAL,
    salt REAL,
    name TEXT,
    brands TEXT,
    fiber REAL
  );
  CREATE TABLE weight_checkpoint (
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL,
    weight_kg REAL NOT NULL,
    title TEXT NOT NULL,
    goal TEXT NOT NULL
  );
`);

const insFood = db.prepare(`
  INSERT INTO food_entry
    (id, date, meal_type, name, brands, grams, kcal_per_100g, proteins_per_100g, carbs_per_100g, fat_per_100g, sugars_per_100g, salt_per_100g, fiber_per_100g, sort_order)
  VALUES
    ($id, $date, $meal, $name, $brands, $grams, $kcal, $prot, $carbs, $fat, $sugars, $salt, $fiber, $order)
`);

const insWeight = db.prepare(
  `INSERT INTO weight_entry (date, weight_kg) VALUES ($date, $kg)`,
);

const MEAL_MAP: Record<string, string> = { snacks: "snack" };
const stats = { mapped: 0, fts: 0, raw: 0, skipped: 0 };
let processed = 0;

const BROAD_THRESHOLD = 225;

const run = db.transaction(() => {
  for (const day of diary) {
    for (const meal of day.meals) {
      const mealType = MEAL_MAP[meal.name] ?? meal.name;

      for (let i = 0; i < meal.entries.length; i++) {
        const e = meal.entries[i];
        const t = e.totals;
        processed++;

        if (processed % 1000 === 0) {
          process.stderr.write(`\r  ${processed}/${totalEntries}...`);
        }

        // Skip all-zero entries
        if (
          t.calories === 0 &&
          t.protein === 0 &&
          t.carbohydrates === 0 &&
          t.fat === 0
        ) {
          stats.skipped++;
          continue;
        }

        const p = parseName(e.name);

        let name: string,
          brands: string | null,
          grams: number;
        let kcal: number,
          prot: number,
          carbs: number,
          fat: number;
        let sugars: number | null,
          salt: number | null;

        // Priority 1: mapping.json (deterministic)
        const m = mapping[e.name];
        if (m) {
          name = m.off_name;
          brands = m.off_brands;
          kcal = m.off_kcal ?? 0;
          prot = m.off_prot ?? 0;
          carbs = m.off_carbs ?? 0;
          fat = m.off_fat ?? 0;
          sugars = m.off_sugars;
          salt = m.off_salt;

          // Compute grams
          if (p.grams && p.grams > 0) {
            grams = p.grams;
          } else if (m.grams_per_unit && p.qty) {
            grams = Math.round(p.qty * m.grams_per_unit);
          } else if (kcal > 0) {
            grams = Math.round((t.calories * 100) / kcal);
          } else {
            grams = 100;
          }
          stats.mapped++;
        } else {
          // Priority 2: FTS5 fallback
          const g = p.grams && p.grams > 0 ? p.grams : 100;
          const mfpPer100: Per100 = {
            kcal: (t.calories * 100) / g,
            prot: (t.protein * 100) / g,
            carbs: (t.carbohydrates * 100) / g,
            fat: (t.fat * 100) / g,
          };

          let match: OffRow | null = null;

          const r1 = searchExact(offDb, p.name, p.brand);
          if (r1.length) {
            const b = bestMatch(r1, mfpPer100);
            if (b) match = b.row;
          }

          if (!match) {
            const r2 = searchBroad(offDb, p.name);
            if (r2.length) {
              const b = bestMatch(r2, mfpPer100);
              if (b && b.dist < BROAD_THRESHOLD) match = b.row;
            }
          }

          if (match) {
            name = match.name;
            brands = match.brands;
            kcal = match.kcal ?? 0;
            prot = match.proteins ?? 0;
            carbs = match.carbs ?? 0;
            fat = match.fat ?? 0;
            sugars = match.sugars;
            salt = match.salt;
            grams =
              kcal > 0
                ? Math.round((t.calories * 100) / kcal)
                : (p.grams ?? 100);
            stats.fts++;
          } else {
            // Raw import
            name = p.name;
            brands = p.brand;
            grams = g;
            kcal = mfpPer100.kcal;
            prot = mfpPer100.prot;
            carbs = mfpPer100.carbs;
            fat = mfpPer100.fat;
            sugars = (t.sugar * 100) / g;
            salt = (t.sodium * 2.5) / 1000 / (g / 100);
            stats.raw++;
          }
        }

        insFood.run({
          $id: crypto.randomUUID(),
          $date: day.date,
          $meal: mealType,
          $name: name,
          $brands: brands,
          $grams: grams,
          $kcal: kcal,
          $prot: prot,
          $carbs: carbs,
          $fat: fat,
          $sugars: sugars,
          $salt: salt,
          $fiber: null,
          $order: i,
        });
      }
    }
  }

  // Import weights
  for (const w of weights) {
    insWeight.run({ $date: w.date, $kg: w.weight });
  }
});

run();
offDb.close();
db.close();

const total = stats.mapped + stats.fts + stats.raw + stats.skipped;
const pct = (n: number) => `${((n * 100) / total).toFixed(0)}%`;

console.log(`\n\nRésultats (${total} entrées):`);
console.log(`  ✓ ${stats.mapped} mapping (${pct(stats.mapped)})`);
console.log(`  ~ ${stats.fts} FTS5 fallback (${pct(stats.fts)})`);
console.log(`  ✗ ${stats.raw} import brut (${pct(stats.raw)})`);
console.log(`  ⊘ ${stats.skipped} ignorées — 0 cal (${pct(stats.skipped)})`);
console.log(`  Poids: ${weights.length} entrées`);
console.log(`\nSortie: ${OUT_PATH}`);
