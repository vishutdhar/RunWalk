# RunWalk

A simple, beautiful run-walk interval timer for iOS and Apple Watch.

## Current Version: 1.5 (Build 3)

### What It Does

RunWalk helps runners use the run-walk method (popularized by Jeff Galloway) to build endurance, reduce injury risk, and enjoy running more. Just select your interval and tap Start - the app announces "Run!" and "Walk!" at each transition.

### Features

**iOS App**
- 6 research-based interval options (30s, 1min, 1.5min, 2min, 3min, 5min)
- **Custom interval durations** (10 seconds to 30 minutes)
- **Workout presets** (Easy Start, Beginner, Intermediate, Advanced, custom)
- Voice announcements ("Run" / "Walk")
- Bell sounds on phase transitions
- Haptic feedback
- HealthKit integration - workouts save to Health app
- **GPS route tracking** with live map display
- **Distance tracking** with pace calculation
- **Statistics & progress tracking** (streaks, weekly charts, all-time stats)
- Workout history with detail view and route maps
- **Siri Shortcuts** ("Hey Siri, start run walk workout")
- **iPad optimized layout**
- Dark theme optimized for outdoor use
- Works with screen locked (background audio)

**Apple Watch App**
- Standalone - works without iPhone
- Same interval options + presets as iOS
- Distinct haptic patterns for run vs walk phases
- Voice announcements via watch speaker
- **Heart rate zone display** (live HR + zone indicator during workout)
- **GPS route tracking** with live map display
- **Distance tracking**
- Workouts count toward Activity Rings
- Runs in background when wrist is lowered
- Workout history with route maps

**Settings** (iOS & Watch)
- Bells toggle - enable/disable ding sounds
- Voice toggle - enable/disable voice announcements
- Haptics toggle - enable/disable vibration feedback
- GPS toggle - enable/disable location tracking
- Age picker (watchOS) - for heart rate zone calculation

---

## Project Architecture

```
RunWalk/
├── RunWalk.xcodeproj/                # Main Xcode project
├── RunWalk/                          # iOS app target
│   ├── Assets.xcassets/
│   ├── RunWalkApp.swift              # @main entry point
│   └── Info.plist
├── RunWalk Watch App/                # watchOS app target
│   ├── Assets.xcassets/
│   ├── RunWalkWatchApp.swift         # @main entry point
│   └── (uses WatchShared.xcconfig)
├── RunWalkPackage/                   # Swift Package (main development area)
│   ├── Package.swift
│   ├── Sources/
│   │   ├── RunWalkShared/            # Platform-agnostic code
│   │   │   ├── TimerPhase.swift
│   │   │   ├── IntervalDuration.swift
│   │   │   ├── WorkoutStats.swift
│   │   │   ├── WorkoutStatistics.swift
│   │   │   ├── Clock.swift
│   │   │   ├── WorkoutRecord.swift
│   │   │   ├── WorkoutPreset.swift
│   │   │   └── HeartRateZone.swift
│   │   ├── RunWalkFeature/           # iOS-specific code
│   │   │   ├── ContentView.swift
│   │   │   ├── IntervalTimer.swift
│   │   │   ├── SettingsView.swift
│   │   │   ├── HealthKitManager.swift
│   │   │   ├── SoundManager.swift
│   │   │   ├── VoiceAnnouncementManager.swift
│   │   │   ├── WorkoutHistoryView.swift
│   │   │   ├── WorkoutDetailView.swift
│   │   │   ├── StatisticsView.swift
│   │   │   ├── PresetsView.swift
│   │   │   ├── RouteMapView.swift
│   │   │   ├── iOSLocationManager.swift
│   │   │   └── AppIntents/
│   │   │       └── RunWalkIntents.swift
│   │   └── RunWalkWatchFeature/      # watchOS-specific code
│   │       ├── WatchContentView.swift
│   │       ├── WatchRunningView.swift
│   │       ├── WatchSummaryView.swift
│   │       ├── WatchSettingsView.swift
│   │       ├── WatchIntervalTimer.swift
│   │       ├── WatchWorkoutManager.swift
│   │       ├── WatchHapticManager.swift
│   │       ├── WatchVoiceAnnouncementManager.swift
│   │       ├── WatchWorkoutHistoryView.swift
│   │       ├── WatchWorkoutDetailView.swift
│   │       ├── WatchRouteMapView.swift
│   │       └── WatchLocationManager.swift
│   └── Tests/
│       └── RunWalkFeatureTests/
├── Config/                           # Build configuration
│   ├── Shared.xcconfig               # iOS settings (version, bundle ID)
│   ├── WatchShared.xcconfig          # watchOS settings
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   ├── Tests.xcconfig
│   ├── RunWalk.entitlements          # iOS capabilities
│   └── RunWalkWatch.entitlements     # watchOS capabilities
└── RunWalkUITests/                   # UI automation tests
```

### Key Architecture Decisions

1. **Workspace + SPM Package** - Business logic lives in the Swift Package, app targets are thin wrappers
2. **Shared Code** - `RunWalkShared` contains platform-agnostic types shared between iOS and watchOS
3. **Embedded Watch App** - Watch app is embedded in iOS app for single App Store submission
4. **HKWorkoutSession** - Watch app uses HealthKit workout session for background execution
5. **App Intents** - Siri Shortcuts integration using iOS 16+ App Intents framework
6. **Model-View (MV)** - No ViewModels, using native SwiftUI state management

---

## Configuration

### Build Settings (XCConfig)

| File | Purpose |
|------|---------|
| `Config/Shared.xcconfig` | iOS bundle ID, version, deployment target |
| `Config/WatchShared.xcconfig` | watchOS bundle ID, version, deployment target |
| `Config/Debug.xcconfig` | Debug-specific settings |
| `Config/Release.xcconfig` | Release-specific settings |

### Current Version Settings

```
MARKETING_VERSION = 1.5
CURRENT_PROJECT_VERSION = 3
IPHONEOS_DEPLOYMENT_TARGET = 17.0
WATCHOS_DEPLOYMENT_TARGET = 10.0
```

### Entitlements

**iOS** (`Config/RunWalk.entitlements`)
- HealthKit

**watchOS** (`Config/RunWalkWatch.entitlements`)
- HealthKit
- HealthKit Background Delivery

---

## Development

### Building

1. Open `RunWalk.xcodeproj` in Xcode
2. Select the `RunWalk` scheme for iOS or `RunWalk Watch App` scheme for watchOS
3. Build and run on simulator or device

### Testing

- Unit tests: `RunWalkPackage/Tests/RunWalkFeatureTests/`
- UI tests: `RunWalkUITests/`
- Uses Swift Testing framework (`@Test`, `#expect`)

### Archiving for App Store

The watch app is embedded in the iOS app. Archive the `RunWalk` scheme to create a single archive containing both apps.

```bash
xcodebuild -project RunWalk.xcodeproj -scheme RunWalk \
  -destination "generic/platform=iOS" \
  -configuration Release archive \
  -archivePath ~/Desktop/RunWalk.xcarchive
```

---

## Version History

| Version | Features |
|---------|----------|
| 1.5 (Build 3) | Statistics & progress tracking, Siri Shortcuts, Heart rate zones on watchOS |
| 1.5 (Build 2) | "Acquiring GPS Signal" message, iPad layout fixes, swipeable workout pages |
| 1.5 (Build 1) | GPS route tracking, live maps, distance tracking, workout detail view |
| 1.4 | Apple Watch app, Bells/Haptics settings toggles |
| 1.3 | Workout history, HealthKit saving |
| 1.2 | Settings view, Voice toggle |
| 1.1 | Bug fixes |
| 1.0 | Initial release |

---

## What's Next

Potential future features:
- iOS widgets
- Audio coaching messages
- Social sharing / challenges
- Apple Watch complications (beyond current implementation)
- Export workout data

---

## AI Assistant Rules

This project includes rules files for AI coding assistants:
- **Claude Code**: `CLAUDE.md`
- **GitHub Copilot**: `.github/copilot-instructions.md`

These establish coding standards for SwiftUI, Swift Concurrency, and the MV (Model-View) architecture pattern used in this project.

---

## Links

- **App Store**: [RunWalk on App Store](https://apps.apple.com/app/runwalk)
- **Privacy Policy**: [Privacy Policy](https://vishutdhar.github.io/RunWalk/privacy.html)
- **Support**: [GitHub Issues](https://github.com/vishutdhar/RunWalk/issues)

---

*Built with Swift 6.1+, SwiftUI, and HealthKit*
