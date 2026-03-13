# F6 — Persistance des données utilisateur

## Schema SQLite (user.sqlite dans Application Support)

```sql
CREATE TABLE food_entry (
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL,
    meal_type TEXT NOT NULL,
    name TEXT NOT NULL,
    grams REAL NOT NULL,
    kcal_per_100g REAL NOT NULL,
    proteins_per_100g REAL NOT NULL,
    carbs_per_100g REAL NOT NULL,
    fat_per_100g REAL NOT NULL,
    sugars_per_100g REAL,
    salt_per_100g REAL,
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_food_entry_date ON food_entry(date);
```

## Architecture

- **UserStore** — GRDB read-write, Application Support directory, auto-save immédiat
- **DatabaseMigrator** v1 pour créer la table
- Mapping SQL direct (pas de PersistableRecord sur les modèles)
- DayLog reconstruit depuis les entries groupées par meal_type

## Data flow

1. App lance → UserStore.init() crée/migre la DB
2. DashboardView.task → userStore.loadDayLog(for: .now)
3. Ajout aliment → userStore.addEntry() + update @State dayLog
4. PreviewData.dayLog uniquement pour les previews
