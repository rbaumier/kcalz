# F9 — Sélection multiple d'aliments

## Activation

Long press sur un aliment dans un repas → active le mode sélection pour ce repas. L'aliment pressé est automatiquement sélectionné.

## Mode sélection

- Les SwipeableEntryRow du repas concerné deviennent des lignes sélectionnables (checkbox à gauche, le swipe est désactivé)
- Tap = toggle sélection
- Les autres repas restent en mode normal
- Une barre d'actions flottante apparaît en bas avec le nombre d'éléments sélectionnés

## Barre d'actions

Deux boutons :
- **Supprimer** (icone trash, rouge) — supprime tous les éléments sélectionnés, quitte le mode
- **Copier** (icone doc.on.doc) — ouvre la sheet de destination

## Sheet de copie

Bottom sheet avec :
- `DatePicker` compact (style `.graphical` pour voir le calendrier)
- 4 boutons repas (petit-déj / déjeuner / goûter / dîner), style pills, un seul sélectionnable
- Bouton "Copier" (Kc3DButton vert) — copie les aliments sélectionnés avec le même grammage, quitte le mode

## Sortie du mode

- Bouton "Annuler" dans le header du repas (remplace le bouton "+")
- Ou après une action (supprimer/copier)
