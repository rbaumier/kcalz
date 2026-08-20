# F12 — Scan code-barres

## Résumé

Scanner un code-barres (EAN-13, EAN-8, UPC-A) via la caméra pour rechercher un produit dans la base OFF et l'ajouter à un repas.

## Flow utilisateur

1. SearchView : tap icône barcode à côté du champ de recherche
2. Push BarcodeScannerView (plein écran, preview caméra + réticule)
3. Scan détecte un code → lookup `OFFStore.findByBarcode(code)`
4. Trouvé → push ProductDetailView (comme une recherche texte)
5. Non trouvé → alerte "Produit non trouvé", scanner reste actif

## Navigation

Nouveau `Route.scan(MealType)` dans le NavigationStack existant.

```
SearchView → BarcodeScannerView → ProductDetailView → pop to Dashboard
```

## Fichiers à créer

| Fichier | Rôle |
|---|---|
| `Views/Search/BarcodeScannerView.swift` | Vue SwiftUI avec preview caméra + overlay |

## Modifications existantes

| Fichier | Changement |
|---|---|
| `Models/Route.swift` | Ajouter `case scan(MealType)` |
| `Views/Dashboard/DashboardView.swift` | `.navigationDestination` pour `.scan` |
| `Views/Search/SearchView.swift` | Bouton barcode à côté du champ de recherche |
| `Stores/OFFStore.swift` | `func findByBarcode(_ code: String) -> OFFProduct?` |
| `project.yml` | `NSCameraUsageDescription` |

## BarcodeScannerView

- AVFoundation : `AVCaptureSession` + `AVCaptureMetadataOutput`
- Types : `.ean13`, `.ean8`, `.upca`
- Détection → vibration haptique + lookup OFF
- Anti-spam : ignorer détections pendant 1s après un scan
- UI : preview caméra plein écran, réticule central, texte "Scannez un code-barres"

## OFFStore.findByBarcode

```swift
func findByBarcode(_ code: String) -> OFFProduct?
// SELECT * FROM products WHERE code = ?
```

## Permissions

`NSCameraUsageDescription` : "kcalz utilise la caméra pour scanner les codes-barres des produits alimentaires."
