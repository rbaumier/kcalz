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
            Err(_) => {
                errors += 1;
                continue;
            }
        };

        if line.is_empty() {
            continue;
        }

        total += 1;

        let v: Value = match serde_json::from_str(&line) {
            Ok(v) => v,
            Err(_) => {
                errors += 1;
                continue;
            }
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
