# Copilot Custom Instructions

## Project Overview

RunWalk is a run-walk interval timer app for iOS and watchOS. It uses a workspace + SPM package architecture with shared code between platforms.

## Tech Stack

- **Swift 6.1+** with strict concurrency
- **SwiftUI** for all UI
- **iOS 17.0+** and **watchOS 10.0+**
- **HealthKit** for workout tracking
- **Swift Package Manager** for modular architecture

## Architecture

### Package Structure

```
RunWalkPackage/
├── Sources/
│   ├── RunWalkShared/        # Platform-agnostic code (shared)
│   ├── RunWalkFeature/       # iOS-specific code
│   └── RunWalkWatchFeature/  # watchOS-specific code
```

### Pattern: Model-View (MV)

- Use `@State`, `@Observable`, `@Environment`, `@Binding` for state management
- **Do NOT use ViewModels or MVVM**
- Business logic in services, views stay lightweight

## Key Guidelines

1. **Swift Concurrency Only** - Use async/await, actors, @MainActor. No GCD or completion handlers.

2. **Write Code in the Package** - All features go in `RunWalkPackage/Sources/`, not in app targets.

3. **Shared Code** - Platform-agnostic types belong in `RunWalkShared`. Use conditional compilation (`#if os(iOS)`) sparingly.

4. **Swift Testing Framework** - Use `@Test`, `#expect`, `#require` for tests. Tests go in `RunWalkPackage/Tests/`.

5. **HealthKit on watchOS** - Watch app uses `HKWorkoutSession` for background execution. This is required for the timer to run when wrist is lowered.

6. **Data Persistence** - Use `@AppStorage` for simple settings. SwiftData only for complex data (prefer simpler options first).

7. **Accessibility** - Always provide accessibility labels and identifiers for UI elements.

## Build Commands

Use XcodeBuildMCP tools or:

```bash
# Build iOS
xcodebuild -project RunWalk.xcodeproj -scheme RunWalk -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"

# Build watchOS
xcodebuild -project RunWalk.xcodeproj -scheme "RunWalk Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)"

# Archive (includes both iOS and embedded watch app)
xcodebuild -project RunWalk.xcodeproj -scheme RunWalk -destination "generic/platform=iOS" archive
```

## Current Features (v1.4)

- 6 interval durations (30s to 5min)
- Voice announcements, bells, haptics (all toggleable in Settings)
- HealthKit workout saving
- Workout history
- Standalone Apple Watch app with distinct haptic patterns

## What's Next

Potential future features to consider:
- Custom interval durations
- Workout presets/programs
- Apple Watch complications
- Siri shortcuts
- iOS widgets
- Heart rate zones
- GPS tracking
