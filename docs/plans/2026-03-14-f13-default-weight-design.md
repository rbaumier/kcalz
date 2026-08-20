# F13 — Poids par défaut pré-rempli

## Résumé

Pré-remplir le grammage dans ProductDetailView à partir du champ `quantity` du produit OFF, au lieu de toujours 100g.

## Parsing

Fonction `parseQuantityGrams(_ quantity: String?) -> Double?` :

- `250 g` / `250g` → 250
- `1 kg` / `0,320 kg` → 1000 / 320
- `500 ml` / `1 l` / `240ml` → 500 / 1000 / 240 (1ml ≈ 1g)
- `2 x 80 g` → 80 (portion unitaire)
- `6 x 250 ml` → 250
- `6 oz`, `100` (sans unité), `nil`, `""` → nil

Fallback : `parseQuantityGrams(product.quantity) ?? 100`

## Intégration

Modifier `ProductDetailViewModel` pour utiliser le quantity parsé à l'init (mode ajout OFF uniquement, pas récent/edit).

Aucun nouveau fichier, aucune modification de schéma.
