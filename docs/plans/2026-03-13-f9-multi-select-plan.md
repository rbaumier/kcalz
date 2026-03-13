# F9 — Sélection multiple d'aliments — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Long press sur un aliment → mode sélection avec checkbox, barre d'actions flottante (supprimer / copier vers un autre repas+date).

**Architecture:** L'état de sélection vit dans DashboardView (`selectedMealType: MealType?` + `selectedEntryIds: Set<UUID>`). MealSectionView reçoit un binding `isSelecting` et le set de sélection. Nouvelle CopySheet pour la destination. UserStore reçoit `deleteEntries(ids:)` et `copyEntries(ids:to:date:)`.

**Tech Stack:** SwiftUI, GRDB

---

### Task 1: UserStore — bulk delete + copy

**Files:**
- Modify: `kcalz/Stores/UserStore.swift`

**Step 1: Ajouter `deleteEntries(ids:)`**

Après la méthode `deleteEntry(id:)` (ligne 183), ajouter :

```swift
func deleteEntries(ids: Set<UUID>) throws {
    guard !ids.isEmpty else { return }
    try dbQueue.write { db in
        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let sql = "DELETE FROM food_entry WHERE id IN (\(placeholders))"
        try db.execute(sql: sql, arguments: StatementArguments(ids.map { $0.uuidString }))
    }
}
```

**Step 2: Ajouter `copyEntries(ids:toDate:mealType:)`**

```swift
func copyEntries(ids: Set<UUID>, toDate date: Date, mealType: MealType) throws {
    guard !ids.isEmpty else { return }
    let dateStr = date.kcDateString
    let mealTypeStr = mealType.rawValue

    try dbQueue.write { db in
        let nextOrder: Int = try Int.fetchOne(
            db,
            sql: "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM food_entry WHERE date = ? AND meal_type = ?",
            arguments: [dateStr, mealTypeStr]
        ) ?? 0

        let placeholders = ids.map { _ in "?" }.joined(separator: ", ")
        let rows = try Row.fetchAll(
            db,
            sql: "SELECT * FROM food_entry WHERE id IN (\(placeholders)) ORDER BY sort_order",
            arguments: StatementArguments(ids.map { $0.uuidString })
        )

        for (i, row) in rows.enumerated() {
            let sql = """
                INSERT INTO food_entry (id, date, meal_type, name, grams, kcal_per_100g, proteins_per_100g, carbs_per_100g, fat_per_100g, sugars_per_100g, salt_per_100g, sort_order)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """
            try db.execute(sql: sql, arguments: [
                UUID().uuidString,
                dateStr,
                mealTypeStr,
                row["name"] as? String ?? "",
                row["grams"] as? Double ?? 0,
                row["kcal_per_100g"] as? Double ?? 0,
                row["proteins_per_100g"] as? Double ?? 0,
                row["carbs_per_100g"] as? Double ?? 0,
                row["fat_per_100g"] as? Double ?? 0,
                row["sugars_per_100g"] as? Double,
                row["salt_per_100g"] as? Double,
                nextOrder + i,
            ])
        }
    }
}
```

**Step 3: Build**

```bash
xcodebuild -project kcalz.xcodeproj -scheme kcalz -sdk iphonesimulator -destination 'id=67080FA6-9061-46B3-A900-C59F47616CAE' ENABLE_DEBUG_DYLIB=false build 2>&1 | grep -E '(error:|BUILD)'
```

Expected: `BUILD SUCCEEDED`

**Step 4: Commit**

```bash
git add kcalz/Stores/UserStore.swift
git commit -m "feat: UserStore bulk delete + copy entries"
```

---

### Task 2: MealSectionView — mode sélection

**Files:**
- Modify: `kcalz/Views/Components/MealSectionView.swift`

**Step 1: Ajouter les paramètres de sélection à MealSectionView**

Modifier la struct pour accepter l'état de sélection :

```swift
struct MealSectionView: View {
    let meal: Meal
    let onAdd: () -> Void
    let onTap: (FoodEntry) -> Void
    let onDelete: (FoodEntry) -> Void
    let isSelecting: Bool
    @Binding var selectedIds: Set<UUID>
    let onLongPress: () -> Void
    let onCancelSelection: () -> Void
```

**Step 2: Modifier le header — bouton Annuler en mode sélection**

Remplacer le bouton "+" par "Annuler" quand `isSelecting` :

```swift
// Dans le header HStack, remplacer le bouton + par :
if isSelecting {
    Button {
        onCancelSelection()
    } label: {
        Text("Annuler")
            .font(.kcBody)
            .foregroundStyle(Color.kcWolf)
    }
} else {
    Button {
        onAdd()
    } label: {
        Image(systemName: "plus")
            .font(.kcIconMedium)
            .foregroundStyle(Color.kcSnow)
            .frame(width: Theme.buttonSize, height: 36)
            .background(Color.kcFeather)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusS, style: .continuous))
    }
    .buttonStyle(Kc3DButton(shadow: .kcWing))
    .accessibilityLabel("Ajouter un aliment à \(meal.type.displayName)")
}
```

**Step 3: Modifier le body des entrées — checkbox en mode sélection**

Remplacer le ForEach des entrées pour basculer entre `SwipeableEntryRow` et `SelectableEntryRow` :

```swift
ForEach(Array(meal.entries.enumerated()), id: \.element.id) { i, entry in
    if i > 0 {
        Rectangle()
            .fill(Color.kcPolar)
            .frame(height: 2)
            .padding(.leading, Theme.cardInnerPadding)
    }

    if isSelecting {
        SelectableEntryRow(
            entry: entry,
            isSelected: selectedIds.contains(entry.id),
            onToggle: {
                if selectedIds.contains(entry.id) {
                    selectedIds.remove(entry.id)
                } else {
                    selectedIds.insert(entry.id)
                }
            }
        )
    } else {
        SwipeableEntryRow(
            entry: entry,
            onTap: { onTap(entry) },
            onDelete: { onDelete(entry) }
        )
        .onLongPressGesture {
            onLongPress()
            selectedIds.insert(entry.id)
        }
    }
}
```

**Step 4: Créer SelectableEntryRow**

Ajouter après `SwipeableEntryRow` :

```swift
private struct SelectableEntryRow: View {
    let entry: FoodEntry
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? Color.kcFeather : Color.kcHare)

            Text(entry.name)
                .font(.kcBody)
                .foregroundStyle(Color.kcEel)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(Int(entry.grams))g")
                .font(.kcBadge)
                .foregroundStyle(Color.kcHare)
                .padding(.trailing, 14)

            Text("\(Int(entry.kcal))")
                .font(.kcNumberSmall)
                .foregroundStyle(Color.kcFeather)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal, Theme.cardInnerPadding)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}
```

**Step 5: Build** (attendu : erreurs dans DashboardView car les appels à MealSectionView n'ont pas encore les nouveaux params)

---

### Task 3: DashboardView — état de sélection + barre d'actions

**Files:**
- Modify: `kcalz/Views/Dashboard/DashboardView.swift`

**Step 1: Ajouter les @State de sélection**

Après `@State private var summaryAppeared = false` :

```swift
@State private var selectingMealType: MealType?
@State private var selectedEntryIds: Set<UUID> = []
@State private var showCopySheet = false
```

**Step 2: Mettre à jour l'appel MealSectionView**

Remplacer le ForEach des meals dans `dayContent` :

```swift
ForEach(dayLog.meals) { meal in
    MealSectionView(
        meal: meal,
        onAdd: { path.append(.search(meal.type)) },
        onTap: { entry in path.append(.edit(entry, meal.type)) },
        onDelete: { entry in removeEntry(entry, from: meal.type) },
        isSelecting: selectingMealType == meal.type,
        selectedIds: $selectedEntryIds,
        onLongPress: { selectingMealType = meal.type },
        onCancelSelection: { exitSelectionMode() }
    )
}
```

**Step 3: Ajouter la barre d'actions flottante**

Wrapper le ScrollView dans un ZStack, avec la barre en overlay en bas :

```swift
// Dans dayContent, après le ScrollView, ajouter un overlay :
.overlay(alignment: .bottom) {
    if selectingMealType != nil && !selectedEntryIds.isEmpty {
        SelectionActionBar(
            count: selectedEntryIds.count,
            onDelete: { deleteSelectedEntries() },
            onCopy: { showCopySheet = true }
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .padding(.horizontal, Theme.horizontalPadding)
        .padding(.bottom, 16)
    }
}
.animation(.easeOut(duration: 0.2), value: selectingMealType)
.animation(.easeOut(duration: 0.2), value: selectedEntryIds)
```

**Step 4: Ajouter les méthodes helper**

```swift
private func exitSelectionMode() {
    selectingMealType = nil
    selectedEntryIds = []
}

private func deleteSelectedEntries() {
    try? userStore.deleteEntries(ids: selectedEntryIds)
    exitSelectionMode()
    loadDay(currentDate)
}

private func copySelectedEntries(to date: Date, mealType: MealType) {
    try? userStore.copyEntries(ids: selectedEntryIds, toDate: date, mealType: mealType)
    exitSelectionMode()
    loadDay(currentDate)
}
```

**Step 5: Build** (attendu : erreur car `SelectionActionBar` n'existe pas encore)

---

### Task 4: SelectionActionBar + CopySheet

**Files:**
- Create: `kcalz/Views/Components/SelectionActionBar.swift`
- Create: `kcalz/Views/Components/CopySheet.swift`

**Step 1: Créer SelectionActionBar**

```swift
import SwiftUI

struct SelectionActionBar: View {
    let count: Int
    let onDelete: () -> Void
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text("\(count) sélectionné\(count > 1 ? "s" : "")")
                .font(.kcBody)
                .foregroundStyle(Color.kcSnow)

            Spacer()

            Button { onCopy() } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.kcSnow)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Copier")

            Button { onDelete() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.kcCardinal)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Supprimer")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.kcEel)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusL, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}
```

**Step 2: Créer CopySheet**

```swift
import SwiftUI

struct CopySheet: View {
    @State private var selectedDate = Date.now
    @State private var selectedMealType: MealType = .breakfast

    let onCopy: (Date, MealType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "fr_FR"))

                // Meal type pills
                VStack(alignment: .leading, spacing: 8) {
                    Text("REPAS")
                        .font(.kcLabel)
                        .foregroundStyle(Color.kcWolf)
                        .kerning(Theme.labelKerning)

                    HStack(spacing: 8) {
                        ForEach(MealType.allCases) { type in
                            Button {
                                selectedMealType = type
                            } label: {
                                Text(type.displayName)
                                    .font(.kcSmallLabel)
                                    .foregroundStyle(selectedMealType == type ? Color.kcSnow : Color.kcEel)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedMealType == type ? Color.kcFeather : Color.kcSnow)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    onCopy(selectedDate, selectedMealType)
                    dismiss()
                } label: {
                    Text("Copier")
                        .font(.kcHeadline)
                        .foregroundStyle(Color.kcSnow)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.kcFeather)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusL, style: .continuous))
                }
                .buttonStyle(Kc3DButton(shadow: .kcWing, depth: 5))
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 32)
            .background(Color.kcPolar)
            .navigationTitle("Copier vers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}
```

**Step 3: Ajouter la `.sheet` dans DashboardView**

Dans `dayContent`, ajouter après le `.overlay` de la barre d'actions :

```swift
.sheet(isPresented: $showCopySheet) {
    CopySheet { date, mealType in
        copySelectedEntries(to: date, mealType: mealType)
    }
    .presentationDetents([.large])
}
```

**Step 4: xcodegen + build**

```bash
xcodegen generate
xcodebuild -project kcalz.xcodeproj -scheme kcalz -sdk iphonesimulator -destination 'id=67080FA6-9061-46B3-A900-C59F47616CAE' ENABLE_DEBUG_DYLIB=false build 2>&1 | grep -E '(error:|BUILD)'
```

Expected: `BUILD SUCCEEDED`

**Step 5: Install + test manuel**

1. Ajouter 2-3 aliments dans un repas
2. Long press sur un aliment → mode sélection, checkbox visible
3. Tap pour sélectionner/désélectionner
4. Barre d'actions apparaît en bas
5. Supprimer → les aliments sélectionnés disparaissent
6. Copier → sheet s'ouvre, choisir date + repas, confirmer

**Step 6: Commit**

```bash
git add kcalz/Views/Components/SelectionActionBar.swift kcalz/Views/Components/CopySheet.swift kcalz/Views/Dashboard/DashboardView.swift kcalz/Views/Components/MealSectionView.swift kcalz.xcodeproj
git commit -m "feat: F9 — sélection multiple, suppression groupée, copie vers repas"
```
