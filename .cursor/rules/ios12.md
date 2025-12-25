---
alwaysApply: true
description: "Enforce iOS 12 compatibility rules for the project."
globs: ["**/*.swift", "**/*.plist", "**/*.pbxproj"]
---
# iOS 12 Compatibility Rules

1. **Deployment Target**:
   - The project's Minimum Deployment Target MUST be set to **iOS 12.0** (or lower).

2. **App Lifecycle**:
   - MUST use the traditional `AppDelegate` lifecycle.
   - **FORBIDDEN**: `UIScene`, `UISceneSession`, `SceneDelegate`, and `UIApplicationSceneManifest` in `Info.plist` are NOT allowed for the main app entry point.
   - **REQUIRED**: `AppDelegate` class must include `var window: UIWindow?`.

3. **API Restrictions**:
   - Do NOT use iOS 13+ specific frameworks (like SwiftUI, Combine, CryptoKit) without strict `@available(iOS 13.0, *)` guards.
   - Do NOT use iOS 13+ UI elements (e.g., `UIColor.systemBackground`, `SF Symbols` system names) without fallback for iOS 12.

4. **Code Generation**:
   - When generating new ViewControllers or startup code, always use the pre-iOS 13 style (no SceneDelegate).

5. **Layout & Orientation**:
   - MUST support both Portrait and Landscape orientations (iPad standard).
   - Use Auto Layout and Safe Area guides for all UI to ensure proper resizing on rotation.
   - Avoid hardcoded frames or fixed screen dimensions; rely on constraints to handle size changes.

