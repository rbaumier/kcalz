# OFF Reduce Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Script Rust qui lit `data/openfoodfacts-products.jsonl` (65 Go), filtre les produits FR avec kcal, extrait 13 champs, écrit `data/off_fr.jsonl`.

**Architecture:** Cargo binary dans `tools/off-reduce/`. Lecture streaming ligne par ligne avec `BufReader` (mémoire constante). Parsing JSON avec `serde_json::Value` pour gérer la structure variable des produits OFF. Écriture buffered.

**Tech Stack:** Rust, serde, serde_json

---

### Task 1: Scaffold Cargo project

**Files:**
- Create: `tools/off-reduce/Cargo.toml`
- Create: `tools/off-reduce/src/main.rs`

**Step 1: Init le projet Cargo**

```bash
cd /Users/rbaumier/www/kcalz
cargo init tools/off-reduce
```

**Step 2: Configurer Cargo.toml**

Remplacer le contenu de `tools/off-reduce/Cargo.toml` :

```toml
[package]
name = "off-reduce"
version = "0.1.0"
edition = "2024"

[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"

[profile.release]
opt-level = 3
lto = true
```

**Step 3: Écrire un main.rs minimal qui compile**

```rust
fn main() {
    println!("off-reduce");
}
```

**Step 4: Vérifier que ça compile**

```bash
cd /Users/rbaumier/www/kcalz/tools/off-reduce && cargo build --release
```

Expected: `Compiling off-reduce` → `Finished`

**Step 5: Commit**

```bash
cd /Users/rbaumier/www/kcalz
git add tools/off-reduce/
git commit -m "init: cargo project off-reduce"
```

---

### Task 2: Implémenter le script complet

**Files:**
- Modify: `tools/off-reduce/src/main.rs`

**Step 1: Écrire l'implémentation**

```rust
use serde::Serialize;
use serde_json::Value;
use std::fs::File;
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::time::Instant;

#[derive(Serialize)]
struct Product {
    code: String,
    name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    brands: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    categories: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    kcal: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    proteins: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    carbs: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    fat: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    sugars: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    salt: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    nutriscore: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    quantity: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    scans: Option<u64>,
}

fn non_empty_str(v: &Value, key: &str) -> Option<String> {
    v.get(key)
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
}

fn nutriment_f64(nutriments: &Value, key: &str) -> Option<f64> {
    nutriments.get(key).and_then(|v| v.as_f64())
}

fn is_france(v: &Value) -> bool {
    v.get("countries_tags")
        .and_then(|v| v.as_array())
        .map(|tags| tags.iter().any(|t| t.as_str() == Some("en:france")))
        .unwrap_or(false)
}

fn extract(v: &Value) -> Option<Product> {
    // Filtre: France + kcal renseigné
    if !is_france(v) {
        return None;
    }

    let nutriments = v.get("nutriments").unwrap_or(&Value::Null);
    let kcal = nutriment_f64(nutriments, "energy-kcal_100g");
    if kcal.is_none() {
        return None;
    }

    let code = non_empty_str(v, "code")?;
    let name = non_empty_str(v, "product_name")
        .or_else(|| non_empty_str(v, "product_name_fr"))?;

    Some(Product {
        code,
        name,
        brands: non_empty_str(v, "brands"),
        categories: non_empty_str(v, "categories"),
        kcal,
        proteins: nutriment_f64(nutriments, "proteins_100g"),
        carbs: nutriment_f64(nutriments, "carbohydrates_100g"),
        fat: nutriment_f64(nutriments, "fat_100g"),
        sugars: nutriment_f64(nutriments, "sugars_100g"),
        salt: nutriment_f64(nutriments, "salt_100g"),
        nutriscore: non_empty_str(v, "nutriscore_grade")
            .filter(|s| s != "unknown" && s != "not-applicable"),
        quantity: non_empty_str(v, "quantity"),
        scans: v.get("unique_scans_n").and_then(|v| v.as_u64()),
    })
}

fn main() {
    let input_path = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "data/openfoodfacts-products.jsonl".to_string());
    let output_path = std::env::args()
        .nth(2)
        .unwrap_or_else(|| "data/off_fr.jsonl".to_string());

    eprintln!("Lecture: {input_path}");
    eprintln!("Sortie:  {output_path}");

    let input = File::open(&input_path).expect("impossible d'ouvrir le fichier d'entrée");
    let reader = BufReader::with_capacity(8 * 1024 * 1024, input);

    let output = File::create(&output_path).expect("impossible de créer le fichier de sortie");
    let mut writer = BufWriter::with_capacity(4 * 1024 * 1024, output);

    let start = Instant::now();
    let mut total: u64 = 0;
    let mut kept: u64 = 0;
    let mut errors: u64 = 0;

    for line in reader.lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => { errors += 1; continue; }
        };

        if line.is_empty() {
            continue;
        }

        total += 1;

        let v: Value = match serde_json::from_str(&line) {
            Ok(v) => v,
            Err(_) => { errors += 1; continue; }
        };

        if let Some(product) = extract(&v) {
            serde_json::to_writer(&mut writer, &product).unwrap();
            writer.write_all(b"\n").unwrap();
            kept += 1;
        }

        if total % 100_000 == 0 {
            let elapsed = start.elapsed().as_secs();
            let rate = if elapsed > 0 { total / elapsed } else { 0 };
            eprintln!(
                "[{elapsed:>4}s] {total:>8} lus | {kept:>7} gardés | {errors} erreurs | {rate}/s"
            );
        }
    }

    writer.flush().unwrap();

    let elapsed = start.elapsed().as_secs_f64();
    eprintln!();
    eprintln!("Terminé en {elapsed:.1}s");
    eprintln!("  Total lu:  {total}");
    eprintln!("  Gardés:    {kept}");
    eprintln!("  Erreurs:   {errors}");
    eprintln!("  Sortie:    {output_path}");
}
```

**Step 2: Compiler en release**

```bash
cd /Users/rbaumier/www/kcalz/tools/off-reduce && cargo build --release
```

Expected: `Finished` sans erreur.

**Step 3: Tester sur le sample de 100 produits**

D'abord extraire un sample depuis le fichier complet :

```bash
cd /Users/rbaumier/www/kcalz
head -1000 data/openfoodfacts-products.jsonl > /tmp/off_sample_1k.jsonl
./tools/off-reduce/target/release/off-reduce /tmp/off_sample_1k.jsonl /tmp/off_test.jsonl
```

Expected: affiche les stats (total lu, gardés ~20%, erreurs 0). Vérifier le contenu :

```bash
head -3 /tmp/off_test.jsonl | python3 -m json.tool
```

Expected: objets JSON avec les 13 champs, valeurs cohérentes.

**Step 4: Commit**

```bash
cd /Users/rbaumier/www/kcalz
git add tools/off-reduce/
git commit -m "feat: off-reduce — script Rust pour réduire le dump OpenFoodFacts"
```

---

### Task 3: Lancer sur le dump complet

**Step 1: Exécuter sur les 65 Go**

```bash
cd /Users/rbaumier/www/kcalz
./tools/off-reduce/target/release/off-reduce data/openfoodfacts-products.jsonl data/off_fr.jsonl
```

Durée estimée : 5-15 min. Le script log la progression toutes les 100k lignes.

**Step 2: Vérifier le résultat**

```bash
wc -l data/off_fr.jsonl
ls -lh data/off_fr.jsonl
head -5 data/off_fr.jsonl | python3 -m json.tool
```

Expected: ~500-600k lignes, ~80-150 Mo.

**Step 3: Vérifier que les données sont cohérentes**

```bash
python3 -c "
import json
with open('data/off_fr.jsonl') as f:
    products = [json.loads(line) for line in f]
print(f'Total: {len(products)}')
print(f'Avec kcal: {sum(1 for p in products if p.get(\"kcal\"))}')
print(f'Avec name: {sum(1 for p in products if p.get(\"name\"))}')
print(f'Avec brands: {sum(1 for p in products if p.get(\"brands\"))}')
print(f'Avec nutriscore: {sum(1 for p in products if p.get(\"nutriscore\"))}')
print(f'Top scans:', sorted(products, key=lambda p: p.get('scans') or 0, reverse=True)[:5])
"
```

**Step 4: Ajouter data/ au .gitignore et commit**

```bash
cd /Users/rbaumier/www/kcalz
echo -e "\n# Data dumps\ndata/" >> .gitignore
git add .gitignore
git commit -m "chore: ignore data/ (dumps OFF volumineux)"
```
