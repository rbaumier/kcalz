# F4+F5 — Recherche OFF + Ajout d'aliment

## Données
- `off_fr.sqlite` (195Mo, 785k produits FR) embarqué dans le bundle
- Accès via GRDB, read-only, ouvert au lancement de l'app
- Recherche FTS5 sur `products_fts` (name, brands, categories)
- Résultats triés par `scans DESC` (popularité)

## Architecture
- `OFFStore` — classe qui ouvre le sqlite et expose `search(query:) -> [OFFProduct]`
- `OFFProduct` — struct miroir de la table `products`
- `SearchViewModel` — @Observable, gère le texte de recherche, le debounce (~300ms), les résultats
- `ProductDetailViewModel` — @Observable, gère les grammes et le calcul des nutriments en temps réel

## Navigation (push, 3 écrans)
1. **Dashboard** — bouton "+" sur un repas → push vers SearchView (passe le MealType)
2. **SearchView** — champ de recherche + liste résultats OFF. Tap produit → push vers ProductDetailView
3. **ProductDetailView** — nom, marque, champ grammes (100g défaut, clavier numérique), tableau nutriments recalculé live, bouton "Ajouter" → pop retour Dashboard

## Scope exclu
- Pas de SwiftData (données en mémoire, hardcodées)
- Pas d'historique/favoris
- Pas de scan code-barres
- Pas d'aliments custom
