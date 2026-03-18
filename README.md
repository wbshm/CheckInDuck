# CheckInDuck

Privacy-first iOS habit tracker MVP.

## Product Goal

Users authorize Screen Time / Family Controls, select one app to monitor, set a daily deadline, and get checked in automatically after the selected app reaches the configured usage threshold. If the task is still incomplete at the deadline, the app sends a reminder.

## Stack

- Swift
- SwiftUI
- MVVM
- iOS 16+
- StoreKit 2
- FamilyControls / DeviceActivity

## Verified Project Status

As of 2026-03-18, the codebase is no longer at "scaffold" stage. The MVP core loop is mostly implemented and the project is in debug / cleanup / documentation stage.

Implemented in code:

- Root tabs: `Today / History / Settings`
- Task creation flow with app selection, deadline, and auto check-in threshold
- Family Controls authorization flow and persisted authorization state
- DeviceActivity monitor extension for app-usage threshold callbacks
- Home Screen widget for today's task status (`systemSmall` / `systemMedium`)
- Reminder scheduling and deadline-time-sensitive notifications
- History page with free-tier window limits
- Premium boundary and StoreKit purchase / restore flow
- Diagnostics panel for monitor and app group state
- Shared App Group persistence path for app / monitor extension / widget reads

Verified locally in this workspace:

- `xcodebuild -list -project CheckInDuck.xcodeproj` shows 5 targets
- `xcodebuild build -scheme CheckInDuck -destination 'platform=iOS Simulator,name=iPhone 17'` passes
- `xcodebuild test -scheme CheckInDuck -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:CheckInDuckTests` passes
- Current automated unit coverage includes 13 passing tests
- Current automated unit coverage is focused on monitoring / reminder regression paths

Known limitations of current verification:

- UI tests are still placeholder-level launch tests
- Widget is currently read-only and intentionally limited to `systemSmall` / `systemMedium`
- Real Screen Time / Family Controls behavior still depends on real device capability, entitlement environment, and extension runtime behavior outside normal simulator coverage

## Project Structure

- `CheckInDuck/Features/Today`: dashboard and task status flow
- `CheckInDuck/Features/CreateTask`: task creation and app selection
- `CheckInDuck/Features/History`: record browsing and premium gating
- `CheckInDuck/Features/Settings`: permissions, reminders, subscription, diagnostics
- `CheckInDuck/Services`: authorization, monitoring, reminders, subscription, diagnostics
- `CheckInDuck/Storage`: local persistence
- `CheckInDuck/WidgetSupport`: shared app-side storage helpers for widget refresh / app group access
- `CheckInDuckWidget`: WidgetKit extension for today status
- `CheckInDuckDeviceActivityMonitor`: DeviceActivity monitor extension
- `Config/`: extension plist and related configuration

## Current Assessment

The project is functionally close to MVP-complete, but not yet "finished engineering work". The remaining work is mainly:

- close the last debug loop for Screen Time / extension edge cases
- refactor and clean parts that were stabilized during debugging
- improve developer documentation and handoff clarity
- expand verification beyond basic unit coverage

For the detailed execution record and task-by-task status, see `TODOLIST.md`.
