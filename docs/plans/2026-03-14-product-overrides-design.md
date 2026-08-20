# Produits OFF sans nutriments — enrichissement utilisateur

## Résumé

Garder les produits OFF même sans données nutritionnelles. Les rendre searchables/scannables. Permettre à l'utilisateur de renseigner manuellement les kcal/macros. Stocker ces overrides dans `user.sqlite` pour qu'ils survivent aux mises à jour de `off_fr.sqlite`.

## Pipeline off-reduce

Retirer le filtre `kcal` obligatoire — inclure tous les produits FR même sans nutriments.

## Stockage — user.sqlite

Migration v6 :

```sql
CREATE TABLE product_override (
    code TEXT PRIMARY KEY,
    kcal REAL NOT NULL,
    proteins REAL,
    carbs REAL,
    fat REAL,
    sugars REAL,
    salt REAL
);
```

## Lookup avec merge

1. `OFFProduct` récupéré (search ou barcode)
2. Chercher override dans `user.sqlite` par `code`
3. Override existe → utiliser ses nutriments
4. `kcal == nil` sans override → mode éditable
5. `kcal != nil` → mode normal

## ProductDetailView — mode incomplet

- Bannière "Produit incomplet — renseignez les valeurs nutritionnelles"
- Champs nutriments éditables (kcal obligatoire, reste optionnel)
- "Ajouter" sauvegarde l'override puis ajoute l'entrée au repas

## Fichiers impactés

- `off-reduce/src/main.rs` — retirer filtre kcal obligatoire
- `UserStore.swift` — migration v6 + CRUD product_override
- `ProductDetailViewModel.swift` — mode éditable quand kcal nil
- `ProductDetailView.swift` — bannière + champs éditables conditionnels
- `DashboardView.swift` — passer userStore pour charger overrides
