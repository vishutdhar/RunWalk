# RunWalk Project Overview

## Current Version: 1.5

RunWalk is a run-walk interval timer for **iOS and watchOS**. It uses **Swift 6.1+** and **SwiftUI** with a shared codebase architecture.

### Platforms & Requirements
- **iOS 17.0+** - iPhone app
- **watchOS 10.0+** - Standalone Apple Watch app
- **Swift 6.1+** with strict concurrency
- **HealthKit** for workout tracking

### Architecture Pattern
- **Model-View (MV)** using native SwiftUI state management
- No ViewModels - use `@State`, `@Observable`, `@Environment`, `@Binding`
- Business logic in services, views stay lightweight

---

## Project Structure

```
RunWalk/
├── RunWalk.xcodeproj/                # Xcode project (opens directly, no workspace)
├── RunWalk/                          # iOS app target
│   ├── Assets.xcassets/
│   ├── RunWalkApp.swift              # @main entry point
│   └── Info.plist
├── RunWalk Watch App/                # watchOS app target (embedded in iOS)
│   ├── Assets.xcassets/
│   └── RunWalkWatchApp.swift         # @main entry point
├── RunWalkPackage/                   # Swift Package (ALL development here)
│   ├── Package.swift
│   ├── Sources/
│   │   ├── RunWalkShared/            # Platform-agnostic code
│   │   │   ├── TimerPhase.swift      # .run, .walk enum
│   │   │   ├── IntervalDuration.swift # 30s, 1min, etc.
│   │   │   ├── WorkoutStats.swift    # Statistics struct
│   │   │   ├── Clock.swift           # Time abstraction
│   │   │   └── WorkoutRecord.swift   # Saved workout model
│   │   ├── RunWalkFeature/           # iOS-specific code
│   │   │   ├── ContentView.swift     # Main iOS view
│   │   │   ├── IntervalTimer.swift   # iOS timer logic
│   │   │   ├── SettingsView.swift    # iOS settings
│   │   │   ├── HealthKitManager.swift
│   │   │   ├── SoundManager.swift    # Bells + haptics
│   │   │   ├── VoiceAnnouncementManager.swift
│   │   │   └── WorkoutHistoryView.swift
│   │   └── RunWalkWatchFeature/      # watchOS-specific code
│   │       ├── WatchContentView.swift     # Main watch view
│   │       ├── WatchRunningView.swift     # Active workout
│   │       ├── WatchSummaryView.swift     # Post-workout
│   │       ├── WatchSettingsView.swift    # Watch settings
│   │       ├── WatchIntervalTimer.swift   # Watch timer logic
│   │       ├── WatchWorkoutManager.swift  # HKWorkoutSession
│   │       ├── WatchHapticManager.swift   # Distinct haptics
│   │       ├── WatchVoiceAnnouncementManager.swift
│   │       └── WatchWorkoutHistoryView.swift
│   └── Tests/
│       └── RunWalkFeatureTests/
├── Config/                           # Build configuration
│   ├── Shared.xcconfig               # iOS: bundle ID, version
│   ├── WatchShared.xcconfig          # watchOS: bundle ID, version
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   ├── Tests.xcconfig
│   ├── RunWalk.entitlements          # iOS capabilities
│   └── RunWalkWatch.entitlements     # watchOS capabilities
└── RunWalkUITests/
```

**Important:** ALL development happens in `RunWalkPackage/Sources/`. App targets are thin wrappers.

---

## Current Features (v1.5)

### iOS App
- 6 interval options (30s, 1min, 1.5min, 2min, 3min, 5min)
- Voice announcements ("Run" / "Walk")
- Bell sounds on phase transitions
- Haptic feedback
- Settings: Voice toggle, Bells toggle, Haptics toggle, GPS toggle
- HealthKit workout saving
- Workout history with detail view
- **GPS route tracking** with live map display
- **Route maps in workout history** (thumbnail + full map)
- **Distance tracking** with pace calculation
- Dark theme, works with screen locked

### Apple Watch App
- Standalone (works without iPhone)
- Same interval options
- HKWorkoutSession for background execution
- Distinct haptic patterns (run vs walk)
- Voice announcements
- Settings: Voice toggle, Bells toggle, Haptics toggle, GPS toggle
- Workout summary view
- Workout history with detail view
- **GPS route tracking** with live map display
- **Route maps in workout history**
- **Distance tracking**
- Counts toward Activity Rings

---

## Key Architecture Decisions

### 1. Shared Code (`RunWalkShared`)
Platform-agnostic types used by both iOS and watchOS:
- `TimerPhase` - `.run` or `.walk`
- `IntervalDuration` - time options enum
- `WorkoutStats` - statistics during workout
- `WorkoutRecord` - saved workout data

### 2. watchOS Background Execution
Watch app **requires** `HKWorkoutSession` to run in background:

```swift
// Without this, timer stops when wrist is lowered
let config = HKWorkoutConfiguration()
config.activityType = .running
let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
let builder = session.associatedWorkoutBuilder()
session.startActivity(with: Date())
try await builder.beginCollection(at: Date())
```

### 3. Embedded Watch App
Watch app is embedded in iOS app for single App Store submission:
- Archive the `RunWalk` scheme to get both apps
- Watch app bundle ID: `com.vishutdhar.RunWalk.watchkitapp`
- `WKRunsIndependentlyOfCompanionApp = YES` (still standalone)

### 4. Settings Storage
Both platforms use `@AppStorage` for settings persistence:
```swift
@AppStorage("voiceAnnouncementsEnabled") var voiceEnabled = false
@AppStorage("bellsEnabled") var bellsEnabled = true
@AppStorage("hapticsEnabled") var hapticsEnabled = true
```

---

## Code Style Guidelines

### Swift Conventions
- `UpperCamelCase` for types, `lowerCamelCase` for properties/functions
- Prefer `struct` for models, `class` only for reference semantics
- Early return pattern over nested conditionals
- Never force-unwrap without certainty

### SwiftUI State Management
- `@State` for view-specific state
- `@Observable` for shared state
- `@Environment` for dependency injection
- `@Binding` for two-way data flow
- **No ViewModels** - use native SwiftUI mechanisms

### Concurrency
- **Swift Concurrency only** - async/await, actors, @MainActor
- No GCD or completion handlers
- Use `.task { }` modifier for async work tied to view lifecycle
- Never use `Task { }` in `onAppear`

---

## Building & Testing

### Build Commands

```bash
# Build iOS simulator
xcodebuild -project RunWalk.xcodeproj -scheme RunWalk \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"

# Build watchOS simulator
xcodebuild -project RunWalk.xcodeproj -scheme "RunWalk Watch App" \
  -destination "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)"

# Archive for App Store (includes both iOS and embedded watch app)
xcodebuild -project RunWalk.xcodeproj -scheme RunWalk \
  -destination "generic/platform=iOS" \
  -configuration Release archive \
  -archivePath ~/Desktop/RunWalk.xcarchive
```

### Using XcodeBuildMCP

```javascript
// Set session defaults
session-set-defaults({
    projectPath: "/path/to/RunWalk.xcodeproj",
    scheme: "RunWalk",
    simulatorName: "iPhone 17 Pro Max"
})

// Build and run
build_run_sim()

// Take screenshot
screenshot()
```

### Testing
- Tests: `RunWalkPackage/Tests/RunWalkFeatureTests/`
- Framework: Swift Testing (`@Test`, `#expect`, `#require`)

---

## Entitlements

### iOS (`Config/RunWalk.entitlements`)
```xml
<key>com.apple.developer.healthkit</key>
<true/>
```

### watchOS (`Config/RunWalkWatch.entitlements`)
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>
```

---

## What's Next (Potential Features)

- Custom interval durations (user-defined times)
- Workout presets/programs (e.g., "5K Training")
- Apple Watch complications
- Siri shortcuts
- iOS widgets
- Heart rate zone integration
- Statistics and progress tracking
- Audio coaching messages

---

## Version History

| Version | Features |
|---------|----------|
| 1.5 | GPS route tracking, live maps, distance tracking, workout detail view |
| 1.4 | Apple Watch app, Bells/Haptics settings toggles |
| 1.3 | Workout history, HealthKit saving |
| 1.2 | Settings view, Voice toggle |
| 1.1 | Bug fixes |
| 1.0 | Initial release |

---

## Best Practices

### Do
- Write all code in `RunWalkPackage/Sources/`
- Use `@AppStorage` for simple settings
- Use `HKWorkoutSession` on watchOS for background
- Test on physical Apple Watch for haptics
- Keep views small and focused

### Don't
- Don't use ViewModels
- Don't use GCD or completion handlers
- Don't use CoreData (use SwiftData if needed)
- Don't add files to app targets directly
- Don't forget to update both xcconfig files for version changes
