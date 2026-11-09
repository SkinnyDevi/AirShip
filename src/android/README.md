# AirShip Android Client (src/android)

Native Kotlin 2 + Jetpack Compose client for AirShip consuming compiled Rust libraries via UniFFI / JNI.

## Architecture & Directory Structure

```
src/android/
├── build.gradle.kts           # Root gradle configuration
├── settings.gradle.kts        # Submodule / repository settings
├── gradle.properties          # JVM & AndroidX properties
├── gradlew                    # Unix gradle wrapper
├── app/                       # Android application module
│   ├── build.gradle.kts       # Jetpack Compose & dependency definitions
│   └── src/main/AndroidManifest.xml # Permissions (mDNS, Multicast, ForegroundService)
├── corebridge/                # UniFFI Kotlin bindings wrapped in Kotlin Coroutines and Flow<T>
├── designsystem/              # Reusable Compose components (Blimp logo, segmented toggle, floating bottom bar)
├── features/
│   ├── home/                  # Identity screen & primary mode entry point
│   ├── send/                  # Multi-source attachment staging list with item removal controls
│   ├── receive/               # Active listening screen with individual and batch download controls
│   ├── trustlist/             # Searchable contact list with inline user addition and trust toggles
│   └── settings/              # Preferences, background execution, and network diagnostics
└── service/                   # ForegroundService with MulticastLock & MediaStore streaming
```
