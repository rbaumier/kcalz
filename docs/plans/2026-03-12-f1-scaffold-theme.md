# F1 — Scaffold + Dashboard hardcodé

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Projet Xcode qui build + un Dashboard affichant des données hardcodées : goal kcal du jour, poids, 4 repas avec aliments.

**Architecture:** SwiftUI iOS 17+, MVVM/@Observable. Pas de persistence pour l'instant — tout est hardcodé. GRDB ajouté en dépendance SPM pour les futures features.

**Tech Stack:** Swift, SwiftUI, GRDB 7.x (SPM), xcodegen

---

### Task 1: Init git + projet Xcode

**Files:**
- Create: `.gitignore`
- Create: `project.yml`

**Step 1: Init git**

```bash
cd /Users/rbaumier/www/kcalz
git init
```

**Step 2: Créer .gitignore**

```gitignore
# Xcode
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
DerivedData/
build/
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
*.xccheckout
*.moved-aside
*.hmap
*.ipa
*.dSYM.zip
*.dSYM

# SPM
.build/
.swiftpm/

# macOS
.DS_Store
```

**Step 3: Installer xcodegen si absent**

```bash
which xcodegen || brew install xcodegen
```

**Step 4: Créer project.yml**

```yaml
name: kcalz
options:
  bundleIdPrefix: com.kcalz
  deploymentTarget:
    iOS: "17.0"
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "6.0"
    DEVELOPMENT_TEAM: ""

targets:
  kcalz:
    type: application
    platform: iOS
    sources:
      - path: kcalz
    settings:
      base:
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: true
        INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents: true
        INFOPLIST_KEY_UILaunchScreen_Generation: true
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
        INFOPLIST_KEY_CFBundleDisplayName: kcalz
        SWIFT_STRICT_CONCURRENCY: complete
    dependencies:
      - package: GRDB

packages:
  GRDB:
    url: https://github.com/groue/GRDB.swift
    from: "7.0.0"
```

**Step 5: Créer les répertoires**

```bash
mkdir -p kcalz/{App,Models,Views/{Dashboard,Components},Resources,Utils}
```

**Step 6: Créer Assets.xcassets**

`kcalz/Resources/Assets.xcassets/Contents.json` :
```json
{
  "info": { "author": "xcode", "version": 1 }
}
```

`kcalz/Resources/Assets.xcassets/AccentColor.colorset/Contents.json` :
```json
{
  "colors": [{
    "color": {
      "color-space": "srgb",
      "components": { "red": "0.345", "green": "0.800", "blue": "0.008", "alpha": "1.000" }
    },
    "idiom": "universal"
  }],
  "info": { "author": "xcode", "version": 1 }
}
```

**Step 7: Commit**

```bash
git add .gitignore project.yml docs/ kcalz/Resources/
git commit -m "init: project structure, xcodegen spec, design docs"
```

---

### Task 2: Thème

**Files:**
- Create: `kcalz/Utils/Theme.swift`

**Step 1: Créer Theme.swift**

```swift
import SwiftUI

// MARK: - Couleurs

extension Color {
    static let kcPrimary = Color(hex: 0x58CC02)
    static let kcSecondary = Color(hex: 0x1CB0F6)
    static let kcAccent = Color(hex: 0xFF9600)
    static let kcDanger = Color(hex: 0xFF4B4B)

    // Nutriments
    static let kcKcal = Color(hex: 0xFF9600)
    static let kcProteins = Color(hex: 0xFF4B4B)
    static let kcCarbs = Color(hex: 0x1CB0F6)
    static let kcFat = Color(hex: 0xFFC800)
    static let kcSugars = Color(hex: 0xCE82FF)
    static let kcSalt = Color(hex: 0x78C800)

    // Surfaces
    static let kcBackground = Color(hex: 0xF7F7F7)
    static let kcCard = Color.white

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Fonts

extension Font {
    static let kcTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let kcHeadline = Font.system(.title2, design: .rounded, weight: .bold)
    static let kcSubheadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let kcBody = Font.system(.body, design: .rounded)
    static let kcCaption = Font.system(.caption, design: .rounded, weight: .medium)
    static let kcNumber = Font.system(.title, design: .rounded, weight: .heavy)
    static let kcNumberSmall = Font.system(.body, design: .rounded, weight: .bold)
}

// MARK: - Animations

extension Animation {
    static let kcBounce = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let kcSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
}

// MARK: - View Modifiers

struct KcCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.kcCard)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

struct KcBounceButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.kcBounce, value: configuration.isPressed)
    }
}

extension View {
    func kcCard() -> some View { modifier(KcCardModifier()) }
}
```

**Step 2: Commit**

```bash
git add kcalz/Utils/
git commit -m "feat: theme — couleurs, fonts arrondies, animations bounce"
```

---

### Task 3: Modèles de données (structs simples, pas SwiftData)

On utilise des structs simples pour le hardcodé. SwiftData viendra quand on aura besoin de persistence.

**Files:**
- Create: `kcalz/Models/MealType.swift`
- Create: `kcalz/Models/FoodEntry.swift`
- Create: `kcalz/Models/Meal.swift`
- Create: `kcalz/Models/DayLog.swift`

**Step 1: Créer MealType**

```swift
import Foundation

enum MealType: String, CaseIterable, Identifiable {
    case breakfast = "Petit déjeuner"
    case lunch = "Déjeuner"
    case snack = "Goûter"
    case dinner = "Dîner"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .snack: "cup.and.saucer.fill"
        case .dinner: "moon.fill"
        }
    }
}
```

**Step 2: Créer FoodEntry**

```swift
import Foundation

struct FoodEntry: Identifiable {
    let id = UUID()
    var name: String
    var grams: Double
    var kcalPer100g: Double
    var proteinsPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var sugarsPer100g: Double?
    var saltPer100g: Double?

    var kcal: Double { kcalPer100g * grams / 100 }
    var proteins: Double { proteinsPer100g * grams / 100 }
    var carbs: Double { carbsPer100g * grams / 100 }
    var fat: Double { fatPer100g * grams / 100 }
}
```

**Step 3: Créer Meal**

```swift
import Foundation

struct Meal: Identifiable {
    let id = UUID()
    var type: MealType
    var entries: [FoodEntry]

    var totalKcal: Double { entries.reduce(0) { $0 + $1.kcal } }
    var totalProteins: Double { entries.reduce(0) { $0 + $1.proteins } }
    var totalCarbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double { entries.reduce(0) { $0 + $1.fat } }
}
```

**Step 4: Créer DayLog**

```swift
import Foundation

struct DayLog: Identifiable {
    let id = UUID()
    var date: Date
    var meals: [Meal]
    var weight: Double?

    var totalKcal: Double { meals.reduce(0) { $0 + $1.totalKcal } }
    var totalProteins: Double { meals.reduce(0) { $0 + $1.totalProteins } }
    var totalCarbs: Double { meals.reduce(0) { $0 + $1.totalCarbs } }
    var totalFat: Double { meals.reduce(0) { $0 + $1.totalFat } }

    func meal(for type: MealType) -> Meal? {
        meals.first { $0.type == type }
    }
}
```

**Step 5: Commit**

```bash
git add kcalz/Models/
git commit -m "feat: models simples — MealType, FoodEntry, Meal, DayLog"
```

---

### Task 4: Données hardcodées de preview

**Files:**
- Create: `kcalz/Models/PreviewData.swift`

**Step 1: Créer les données de test**

```swift
import Foundation

enum PreviewData {
    static let goal = (kcal: 2200, proteins: 140.0, carbs: 250.0, fat: 80.0)

    static let dayLog = DayLog(
        date: .now,
        meals: [
            Meal(type: .breakfast, entries: [
                FoodEntry(name: "Flocons d'avoine", grams: 60, kcalPer100g: 379, proteinsPer100g: 13.5, carbsPer100g: 67.7, fatPer100g: 6.9),
                FoodEntry(name: "Lait demi-écrémé", grams: 200, kcalPer100g: 46, proteinsPer100g: 3.2, carbsPer100g: 4.8, fatPer100g: 1.6),
                FoodEntry(name: "Banane", grams: 120, kcalPer100g: 89, proteinsPer100g: 1.1, carbsPer100g: 22.8, fatPer100g: 0.3),
            ]),
            Meal(type: .lunch, entries: [
                FoodEntry(name: "Poulet grillé", grams: 150, kcalPer100g: 165, proteinsPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6),
                FoodEntry(name: "Riz basmati", grams: 180, kcalPer100g: 130, proteinsPer100g: 2.7, carbsPer100g: 28.2, fatPer100g: 0.3),
            ]),
            Meal(type: .snack, entries: []),
            Meal(type: .dinner, entries: []),
        ],
        weight: 78.2
    )
}
```

**Step 2: Commit**

```bash
git add kcalz/Models/PreviewData.swift
git commit -m "feat: données hardcodées pour preview dashboard"
```

---

### Task 5: Dashboard — composants UI

**Files:**
- Create: `kcalz/Views/Components/KcalRingView.swift`
- Create: `kcalz/Views/Components/NutrientBarView.swift`
- Create: `kcalz/Views/Components/MealSectionView.swift`

**Step 1: Créer KcalRingView** — anneau circulaire de progression kcal

```swift
import SwiftUI

struct KcalRingView: View {
    let consumed: Double
    let goal: Int
    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(consumed / Double(goal), 1.0)
    }

    private var remaining: Int {
        max(goal - Int(consumed), 0)
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(.kcKcal.opacity(0.15), lineWidth: 20)

            // Progress
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(.kcKcal, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center text
            VStack(spacing: 4) {
                Text("\(remaining)")
                    .font(.kcNumber)
                    .foregroundStyle(.kcKcal)
                Text("restantes")
                    .font(.kcCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 160, height: 160)
        .onAppear {
            withAnimation(.kcBounce.delay(0.2)) {
                animatedProgress = progress
            }
        }
    }
}
```

**Step 2: Créer NutrientBarView** — barre horizontale pour un macro

```swift
import SwiftUI

struct NutrientBarView: View {
    let label: String
    let current: Double
    let goal: Double
    let color: Color
    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.kcCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(current))/\(Int(goal))g")
                    .font(.kcNumberSmall)
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geo.size.width * animatedProgress)
                }
            }
            .frame(height: 10)
        }
        .onAppear {
            withAnimation(.kcBounce.delay(0.3)) {
                animatedProgress = progress
            }
        }
    }
}
```

**Step 3: Créer MealSectionView** — section repas avec ses aliments

```swift
import SwiftUI

struct MealSectionView: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: meal.type.icon)
                    .foregroundStyle(.kcPrimary)
                Text(meal.type.rawValue)
                    .font(.kcSubheadline)
                Spacer()
                if meal.totalKcal > 0 {
                    Text("\(Int(meal.totalKcal)) kcal")
                        .font(.kcNumberSmall)
                        .foregroundStyle(.kcKcal)
                }
                Button {
                    // TODO: F5 — ajout aliment
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.kcPrimary)
                }
                .buttonStyle(KcBounceButton())
            }

            // Aliments
            if meal.entries.isEmpty {
                Text("Aucun aliment")
                    .font(.kcCaption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 28)
            } else {
                ForEach(meal.entries) { entry in
                    HStack {
                        Text(entry.name)
                            .font(.kcBody)
                        Spacer()
                        Text("\(Int(entry.grams))g")
                            .font(.kcCaption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(entry.kcal))")
                            .font(.kcNumberSmall)
                            .foregroundStyle(.kcKcal)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.leading, 28)
                }
            }
        }
        .kcCard()
    }
}
```

**Step 4: Commit**

```bash
git add kcalz/Views/Components/
git commit -m "feat: composants UI — KcalRing, NutrientBar, MealSection"
```

---

### Task 6: Dashboard — écran principal assemblé

**Files:**
- Create: `kcalz/Views/Dashboard/DashboardView.swift`
- Create: `kcalz/App/KcalzApp.swift`

**Step 1: Créer DashboardView**

```swift
import SwiftUI

struct DashboardView: View {
    let dayLog = PreviewData.dayLog
    let goal = PreviewData.goal

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Date header
                HStack {
                    Button { } label: {
                        Image(systemName: "chevron.left")
                            .font(.kcSubheadline)
                    }
                    Spacer()
                    Text(dateFormatter.string(from: dayLog.date).capitalized)
                        .font(.kcHeadline)
                    Spacer()
                    Button { } label: {
                        Image(systemName: "chevron.right")
                            .font(.kcSubheadline)
                    }
                }
                .foregroundStyle(.primary)
                .padding(.horizontal)

                // Kcal ring + poids
                HStack(spacing: 24) {
                    KcalRingView(consumed: dayLog.totalKcal, goal: goal.kcal)

                    VStack(alignment: .leading, spacing: 12) {
                        // Poids
                        if let weight = dayLog.weight {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Poids")
                                    .font(.kcCaption)
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(String(format: "%.1f", weight))
                                        .font(.kcNumber)
                                    Text("kg")
                                        .font(.kcCaption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Résumé kcal
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(dayLog.totalKcal)) consommées")
                                .font(.kcCaption)
                                .foregroundStyle(.secondary)
                            Text("sur \(goal.kcal) kcal")
                                .font(.kcCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .kcCard()

                // Barres macros
                VStack(spacing: 12) {
                    NutrientBarView(label: "Protéines", current: dayLog.totalProteins, goal: goal.proteins, color: .kcProteins)
                    NutrientBarView(label: "Glucides", current: dayLog.totalCarbs, goal: goal.carbs, color: .kcCarbs)
                    NutrientBarView(label: "Lipides", current: dayLog.totalFat, goal: goal.fat, color: .kcFat)
                }
                .kcCard()

                // Repas
                ForEach(dayLog.meals) { meal in
                    MealSectionView(meal: meal)
                }
            }
            .padding()
        }
        .background(.kcBackground)
    }
}

#Preview {
    DashboardView()
}
```

**Step 2: Créer KcalzApp.swift**

```swift
import SwiftUI

@main
struct KcalzApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
    }
}
```

**Step 3: Commit**

```bash
git add kcalz/Views/Dashboard/ kcalz/App/
git commit -m "feat: dashboard hardcodé — ring kcal, macros, repas, poids"
```

---

### Task 7: Générer le projet + vérifier le build

**Step 1: Générer le .xcodeproj**

```bash
cd /Users/rbaumier/www/kcalz
xcodegen generate
```

Expected: `Created project at kcalz.xcodeproj`

**Step 2: Résoudre les dépendances SPM**

```bash
xcodebuild -resolvePackageDependencies -project kcalz.xcodeproj -scheme kcalz
```

**Step 3: Build**

```bash
xcodebuild build \
  -project kcalz.xcodeproj \
  -scheme kcalz \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -quiet
```

Expected: `BUILD SUCCEEDED`

**Step 4: Fixer les erreurs éventuelles**

Lire les erreurs de compilation et corriger. Itérer jusqu'à `BUILD SUCCEEDED`.

**Step 5: Commit**

```bash
git add kcalz.xcodeproj
git commit -m "feat: projet Xcode généré — build OK"
```
