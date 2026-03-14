# F — Copier le repas précédent (section vide)

## Comportement

Quand une section de repas est vide, afficher sous "Aucun aliment" un texte secondaire interactif :

> *maintiens pour copier le goûter d'hier (150 kcal)*
> *maintiens pour copier le déjeuner d'il y a 3j (620 kcal)*

- **Recherche** : scanner les 7 derniers jours pour le dernier repas du même `MealType` non-vide
- **Texte** : `"maintiens pour copier le {mealType} d'{timeLabel} ({totalKcal} kcal)"`
  - `timeLabel` = "hier" si 1 jour, "il y a Xj" sinon
- **Action** : long-press → copie directe, pas de confirmation
- Si rien trouvé dans les 7j → rien affiché, juste "Aucun aliment"

## Implémentation

### Store — `UserStore.findLastMealEntries(type:before:limit:)`

- Query : `SELECT * FROM food_entry WHERE meal_type = ? AND date < ? AND date >= ? ORDER BY date DESC, sort_order`
- Grouper par date, retourner le premier groupe non-vide : `(date: Date, entries: [FoodEntry])?`

### Vue — `MealSectionView`

- Nouvelle prop optionnelle : `previousMeal: (date: Date, entries: [FoodEntry])?`
- Si section vide + previousMeal non-nil → afficher label + `.onLongPressGesture`
- Long-press appelle callback `onCopyPrevious`

### DashboardView

- Charger les données "previous meal" pour chaque section vide lors du `loadDay()`
- `onCopyPrevious` → `copyEntries` puis reload
