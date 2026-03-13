# F7 — Navigation entre jours

## Design

- `@State private var currentDate = Date.now` dans DashboardView
- Chevrons ← → ajoutent/retirent 1 jour via `Calendar.current.date(byAdding:)`
- `.onChange(of: currentDate)` recharge le DayLog depuis UserStore
- Afficher "Aujourd'hui" quand currentDate == today
- Pas de limite passé/futur
- Pas de swipe, pas de calendrier picker
