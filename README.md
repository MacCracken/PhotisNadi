# Photis Nadi

A cross-platform productivity application combining Kanban-style task management with daily ritual tracking.

## Features

- **Kanban Board**: Horizontal-scrolling task management similar to Trello
- **Project Management**: Organize tasks into projects with unique keys (e.g., WK-1, WK-2)
- **Daily Rituals**: Persistent sidebar checklist for recurring daily, weekly, or monthly tasks
- **Dual-Mode UI**: Vibrant glassmorphism mode and E-reader friendly high-contrast mode
- **Cross-Platform**: Native performance on macOS, iOS, Linux desktop, and Linux mobile
- **Local-First**: Offline-first data storage with optional Supabase cloud sync
- **Conflict Resolution**: Last-write-wins sync with `modifiedAt` timestamps

## Technical Stack

- **Framework**: Flutter 3.10+
- **Database**: Hive for local storage
- **State Management**: Provider + Riverpod
- **Cloud Sync**: Supabase (optional, real-time subscriptions)
- **Desktop Integration**: window_manager, system_tray
- **UI**: Material 3 with custom glassmorphism effects

## Usage

For detailed instructions on how to use Photis Nadi, including the Kanban board, projects, daily rituals, theme modes, and troubleshooting, see the [USAGE.md](USAGE.md) guide.

## Installation

### Prerequisites

- Flutter SDK 3.10.0 or higher
- For desktop builds: Platform-specific development tools

### Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Generate model adapters:
   ```bash
   flutter packages pub run build_runner build --delete-conflicting-outputs
   ```

## Development

### Build Commands

```bash
# Development
flutter run                    # Run in debug mode
flutter run --release         # Run in release mode

# Platform-specific builds
flutter build macos           # macOS app
flutter build linux           # Linux executable
flutter build apk             # Android APK
flutter build ios             # iOS app

# Testing
flutter test                  # Run all tests
flutter test test/unit_test.dart  # Run specific test
```

### Linting and Code Quality

```bash
# Lint code
flutter analyze

# Format code
dart format .

# Generate code (models, etc.)
flutter packages pub run build_runner build --delete-conflicting-outputs
```

## Project Structure

```
lib/
├── models/          # Data models (Task, Ritual, Board, Project)
│   ├── task.dart         # Task with status, priority, projectId, taskKey, modifiedAt
│   ├── ritual.dart       # Ritual with frequency, streak tracking, reset logic
│   ├── board.dart        # Board and BoardColumn definitions
│   └── project.dart      # Project with key-based task numbering, modifiedAt
├── services/        # Business logic and state management
│   ├── task_service.dart       # CRUD for tasks, rituals, and projects
│   ├── theme_service.dart      # Theme preferences (vibrant/e-reader/dark)
│   ├── sync_service.dart       # Supabase sync with conflict resolution
│   └── desktop_integration.dart # Window manager and system tray
├── screens/         # UI screens
│   └── home_screen.dart  # Main layout: ProjectSidebar | KanbanBoard | RitualsSidebar
├── widgets/         # Reusable UI components
│   ├── kanban_board.dart      # Drag-and-drop task columns
│   ├── project_sidebar.dart   # Project list, selection, and management
│   ├── rituals_sidebar.dart   # Ritual checklist with streaks
│   └── theme_toggle.dart      # Theme mode switcher
├── themes/          # App theming and styling
│   └── app_theme.dart    # Vibrant, dark, and e-reader themes
└── main.dart        # App entry point, Hive initialization
```

## Data Models

### Task
- `id`, `title`, `description`, `status` (todo/inProgress/done)
- `priority` (low/medium/high), `dueDate`, `tags`
- `projectId` — links to a Project
- `taskKey` — project-scoped key (e.g., "WK-3")
- `createdAt`, `modifiedAt` — used for sync conflict resolution

### Project
- `id`, `name`, `key` — short uppercase key for task numbering
- `description`, `color`, `iconName`
- `taskCounter` — auto-incrementing counter for task keys
- `isArchived`, `createdAt`, `modifiedAt`

### Ritual
- `id`, `title`, `description`
- `frequency` (daily/weekly/monthly)
- `isCompleted`, `streakCount`, `lastCompleted`, `resetTime`
- Auto-resets based on frequency (daily at midnight, weekly on new ISO week, monthly on new month)

## Sync Architecture

The app uses a local-first approach:
1. All data stored locally in Hive database
2. Optional Supabase cloud sync for tasks, projects, and rituals
3. Conflict resolution via `modifiedAt` timestamps (last-write-wins)
4. Real-time subscriptions for live updates across devices
5. `syncAll()` syncs projects first, then tasks, then rituals

## Code Style Guidelines

### Import Style
- Use `flutter/material.dart` first
- Group imports: external, internal, relative
- Use relative imports for files within lib/
- Sort imports alphabetically

### Formatting
- Use 2-space indentation
- Maximum line length: 80 characters
- Use trailing commas for multi-line parameters
- Use single quotes for strings

### Naming Conventions
- Variables: `camelCase`
- Functions: `camelCase`
- Classes: `PascalCase`
- Constants: `UPPER_SNAKE_CASE`
- Files: `snake_case.dart`
- Directories: `snake_case`

## Testing

- 26 unit tests covering task CRUD, project management, ritual reset logic, and model behavior
- Write unit tests for all service classes
- Use descriptive test names following `describe...when...should` pattern
- Mock external dependencies
- Test edge cases and error conditions

Run tests:
```bash
flutter test
```

## Platform Integration

### macOS Features
- Menu bar integration via window_manager
- Always-on-top floating window mode
- Native system tray support

### Linux Features
- AppImage build support
- Flatpak packaging ready
- System tray integration

## Build & Distribution

### macOS
```bash
flutter build macos --release
# Creates .app bundle in build/macos/Build/Products/Release/
```

### Linux
```bash
flutter build linux --release
# Creates executable in build/linux/x64/release/bundle/
```

## Contributing

1. Fork the repository
2. Create a feature branch from main
3. Make changes with descriptive commits
4. Run linting and tests locally
5. Submit pull request for review

## Code Review TODOs

Based on comprehensive code audit, the following improvements are identified:

### Critical Issues

#### 1. Architecture & Code Organization ✅ COMPLETED
- **Refactor oversized widgets**: 
  - ✅ `kanban_board.dart` (925 → 416 lines) - extracted dialogs, cards, and utilities
  - ✅ `project_sidebar.dart` (697 → 331 lines) - extracted dialog components
  - ✅ `rituals_sidebar.dart` (411 → 320 lines) - extracted dialog components
- **DRY Violations**: ✅ Extracted duplicated color parsing (`_parseColor`) to `common/utils.dart`
- **UI Component Library**: ✅ Created reusable dialog components in `widgets/dialogs/`

#### 2. Model Issues
- **Mutability**: All model fields are mutable (no `final` keyword) - violates immutability
  - Files: `task.dart`, `ritual.dart`, `project.dart`, `board.dart`
- **Missing validation**: No validation for hex color strings, empty keys, or malformed data
- **Unsafe null handling**: Line 68 in `ritual.dart` - `taskKey` can be null but used without check

#### 3. Service Layer Issues

**TaskService (`task_service.dart`)**:
- Line 119: Direct field mutation `task.status = newStatus` - violates encapsulation
- Lines 203, 222: Direct model mutations instead of using copyWith
- ✅ Error handling added for all database operations with try-catch blocks and logging
- ✅ Line 11: Boxes changed to `late final`
- Potential race condition: Multiple async operations without proper locking

**SyncService (`sync_service.dart`)**:
- ✅ Replaced `debugPrint()` with proper `developer.log()` logging
- ✅ Added retry logic with exponential backoff and configurable max retries
- ✅ Added timeout handling for all Supabase operations with `_executeWithRetry` helper
- Lines 46-69, 152-167, 249-269: **Duplicated parsing logic** - extract to factory methods
- Memory leak risk: Real-time subscriptions not properly disposed
- ✅ Added `SyncException` class for structured error handling
- ✅ Added error recovery mechanism for partial sync failures
- ✅ All sync methods now return `bool` for success/failure indication

**ThemeService (`theme_service.dart`)**:
- ✅ Added error handling for SharedPreferences operations with try-catch and logging
- ✅ All toggle methods now return `bool` for success/failure and revert state on error

#### 4. Main.dart Issues
- Lines 23-30: Missing `const` keyword for adapter registrations
- Lines 33-36: No error handling for Hive box opening
- Line 44: Class name is `LuminaFlowApp` should be `PhotisNadiApp`
- No app initialization error recovery

#### 5. UI/UX Issues
- **theme_toggle.dart**: Dark mode toggle doesn't actually switch themes (UI only)
- **app_theme.dart**: 
  - Lines 235-261: `glassCard()` method is defined but never used
  - Unused import: `glassmorphism` package imported but minimally used
- **home_screen.dart**: Missing error boundaries and loading states
- **rituals_sidebar.dart**: Line 122 - Bug in completion counter displays `$completedCount/$completedCount` instead of `$completedCount/$totalCount`

#### 6. Error Handling & Robustness
- **Missing try-catch blocks** in:
  - ✅ All database write operations in TaskService
  - ✅ JSON parsing in SyncService with error recovery
  - Color parsing across widgets
  - Date parsing operations
- ✅ Added proper error handling throughout services with structured logging
- No fallback UI for error states
- No loading indicators for async operations
- Potential null pointer exceptions throughout

#### 7. Performance Issues
- **kanban_board.dart**: 
  - Line 39-59: ListView rebuilds entire board on every task change
  - No pagination for large task lists
  - Images (if added) not cached
- **Memory leaks**: 
  - ✅ ScrollController disposed in kanban_board.dart
  - TextEditingControllers not disposed in dialogs
  - Stream subscriptions not cancelled

#### 8. Testing Gaps
- Only 26 unit tests covering basic CRUD
- Missing widget tests for UI components
- Missing integration tests for sync
- No error scenario tests
- Tests don't cover edge cases (null values, empty strings, long text)

#### 9. Code Style Issues
- Inconsistent spacing (some files use trailing commas, others don't)
- Some long methods violate single responsibility principle
- Magic numbers throughout (e.g., line length limits, padding values)

#### 10. Dependencies
- **Unused packages to audit**:
  - `riverpod` imported but only Provider used
  - `glassmorphism` - verify actual usage
  - `flutter_staggered_animations` - verify actual usage

### Refactoring Priority

**High Priority:**
1. ✅ Split oversized widget files - COMPLETED
2. ✅ Add error handling to all service methods - COMPLETED
   - ✅ TaskService: Added try-catch blocks, logging, and bool return values
   - ✅ SyncService: Added retry logic with exponential backoff, timeout handling, SyncException class
   - ✅ ThemeService: Added error handling with state rollback on failure
3. Extract duplicated parsing logic in SyncService
4. Fix mutability issues in models (use copyWith exclusively)
5. Fix the rituals sidebar completion counter bug

**Medium Priority:**
6. ✅ Extract reusable UI components - COMPLETED
7. Add proper logging throughout
8. Dispose controllers and cancel subscriptions
9. Add const constructors where missing
10. Add validation to models

**Low Priority:**
11. Remove unused imports and dependencies
12. Add more comprehensive tests
13. Optimize performance for large lists
14. Rename LuminaFlowApp to PhotisNadiApp

## License

MIT License - see LICENSE file for details.
