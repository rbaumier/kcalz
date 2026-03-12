use rusqlite::Connection;
use serde::Deserialize;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::time::Instant;

#[derive(Deserialize)]
struct Product {
    code: String,
    name: String,
    brands: Option<String>,
    categories: Option<String>,
    kcal: Option<f64>,
    proteins: Option<f64>,
    carbs: Option<f64>,
    fat: Option<f64>,
    sugars: Option<f64>,
    salt: Option<f64>,
    nutriscore: Option<String>,
    quantity: Option<String>,
    scans: Option<u64>,
}

fn main() {
    let input_path = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "data/off_fr.jsonl".to_string());
    let output_path = std::env::args()
        .nth(2)
        .unwrap_or_else(|| "data/off_fr.sqlite".to_string());

    eprintln!("Lecture: {input_path}");
    eprintln!("Sortie:  {output_path}");

    let _ = std::fs::remove_file(&output_path);

    let db = Connection::open(&output_path).expect("impossible de créer la base SQLite");

    db.execute_batch(
        "PRAGMA journal_mode = OFF;
         PRAGMA synchronous = OFF;
         PRAGMA cache_size = -64000;
         PRAGMA page_size = 4096;",
    )
    .unwrap();

    db.execute_batch(
        "CREATE TABLE products (
            code TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            brands TEXT,
            categories TEXT,
            kcal REAL,
            proteins REAL,
            carbs REAL,
            fat REAL,
            sugars REAL,
            salt REAL,
            nutriscore TEXT,
            quantity TEXT,
            scans INTEGER
        );",
    )
    .unwrap();

    let start = Instant::now();
    let input = File::open(&input_path).expect("impossible d'ouvrir le fichier d'entrée");
    let reader = BufReader::with_capacity(8 * 1024 * 1024, input);

    let mut total: u64 = 0;
    let mut errors: u64 = 0;
    let mut batch: Vec<Product> = Vec::with_capacity(10_000);

    for line in reader.lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => {
                errors += 1;
                continue;
            }
        };
        if line.is_empty() {
            continue;
        }

        match serde_json::from_str::<Product>(&line) {
            Ok(p) => batch.push(p),
            Err(_) => {
                errors += 1;
                continue;
            }
        }

        if batch.len() >= 10_000 {
            insert_batch(&db, &batch);
            total += batch.len() as u64;
            batch.clear();

            if total % 100_000 == 0 {
                let elapsed = start.elapsed().as_secs();
                let rate = if elapsed > 0 { total / elapsed } else { 0 };
                eprintln!("[{elapsed:>4}s] {total:>8} insérés | {errors} erreurs | {rate}/s");
            }
        }
    }

    if !batch.is_empty() {
        total += batch.len() as u64;
        insert_batch(&db, &batch);
    }

    let insert_elapsed = start.elapsed().as_secs_f64();
    eprintln!();
    eprintln!("Insertion terminée en {insert_elapsed:.1}s — {total} produits");

    eprintln!("Création index FTS5...");
    let fts_start = Instant::now();

    db.execute_batch(
        "CREATE VIRTUAL TABLE products_fts USING fts5(
            name,
            brands,
            categories,
            content='products',
            content_rowid='rowid',
            tokenize='unicode61 remove_diacritics 2'
        );",
    )
    .unwrap();

    db.execute_batch(
        "INSERT INTO products_fts(rowid, name, brands, categories)
         SELECT rowid, name, COALESCE(brands, ''), COALESCE(categories, '')
         FROM products;",
    )
    .unwrap();

    let fts_elapsed = fts_start.elapsed().as_secs_f64();
    eprintln!("FTS5 créé en {fts_elapsed:.1}s");

    eprintln!("Création index scans...");
    db.execute_batch("CREATE INDEX idx_products_scans ON products(scans DESC);")
        .unwrap();

    let total_elapsed = start.elapsed().as_secs_f64();
    eprintln!();
    eprintln!("Terminé en {total_elapsed:.1}s");
    eprintln!("  Produits: {total}");
    eprintln!("  Erreurs:  {errors}");
    eprintln!("  Sortie:   {output_path}");
}

fn insert_batch(db: &Connection, batch: &[Product]) {
    db.execute_batch("BEGIN;").unwrap();
    let mut stmt = db
        .prepare_cached(
            "INSERT OR IGNORE INTO products
             (code, name, brands, categories, kcal, proteins, carbs, fat, sugars, salt, nutriscore, quantity, scans)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)",
        )
        .unwrap();

    for p in batch {
        stmt.execute(rusqlite::params![
            p.code,
            p.name,
            p.brands,
            p.categories,
            p.kcal,
            p.proteins,
            p.carbs,
            p.fat,
            p.sugars,
            p.salt,
            p.nutriscore,
            p.quantity,
            p.scans,
        ])
        .unwrap();
    }
    db.execute_batch("COMMIT;").unwrap();
}
