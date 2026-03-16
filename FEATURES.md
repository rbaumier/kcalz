# Features — kcalz

## Done

- **F1** — Scaffold + Dashboard hardcodé (palette Duolingo, ring kcal, barres macros, sections repas)
- **F2** — Script Rust `off-reduce` (réduction dump OFF → JSONL filtré, inclut produits sans nutriments)
- **F3** — Script Rust `off-to-sqlite` (JSONL → SQLite + FTS5, 988k produits)
- **F4** — Recherche OFF (OFFStore GRDB read-only, FTS5 prefix matching, debounce 150ms, recherche background)
- **F5** — Ajout d'aliment (SearchView → ProductDetailView → ajout au repas, NavigationStack)
- **F6** — Persistance des données utilisateur (GRDB read-write, user.sqlite, auto-save immédiat)
- **F7** — Navigation entre jours (chevrons fonctionnels, passé/futur, "Aujourd'hui")
- **F8** — Modifier un aliment (tap sur un aliment du dashboard → même écran que l'ajout, modifier le grammage, bouton supprimer)
- **F9** — Sélection multiple d'aliments (long press → mode sélection, barre d'actions : supprimer ou copier vers un autre repas)
- **F10** — Détail d'un repas (tap sur le titre → écran avec détails nutriments du repas)
- **F11** — Copier le repas précédent depuis une section vide
- **F12** — Scan code-barres (recherche OFF par code EAN lors de l'ajout d'un aliment)
- **F13** — Poids par défaut pré-rempli (product_quantity OFF, recherche par code EAN dans le champ texte)
- **F14** — Aliments récents / fréquents (historique filtrable, toggle récents/fréquents, brands persistées)
- **F15** — Aliments custom (créer un aliment non présent dans OFF, stocké dans product_override, recherchable dans "Mes aliments")
- **F16** — Enrichissement produits OFF incomplets (overrides utilisateur dans user.sqlite, bannière + champs éditables)
- **F17** — Suivi du poids (zone poids sur le dashboard, tap → graphe d'évolution avec période ajustable)
- **F20** — Retirer le swipe-to-delete sur un aliment
- **F21** — Calendrier pour changer de jour (tap sur la date → DatePicker graphical en sheet)
- **F22** — Lisser la courbe de poids (Catmull-Rom sur grandes périodes, masquer les points >31 entrées)

## À tester
- **F23** — Export manuel de la BDD (bouton dans GoalsView → fileExporter, rappel si dernier export >7 jours)
- **F24** — Fibres (suivi + barre dashboard, objectif auto 15g/1000 kcal, 255k produits avec données)
- **F25** — Objectifs poids (créer/supprimer des objectifs avec titre + type perte/prise/maintien, diff affiché sur dashboard + page poids)

## Tooling
- **Import MFP v2** — Pipeline mapping interactif (generate-candidates → mapping.html/server.ts → import.ts), 87% mapping, 12% FTS5, 1% brut
- **Match Drive U** — Matching EAN courses U ↔ produits OFF pour enrichir le mapping MFP

## Bugs connus
- Sélection multiple via context menu au lieu de long press direct (SwiftUI gesture conflict avec ScrollView)

## Next
- **F26** — Déploiement via AltStore/Sideloadly (re-signing automatique pour éviter l'expiration 7 jours)
- **F27** — Long press natif pour sélection sans bloquer le scroll (UIKit gesture recognizer ou refactor)
