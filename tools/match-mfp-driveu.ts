#!/usr/bin/env bun

import { Database } from "bun:sqlite";
import { readFileSync, writeFileSync } from "fs";
import { join } from "path";

const ROOT = join(import.meta.dir, "..");
const offDb = new Database(join(ROOT, "data/off_fr.sqlite"), { readonly: true });

const mapping = JSON.parse(readFileSync(join(ROOT, "tools/mfp-import/mapping.json"), "utf8"));
const candidates = JSON.parse(readFileSync(join(ROOT, "tools/mfp-import/candidates.json"), "utf8"));
const driveU = JSON.parse(readFileSync(join(ROOT, "data/drive-u-products.json"), "utf8")).flat();

// Build Drive U lookup: normalized name -> product
const driveByName = new Map<string, any>();
for (const p of driveU) {
  // Multiple normalization keys for fuzzy matching
  const name = p.name.toLowerCase()
    .replace(/\s*-\s*/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  driveByName.set(name, p);

  // Also index by just the first meaningful words
  const short = name.split(/[,-]/)[0].trim();
  if (short.length > 3 && !driveByName.has(short)) {
    driveByName.set(short, p);
  }
}

const lookupStmt = offDb.prepare(
  "SELECT code, name, brands, kcal, proteins, carbs, fat, sugars, salt FROM products WHERE code = ?"
);

function lookupOFF(ean: string): any {
  let row = lookupStmt.get(ean);
  if (!row && ean.length < 13) {
    row = lookupStmt.get("0".repeat(13 - ean.length) + ean);
  }
  return row;
}

function normalize(s: string): string {
  return s.toLowerCase()
    .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

// Extract keywords from MFP name for matching
function mfpKeywords(mfpName: string): string[] {
  // "Flocons d'avoine repere - Flocons d'avoine, 80 gramme" -> extract product name part
  const parts = mfpName.split(/\s*-\s*/);
  const name = parts.length > 1 ? parts[1].split(",")[0].trim() : parts[0].split(",")[0].trim();
  return normalize(name).split(/\s+/).filter(w => w.length > 2);
}

function driveKeywords(driveName: string): string[] {
  return normalize(driveName).split(/\s+/).filter(w => w.length > 2);
}

// Score: how many MFP keywords match Drive U product name
function matchScore(mfpKw: string[], driveKw: string[]): number {
  let score = 0;
  for (const kw of mfpKw) {
    if (driveKw.some(dk => dk.includes(kw) || kw.includes(dk))) score++;
  }
  return score;
}

const unmapped = candidates.filter((c: any) => !mapping[c.mfpName]);
let newMatches = 0;

console.log(`${unmapped.length} aliments MFP non mappés`);
console.log(`${driveByName.size} produits Drive U indexés`);
console.log();

const newMapping: Record<string, any> = {};

for (const c of unmapped) {
  const mfpKw = mfpKeywords(c.mfpName);
  if (mfpKw.length === 0) continue;

  // Find best matching Drive U product
  let bestProduct: any = null;
  let bestScore = 0;

  for (const dp of driveU) {
    const dkw = driveKeywords(dp.name);
    const score = matchScore(mfpKw, dkw);
    const ratio = score / mfpKw.length;
    if (ratio > bestScore && ratio >= 0.5) {
      bestScore = ratio;
      bestProduct = dp;
    }
  }

  if (!bestProduct) continue;

  // Lookup the Drive U EAN in OFF
  const offProduct = lookupOFF(bestProduct.EAN);
  if (!offProduct || offProduct.kcal == null) continue;

  newMapping[c.mfpName] = {
    off_code: offProduct.code,
    off_name: offProduct.name,
    off_brands: offProduct.brands,
    off_kcal: offProduct.kcal,
    off_prot: offProduct.proteins,
    off_carbs: offProduct.carbs,
    off_fat: offProduct.fat,
    off_sugars: offProduct.sugars,
    off_salt: offProduct.salt,
    drive_u_match: bestProduct.name.slice(0, 60),
    drive_u_ean: bestProduct.EAN,
  };
  newMatches++;

  console.log(`✓ ${c.count}x "${c.mfpName.slice(0, 50)}" → ${offProduct.name} (${bestProduct.name.slice(0, 40)})`);
}

console.log(`\n${newMatches} nouveaux matchs trouvés via Drive U`);

// Merge with existing mapping
const merged = { ...mapping, ...newMapping };
const outPath = join(ROOT, "tools/mfp-import/mapping.json");
writeFileSync(outPath, JSON.stringify(merged, null, 2));
console.log(`mapping.json mis à jour: ${Object.keys(merged).length} entrées (${Object.keys(mapping).length} existantes + ${newMatches} nouvelles)`);
