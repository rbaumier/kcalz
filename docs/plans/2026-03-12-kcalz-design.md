# kcalz — Design

App iOS de suivi calories/poids. Ultra performante, légère, ludique. French only.

## Décisions techniques

- **Stack** : SwiftUI natif, iOS 17+
- **Architecture** : MVVM + `@Observable`
- **Données utilisateur** : SwiftData + CloudKit (sync iCloud automatique)
- **Données OFF** : SQLite read-only via GRDB, FTS5 sur name/brands/categories
- **Dump OFF** : ~500k produits FR réduits (~80-120Mo), embarqué dans le bundle
- **Fallback scan** : API OFF si code-barres absent du dump → cache dans SwiftData (`CachedProduct`)
- **Quantités** : grammes uniquement
- **UI** : coloré, arrondi, animations spring/bounce (style Duolingo)

## Modèle de données

### OFF dump (SQLite/GRDB — read-only)

```
OFFProduct: barcode (PK), name, brands, categories,
  energy_kcal_100g, proteins_100g, carbs_100g, fat_100g,
  sugars_100g, salt_100g, image_thumb_url
  → FTS5 index sur name, brands, categories
```

### Utilisateur (SwiftData + CloudKit)

```
UserGoal: id, kcal?, proteins?, carbs?, fat?, sugars?, salt?

WeightEntry: id, date, weight (kg)

DayLog: id, date → [Meal]

Meal: id, type (breakfast/lunch/snack/dinner) → [FoodEntry]

FoodEntry: id, barcode?, customProductId?, name, grams,
  kcal_100g, proteins_100g, carbs_100g, fat_100g, sugars_100g?, salt_100g?

CustomProduct: id, name, kcal_100g, proteins_100g, carbs_100g, fat_100g, sugars_100g?, salt_100g?

Recipe: id, name → [FoodEntry]

CachedProduct: barcode (PK), name, brands?,
  energy_kcal_100g?, proteins_100g?, carbs_100g?, fat_100g?,
  sugars_100g?, salt_100g?, image_thumb_url?, fetchedAt
```

Nutriments dénormalisés dans FoodEntry pour indépendance vis-à-vis du dump OFF.

## Architecture

```
App/KcalzApp.swift
Models/          — SwiftData models
Stores/          — OFFStore (GRDB), BarcodeAPIClient
ViewModels/      — @Observable VMs
Views/           — SwiftUI views par feature
Resources/       — off_products.sqlite
Utils/           — BarcodeScanner (AVFoundation), Theme
```

Deux stores séparés : GRDB (OFF, read-only) + SwiftData (utilisateur, CloudKit).

## Flux clés

- **Recherche** : FoodEntry déjà utilisés (fréquence) → CustomProduct → OFF dump (FTS5) → résultats fusionnés
- **Scan** : GRDB par barcode → si miss, API OFF → CachedProduct → si miss, proposer CustomProduct
- **Ajout recette à repas** : copie des FoodEntry de la recette dans le Meal

## Navigation

TabView 3 onglets : Journal | Poids | Réglages

## Features (user stories)

### F1 — Scaffold projet + thème
Setup Xcode, SwiftData, GRDB, thème couleurs/fonts/animations de base.

### F2 — Dashboard journalier
Afficher la date du jour (navigation jour), barres de progression nutriments, liste des 4 repas avec leurs aliments. Goals en dur pour commencer.

### F3 — Objectifs (UserGoal)
CRUD des objectifs journaliers (kcal, P, G, L, sucres, sel). Tous optionnels. Le dashboard reflète les goals définis.

### F4 — Dump OFF + recherche FTS
Script de génération du dump réduit. Intégration GRDB + FTS5. Recherche as-you-type.

### F5 — Ajout d'aliment à un repas
Modale recherche (FTS OFF + aliments déjà utilisés triés par fréquence/récence). Saisie quantité en grammes. Preview nutriments en temps réel. Ajout au repas.

### F6 — Scan code-barres
AVFoundation camera, lookup GRDB, fallback API OFF, cache CachedProduct.

### F7 — Sélection & copie/suppression d'aliments
Checkboxes sur les aliments, barre contextuelle bas avec Copier (vers autre repas) / Supprimer.

### F8 — Aliments custom
Création manuelle d'un aliment avec ses nutriments. Apparaît dans la recherche.

### F9 — Recettes
CRUD recettes (nom + liste de FoodEntry). Ajout d'une recette complète à un repas en un tap.

### F10 — Suivi du poids
Saisie quotidienne, historique, graphe évolution (Swift Charts, 7j/30j/90j).

### F11 — Sync iCloud
Activation CloudKit sur les modèles SwiftData. Test multi-device.
