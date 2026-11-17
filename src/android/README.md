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
│   └── src/main/
│       ├── AndroidManifest.xml # Permissions (mDNS, Multicast, ForegroundService)
│       └── java/com/airship/MainActivity.kt # Compose entry point & tab orchestration
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

## Prerequisites

- **Android Studio** supporting AGP `8.8.0` and Kotlin `2.1.0` (e.g., Android Studio Ladybug / Meerkat or newer).
- **Android SDK Platform 35** (`compileSdk = 35`, `targetSdk = 35`, `minSdk = 26`).
- **JDK 17+** (Gradle compiles with Java 17 target compatibility; Android Studio's bundled JetBrains Runtime works out of the box).

## Compiling & Running in Android Studio

1. Open **Android Studio** and choose **File > Open...**, then select the **`src/android/`** directory (not the repository root) so Android Studio loads `settings.gradle.kts` and `build.gradle.kts`.
2. Wait for **Gradle Sync** to finish resolving dependencies.
3. Choose an Android Emulator (API 26+) or a physical Android device with USB debugging enabled from the device selector.
4. Compile the project via **Build > Make Project** (`Cmd + F9` on macOS / `Ctrl + F9` on Linux/Windows).
5. Launch the app by selecting the **`app`** run configuration and clicking **Run** (`Ctrl + R` on macOS / `Shift + F10` on Linux/Windows).
   > *Note*: `MainActivity` currently initializes the ViewModels with `MockCoreBridge` until the compiled Rust `.so` libraries and UniFFI Kotlin bindings are wired into `corebridge/`.
6. To run unit tests in Android Studio, right-click `app/src/test/java/com/airship/AirShipViewModelTest.kt` and select **Run 'AirShipViewModelTest'**.

> **Source-Set Layout Note**: `MainActivity.kt` resides in `app/src/main/java/com/airship/MainActivity.kt`, and `app/build.gradle.kts` `sourceSets` includes `../corebridge`, `../designsystem`, `../features`, `../service`, and `src/main/java`.

## Compiling & Testing via Gradle CLI

You can run Gradle from the repository root (`AirShip/`) using the delegating `./gradlew` script, or directly inside `src/android/`:

```bash
cd src/android

# Compile the debug APK
./gradlew assembleDebug

# Run JVM unit tests
./gradlew testDebugUnitTest
```

If `java` is not configured in your shell `PATH` on macOS, export `JAVA_HOME` to Android Studio's bundled JBR first:

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
./gradlew testDebugUnitTest
```

## Linking the Rust Core (`src/core`)

1. Cross-compile `airship-ffi` (`cdylib`) from `src/core` for Android ABIs (`arm64-v8a`, `armeabi-v7a`, `x86_64`) using `cargo-ndk` into `src/android/app/src/main/jniLibs/`.
2. Generate the UniFFI Kotlin bindings into `corebridge/` (and add the JNA dependency if required by the generated bindings).
3. Replace `MockCoreBridge` in `MainActivity.kt` with the live UniFFI bridge implementation.
