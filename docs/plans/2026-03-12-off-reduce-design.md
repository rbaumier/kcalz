# OFF Reduce — Design

Script Rust pour réduire le dump OpenFoodFacts (65 Go JSONL) en un JSONL léger contenant uniquement les produits français avec données nutritionnelles.

## Entrée

`data/openfoodfacts-products.jsonl` — ~3.5M produits, 186 champs par produit, 65 Go.

## Filtres

- `countries_tags` contient `"en:france"`
- `nutriments.energy-kcal_100g` non null

## Champs extraits (13)

| Champ sortie | Source OFF | Type |
|---|---|---|
| `code` | `code` | String (PK, code-barres EAN) |
| `name` | `product_name` | String |
| `brands` | `brands` | String? |
| `categories` | `categories` | String? |
| `kcal` | `nutriments.energy-kcal_100g` | f64? |
| `proteins` | `nutriments.proteins_100g` | f64? |
| `carbs` | `nutriments.carbohydrates_100g` | f64? |
| `fat` | `nutriments.fat_100g` | f64? |
| `sugars` | `nutriments.sugars_100g` | f64? |
| `salt` | `nutriments.salt_100g` | f64? |
| `nutriscore` | `nutriscore_grade` | String? |
| `quantity` | `quantity` | String? |
| `scans` | `unique_scans_n` | u32? |

## Sortie

`data/off_fr.jsonl` — une ligne JSON par produit, 13 champs.

Estimation : ~500-600k produits, ~80-150 Mo.

## Implémentation

- Cargo project : `tools/off-reduce/`
- Dépendances : `serde`, `serde_json`
- Lecture streaming ligne par ligne (mémoire constante)
- Log progression tous les 100k produits
