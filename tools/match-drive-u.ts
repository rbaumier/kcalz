#!/usr/bin/env bun

import { Database } from "bun:sqlite";
import { readFileSync, writeFileSync } from "fs";
import { join } from "path";

const ROOT = join(import.meta.dir, "..");
const offDb = new Database(join(ROOT, "data/off_fr.sqlite"), { readonly: true });

const data = JSON.parse(readFileSync(join(ROOT, "data/drive-u-products.json"), "utf8"));
const allProducts = (data as any[][]).flat();

// Deduplicate by EAN, count occurrences
const byEan = new Map<string, { product: any; count: number }>();
for (const p of allProducts) {
  const existing = byEan.get(p.EAN);
  if (existing) {
    existing.count++;
  } else {
    byEan.set(p.EAN, { product: p, count: 1 });
  }
}

console.log(`${byEan.size} produits uniques Drive U`);

// Lookup in OFF by EAN
const lookupStmt = offDb.prepare(
  "SELECT code, name, brands, kcal, proteins, carbs, fat, sugars, salt FROM products WHERE code = ?"
);
const lookupPadded = offDb.prepare(
  "SELECT code, name, brands, kcal, proteins, carbs, fat, sugars, salt FROM products WHERE code = ?"
);

interface Match {
  drive_ean: string;
  drive_name: string;
  drive_brand: string;
  count: number;
  off_match: any | null;
  status: "matched" | "matched_no_nutrition" | "not_found";
}

const results: Match[] = [];
let matched = 0;
let matchedNoNutrition = 0;
let notFound = 0;

for (const [ean, { product: p, count }] of byEan) {
  // Try exact, then padded with leading 0
  let offProduct = lookupStmt.get(ean) as any;
  if (!offProduct && ean.length < 13) {
    offProduct = lookupPadded.get("0".repeat(13 - ean.length) + ean) as any;
  }

  const entry: Match = {
    drive_ean: ean,
    drive_name: p.name,
    drive_brand: p.brand,
    count,
    off_match: offProduct || null,
    status: offProduct
      ? offProduct.kcal != null
        ? "matched"
        : "matched_no_nutrition"
      : "not_found",
  };

  if (offProduct && offProduct.kcal != null) matched++;
  else if (offProduct) matchedNoNutrition++;
  else notFound++;

  results.push(entry);
}

// Sort by count desc
results.sort((a, b) => b.count - a.count);

const outPath = join(ROOT, "data/drive-u-matching.json");
writeFileSync(outPath, JSON.stringify(results, null, 2));

console.log(`\nRésultats:`);
console.log(`  Matchés (avec nutrition): ${matched} (${((matched / byEan.size) * 100).toFixed(1)}%)`);
console.log(`  Matchés (sans nutrition): ${matchedNoNutrition}`);
console.log(`  Non trouvés:             ${notFound}`);
console.log(`\nÉcrit: ${outPath}`);

// Show top not found
console.log(`\n=== Top 20 non trouvés (par fréquence) ===`);
const notFoundItems = results.filter((r) => r.status !== "matched");
for (const r of notFoundItems.slice(0, 20)) {
  console.log(`  ${r.count}x | ${r.drive_ean} | ${r.drive_name.slice(0, 60)} [${r.status}]`);
}
