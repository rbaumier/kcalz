# F17 — Suivi du poids

## Dashboard — zone poids

Sous les barres macros (ou sous le résumé kcal si pas de macros), une ligne compacte :

- Icône balance + poids du jour en `kcNumberSmall` + `kcFeather`
- Si pas de poids saisi aujourd'hui : "—" en gris
- Flèche tendance sur 7j : ↓ vert si baisse, ↑ rouge si hausse, → gris si stable (±0.2kg)
- Tap → navigation vers `WeightView`

## WeightView — historique

- **En haut** : champ texte décimal pour le poids du jour + bouton "Enregistrer" (ou mise à jour si déjà saisi)
- **En dessous** : graphe courbe (Swift Charts `LineMark`) avec les points de poids
- **Sélecteur de période** : 4 pills (7j / 30j / 90j / Tout)
- Axe Y auto-scalé avec marge
- Points cliquables qui affichent date + valeur

## Data

- Nouvelle table `weight_entry` (migration v3) : `date TEXT PK`, `weight_kg DOUBLE NOT NULL`
- Méthodes UserStore : `saveWeight(kg:date:)`, `loadWeight(for:)`, `loadWeights(from:to:)`, `latestWeights(limit:)`
- Pas de modif à DayLog ni NutritionGoal
