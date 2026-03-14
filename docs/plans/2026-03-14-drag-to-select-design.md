# Drag-to-select dans une section de repas

## Comportement

1. Long-press sur une EntryRow → entre en mode sélection + sélectionne cette entrée (existant)
2. Sans relâcher, glisser vers le bas/haut → chaque entrée traversée est sélectionnée (ajout only)
3. Relâcher → mode sélection reste actif, tap individuel pour toggle

## Implémentation

### MealSectionView

- `SequenceGesture(LongPressGesture, DragGesture)` sur le VStack des entries
- Phase 1 (long-press) : `onLongPress()` + `selectedIds.insert(entry.id)`
- Phase 2 (drag) : track position Y, hit-test contre les frames des EntryRows
- Stocker les frames via `.onGeometryChange` ou `GeometryReader` + preference key sur chaque row
- Quand le doigt entre dans une row → `selectedIds.insert(row.id)`

### Contraintes

- Drag uniquement dans le même repas (pas cross-section)
- Le drag ne désélectionne pas (seulement ajoute)
- Le DragGesture existant (swipe-to-delete) sur EntryRow doit être désactivé pendant le drag-to-select
