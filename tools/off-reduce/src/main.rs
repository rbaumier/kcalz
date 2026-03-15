use rayon::prelude::*;
use serde::Deserialize;
use std::fs::File;
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::time::Instant;

const CHUNK_SIZE: usize = 8_000;

#[derive(Deserialize)]
struct RawProduct<'a> {
    #[serde(borrow)]
    code: Option<&'a str>,
    #[serde(borrow)]
    product_name: Option<&'a str>,
    #[serde(borrow)]
    product_name_fr: Option<&'a str>,
    #[serde(borrow)]
    brands: Option<&'a str>,
    #[serde(borrow)]
    categories: Option<&'a str>,
    #[serde(borrow)]
    countries_tags: Option<Vec<&'a str>>,
    #[serde(borrow)]
    nutriscore_grade: Option<&'a str>,
    #[serde(borrow)]
    quantity: Option<&'a str>,
    product_quantity: Option<f64>,
    #[serde(borrow)]
    product_quantity_unit: Option<&'a str>,
    unique_scans_n: Option<u64>,
    #[serde(default)]
    nutriments: Nutriments,
    #[serde(default)]
    nutrition: Nutrition,
}

#[derive(Deserialize, Default)]
struct Nutriments {
    #[serde(rename = "energy-kcal_100g")]
    energy_kcal_100g: Option<f64>,
    proteins_100g: Option<f64>,
    carbohydrates_100g: Option<f64>,
    fat_100g: Option<f64>,
    sugars_100g: Option<f64>,
    salt_100g: Option<f64>,
    fiber_100g: Option<f64>,
}

#[derive(Deserialize, Default)]
struct Nutrition {
    #[serde(default)]
    aggregated_set: Option<AggregatedSet>,
}

#[derive(Deserialize)]
struct AggregatedSet {
    #[serde(default)]
    nutrients: Option<AggregatedNutrients>,
}

#[derive(Deserialize)]
struct AggregatedNutrients {
    #[serde(rename = "energy-kcal")]
    energy_kcal: Option<NutrientEntry>,
    proteins: Option<NutrientEntry>,
    carbohydrates: Option<NutrientEntry>,
    fat: Option<NutrientEntry>,
    sugars: Option<NutrientEntry>,
    salt: Option<NutrientEntry>,
    fiber: Option<NutrientEntry>,
}

#[derive(Deserialize)]
struct NutrientEntry {
    value: Option<f64>,
}

/// Get aggregated nutrients fallback (if available).
#[inline]
fn agg<'a>(product: &'a RawProduct<'a>) -> Option<&'a AggregatedNutrients> {
    product.nutrition.aggregated_set.as_ref()?.nutrients.as_ref()
}

/// Fallback: nutriments field, then aggregated_set entry.
#[inline]
fn agg_val(entry: Option<&NutrientEntry>) -> Option<f64> {
    entry?.value
}

/// Process a single line: parse JSON, filter, return serialized output or None.
fn process_line(line: &[u8]) -> Option<Vec<u8>> {
    let product: RawProduct = sonic_rs::from_slice(line).ok()?;

    // Must be sold in France
    let is_fr = product
        .countries_tags
        .as_ref()
        .is_some_and(|tags| tags.iter().any(|t| *t == "en:france"));
    if !is_fr {
        return None;
    }

    let ag = agg(&product);
    let kcal = product.nutriments.energy_kcal_100g
        .or_else(|| agg_val(ag?.energy_kcal.as_ref()));
    let proteins = product.nutriments.proteins_100g
        .or_else(|| agg_val(ag?.proteins.as_ref()));
    let carbs = product.nutriments.carbohydrates_100g
        .or_else(|| agg_val(ag?.carbohydrates.as_ref()));
    let fat = product.nutriments.fat_100g
        .or_else(|| agg_val(ag?.fat.as_ref()));
    let sugars = product.nutriments.sugars_100g
        .or_else(|| agg_val(ag?.sugars.as_ref()));
    let salt = product.nutriments.salt_100g
        .or_else(|| agg_val(ag?.salt.as_ref()));
    let fiber = product.nutriments.fiber_100g
        .or_else(|| agg_val(ag?.fiber.as_ref()));

    let code = product.code.filter(|s| !s.is_empty())?;
    let name = product
        .product_name
        .filter(|s| !s.is_empty())
        .or_else(|| product.product_name_fr.filter(|s| !s.is_empty()))?;

    let mut out = Vec::with_capacity(256);
    write_product(&mut out, code, name, &product, kcal, proteins, carbs, fat, sugars, salt, fiber);
    Some(out)
}

#[inline]
fn write_json_str(w: &mut Vec<u8>, s: &str) {
    w.push(b'"');
    for &byte in s.as_bytes() {
        match byte {
            b'"' => w.extend_from_slice(b"\\\""),
            b'\\' => w.extend_from_slice(b"\\\\"),
            b'\n' => w.extend_from_slice(b"\\n"),
            b'\r' => w.extend_from_slice(b"\\r"),
            b'\t' => w.extend_from_slice(b"\\t"),
            b if b < 0x20 => {
                let hex = b"0123456789abcdef";
                w.extend_from_slice(&[b'\\', b'u', b'0', b'0', hex[(b >> 4) as usize], hex[(b & 0xf) as usize]]);
            }
            _ => w.push(byte),
        }
    }
    w.push(b'"');
}

fn write_product(
    w: &mut Vec<u8>, code: &str, name: &str, p: &RawProduct, kcal: Option<f64>,
    proteins: Option<f64>, carbs: Option<f64>, fat: Option<f64>,
    sugars: Option<f64>, salt: Option<f64>, fiber: Option<f64>,
) {
    w.extend_from_slice(b"{\"code\":");
    write_json_str(w, code);
    w.extend_from_slice(b",\"name\":");
    write_json_str(w, name);

    if let Some(v) = p.brands.filter(|s| !s.is_empty()) {
        w.extend_from_slice(b",\"brands\":");
        write_json_str(w, v);
    }
    if let Some(v) = p.categories.filter(|s| !s.is_empty()) {
        w.extend_from_slice(b",\"categories\":");
        write_json_str(w, v);
    }

    if let Some(v) = kcal {
        w.extend_from_slice(b",\"kcal\":");
        let mut buf = ryu::Buffer::new();
        w.extend_from_slice(buf.format(v).as_bytes());
    }

    if let Some(v) = proteins {
        w.extend_from_slice(b",\"proteins\":");
        let mut buf = ryu::Buffer::new();
        w.extend_from_slice(buf.format(v).as_bytes());
    }
    if let Some(v) = carbs {
        w.extend_from_slice(b",\"carbs\":");
        let mut buf = ryu::Buffer::new();
        w.extend_from_slice(buf.format(v).as_bytes());
    }
    if let Some(v) = fat {
        w.extend_from_slice(b",\"fat\":");
        let mut buf = ryu::Buffer::new();
        w.extend_from_slice(buf.format(v).as_bytes());
    }
    if let Some(v) = sugars {
        w.extend_from_slice(b",\"sugars\":");
        let mut buf = ryu::Buffer::new();
        w.extend_from_slice(buf.format(v).as_bytes());
    }
    if let Some(v) = salt {
        w.extend_from_slice(b",\"salt\":");
        let mut buf = ryu::Buffer::new();
        w.extend_from_slice(buf.format(v).as_bytes());
    }
    if let Some(v) = fiber {
        w.extend_from_slice(b",\"fiber\":");
        let mut buf = ryu::Buffer::new();
        w.extend_from_slice(buf.format(v).as_bytes());
    }

    if let Some(v) = p.nutriscore_grade.filter(|s| !s.is_empty() && *s != "unknown" && *s != "not-applicable") {
        w.extend_from_slice(b",\"nutriscore\":");
        write_json_str(w, v);
    }
    if let Some(v) = p.quantity.filter(|s| !s.is_empty()) {
        w.extend_from_slice(b",\"quantity\":");
        write_json_str(w, v);
    }
    if let Some(v) = p.product_quantity {
        w.extend_from_slice(b",\"product_quantity\":");
        let mut buf = ryu::Buffer::new();
        w.extend_from_slice(buf.format(v).as_bytes());
    }
    if let Some(v) = p.product_quantity_unit.filter(|s| !s.is_empty()) {
        w.extend_from_slice(b",\"product_quantity_unit\":");
        write_json_str(w, v);
    }
    if let Some(v) = p.unique_scans_n {
        w.extend_from_slice(b",\"scans\":");
        let mut buf = itoa::Buffer::new();
        w.extend_from_slice(buf.format(v).as_bytes());
    }

    w.extend_from_slice(b"}\n");
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

    // Read lines in chunks, process each chunk in parallel
    let mut lines_buf: Vec<String> = Vec::with_capacity(CHUNK_SIZE);
    let mut line = String::new();
    let mut reader = reader;

    loop {
        lines_buf.clear();

        for _ in 0..CHUNK_SIZE {
            line.clear();
            match reader.read_line(&mut line) {
                Ok(0) => break,
                Ok(_) => {
                    let trimmed = line.trim_end();
                    if !trimmed.is_empty() {
                        lines_buf.push(trimmed.to_string());
                    }
                }
                Err(_) => {
                    errors += 1;
                }
            }
        }

        if lines_buf.is_empty() {
            break;
        }

        total += lines_buf.len() as u64;

        // Parse + filter in parallel across all cores
        let results: Vec<Option<Vec<u8>>> = lines_buf
            .par_iter()
            .map(|l| {
                process_line(l.as_bytes())
            })
            .collect();

        // Write sequentially (IO-bound, fast with buffered writer)
        for result in results {
            match result {
                Some(out) => {
                    writer.write_all(&out).unwrap();
                    kept += 1;
                }
                None => {}
            }
        }

        let elapsed = start.elapsed().as_secs();
        if elapsed > 0 && total % (CHUNK_SIZE as u64) == 0 {
            let rate = total / elapsed;
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
