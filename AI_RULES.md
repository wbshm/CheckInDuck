# CheckInDuck AI Rules

## Project goals
- Privacy-first daily app-based habit tracker
- MVP first: stable, minimal, readable
- iOS 16+, SwiftUI, MVVM, local-first

## Architecture
- Keep files small and explicit
- Prefer direct dependency injection over abstract factories
- Avoid premature layers and generic overengineering

## Coding style
- Clear naming (`TodayView`, `TodayViewModel`, `TaskStore`)
- Keep comments only for non-obvious logic
- Use native Apple frameworks first
- Prefer deterministic behavior and testability

## Product constraints
- Users explicitly authorize Screen Time / Family Controls
- Users explicitly pick monitored apps via FamilyActivityPicker
- No content inspection in third-party apps

## Delivery rules
- Work in sequence by TODO task IDs
- After each completed change, sync `TODOLIST.md`
- Verify by build/test commands before claiming completion
