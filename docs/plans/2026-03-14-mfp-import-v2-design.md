# MFP Import v2 — Matching interactif

## Problème

L'import v1 produit des faux positifs FTS5 (Banana → Banana Ketchup, Miel → Jus de pomme au miel). Les aliments récurrents doivent être correctement matchés pour un historique fiable.

## Pipeline

```
1. generate-candidates.ts (Bun)
   MFP JSON + OFF SQLite → candidates.json

2. mapping.html (navigateur)
   Charge candidates.json → validation interactive → exporte mapping.json

3. import.ts modifié (Bun)
   MFP JSON + mapping.json + OFF SQLite → data/user.sqlite
```

## Étape 1 — generate-candidates.ts

- Déduplique les aliments MFP par nom, compte les occurrences
- Trie par fréquence décroissante
- Pour chaque aliment unique : parse le nom, cherche 5 candidats OFF (FTS5 + distance nutritionnelle)
- Sortie : `candidates.json`

## Étape 2 — mapping.html

Page HTML self-contained. Pour chaque aliment MFP (trié par fréquence) :
- Nom MFP + count + nutriments MFP
- Dropdown des 5 candidats OFF avec leurs nutriments
- Champ texte pour coller un code-barres OFF (lookup dans off_fr.sqlite via les candidates)
- Champ `grams_per_unit` pour les unités non-grammes (tbsp, slice, verre)
- Skip/ignorer
- Bouton "Exporter JSON" → télécharge `mapping.json`

## Étape 3 — import.ts modifié

- Charge `mapping.json` en premier
- Entrée MFP dans le mapping avec match → utilise le produit mappé (déterministe)
- Entrée MFP pas dans le mapping → fallback FTS5 comme v1
- `grams_per_unit` × quantité parsée = grammage correct

## Format mapping.json

```json
{
  "Flocons d'avoine repere - Flocons d'avoine, 30 gramme": {
    "off_name": "Flocons d'avoine",
    "off_brands": "Marque Repère",
    "off_kcal": 362, "off_prot": 13, "off_carbs": 58, "off_fat": 7,
    "off_sugars": 1.1, "off_salt": 0.01
  },
  "Peanut butter, 1 tbsp": {
    "off_name": "Peanut Butter",
    "off_brands": null,
    "off_kcal": 588, "off_prot": 25, "off_carbs": 20, "off_fat": 50,
    "grams_per_unit": 16
  }
}
```

Entrées skippées = absentes du mapping → import brut.
