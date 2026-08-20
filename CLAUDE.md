# kcalz

App iOS Swift/SwiftUI de suivi nutritionnel.

## Build & Deploy sur iPhone

```bash
# Build
xcodebuild -scheme kcalz -project kcalz.xcodeproj -destination 'id=<DEVICE_ID>' -allowProvisioningUpdates build

# Trouver le device ID
xcrun xctrace list devices

# Installer sur iPhone
xcrun devicectl device install app --device <DEVICE_ID> ~/Library/Developer/Xcode/DerivedData/kcalz-gwzexsxqddhzsgaxltnqlzgibczs/Build/Products/Debug-iphoneos/kcalz.app
```

## "kcalz is no longer available"

Le build de dev expire (provisioning profile). Les données utilisateur (`user.sqlite` dans Application Support) restent sur le téléphone.

**Fix** : redéployer depuis Xcode (build + install ci-dessus). Ne PAS supprimer l'app avant, sinon le container de données est perdu.
