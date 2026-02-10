# AGENTS.md

This file contains instructions for agentic coding agents working in this repository.

## Project Overview

Photis Nadi is a cross-platform productivity application combining Kanban-style task management with daily ritual tracking. Built with Flutter for native performance across macOS, iOS, Linux desktop, and Linux mobile.

## Build, Lint, and Test Commands

### Building the Project
```bash
# Development builds
flutter run                    # Run in debug mode
flutter run --release         # Run in release mode

# Platform-specific builds
flutter build macos           # macOS app
flutter build linux           # Linux executable
flutter build apk             # Android APK
flutter build ios             # iOS app
```

### Linting
```bash
flutter analyze               # Analyze code for issues
dart format .                # Format all Dart files
```

### Testing
```bash
# Run all tests
flutter test                  # Run all unit and widget tests

# Run single test file
flutter test test/unit_test.dart  # Run specific test file

# Run tests with coverage
flutter test --coverage       # Generate coverage report
```

### Code Generation
```bash
# Generate Hive adapters and other generated files
flutter packages pub run build_runner build
flutter packages pub run build_runner build --delete-conflicting-outputs
flutter packages pub run build_runner watch  # Watch for changes
```

## Recent Code Improvements

### Fixed Issues
- **Syntax Error**: Fixed syntax error in `lib/services/sync_service.dart:217-218` where duplicate `modified_at` field was present
- **Missing Adapters**: Added BoardAdapter and BoardColumnAdapter registration in test file `test/unit_test.dart`
- **Font Assets**: Removed empty font files and updated `pubspec.yaml` to remove non-existent font references
- **Unused Dependencies**: Removed unused dependencies:
  - `riverpod` (not used, only `provider` is used)
  - `flutter_staggered_animations` (not used anywhere)
  - `glassmorphism` (unused glassCard method removed)
- **Import Cleanup**: Cleaned up unused imports in `lib/themes/app_theme.dart`

## Code Style Guidelines

### Import Style
- Use `flutter/material.dart` first if needed
- Group imports: external packages, internal files, relative imports
- Sort imports alphabetically within each group
- Use relative imports for files within lib/
- Remove unused imports

### Formatting
- Use 2-space indentation (Flutter default)
- Maximum line length: 80 characters
- Use trailing commas for multi-line parameters and lists
- Use single quotes for strings
- Follow `dart format .` output

### Type Annotations
- Always type function parameters and return values for public APIs
- Use explicit types for service classes and models
- Use `var` for local variables with inferred types
- Type all Hive model fields with @HiveField annotations

### Naming Conventions
- Variables: `camelCase`
- Functions: `camelCase`
- Classes: `PascalCase`
- Constants: `UPPER_SNAKE_CASE`
- Files: `snake_case.dart`
- Directories: `snake_case`
- Private members: prefix with `_`

### Error Handling
- Use try-catch blocks for async operations
- Log errors with appropriate context
- Provide user-friendly error messages in UI
- Use proper error propagation with `async`/`await`
- Handle Hive exceptions gracefully
- Network operations should include timeout and retry logic

## File Structure

```
photisnadi/
├── lib/
│   ├── models/          # Data models (Task, Ritual, Board, Project)
│   │   ├── task.dart         # Task with projectId, taskKey, modifiedAt
│   │   ├── ritual.dart       # Ritual with daily/weekly/monthly reset
│   │   ├── board.dart        # Board and BoardColumn
│   │   └── project.dart      # Project with key-based task numbering
│   ├── services/        # Business logic and state management
│   │   ├── task_service.dart       # CRUD for tasks, rituals, projects
│   │   ├── theme_service.dart      # Theme preferences
│   │   ├── sync_service.dart       # Supabase sync with conflict resolution
│   │   └── desktop_integration.dart
│   ├── screens/         # UI screens
│   │   └── home_screen.dart  # ProjectSidebar | KanbanBoard | RitualsSidebar
│   ├── widgets/         # Reusable UI components
│   │   ├── kanban_board.dart      # Drag-and-drop task columns
│   │   ├── project_sidebar.dart   # Project list and selection
│   │   ├── rituals_sidebar.dart   # Ritual checklist with streaks
│   │   └── theme_toggle.dart
│   ├── themes/          # App theming and styling
│   │   └── app_theme.dart
│   ├── utils/           # Utility functions
│   └── main.dart        # App entry point, Hive adapter registration
├── test/                # Test files (26 unit tests)
├── assets/              # Images, fonts, etc.
│   ├── images/
│   └── fonts/
└── docs/                # Documentation
```

## Development Workflow

1. Create feature branch from main
2. Make changes with descriptive commits (conventional commits preferred)
3. Run `flutter analyze` and `dart format .` locally
4. Run `flutter test` to ensure all tests pass
5. Generate code with `flutter packages pub run build_runner build` if models changed
6. Submit pull request for review

## Tool Configuration

### LSP Configuration
- Use Dart Analysis Server (included with Flutter SDK)
- Configure analysis_options.yaml for custom rules

### IDE Settings
- VS Code: Flutter extension recommended
- Android Studio/IntelliJ: Flutter plugin recommended
- Ensure line endings are consistent (LF preferred)

## Testing Guidelines

- Write unit tests for all service classes
- Use descriptive test names following `describe...when...should` pattern
- Mock external dependencies using `mockito` or similar
- Test edge cases and error conditions
- Maintain test coverage above 80%
- Use `hive_test` for database testing

## Security Guidelines

- Never commit secrets, API keys, or Supabase credentials
- Use environment variables for sensitive configuration
- Validate all user inputs in forms
- Use HTTPS for all network requests
- Follow principle of least privilege for data access

## Performance Guidelines

- Profile before optimizing using Flutter DevTools
- Consider memory usage with Hive (avoid keeping large datasets in memory)
- Use appropriate data structures (List vs Set vs Map)
- Avoid premature optimization
- Use const constructors where possible
- Implement lazy loading for large lists

## Flutter-Specific Rules

- Use `const` widgets where possible
- Prefer `StatefulWidget` only when state is truly needed
- Use `Provider` or `Riverpod` for state management (configured)
- Follow Material 3 design principles
- Use `SizedBox` instead of `Container` for spacing
- Implement proper widget lifecycle management
- Use `BuildContext` correctly (don't store long-term references)

## Database Guidelines

- All models must extend `HiveObject` and include `part` directives
- Use `@HiveType` and `@HiveField` annotations with unique typeIds
- Current typeId assignments: Task=0, TaskStatus=1, TaskPriority=2, Ritual=3, RitualFrequency=4, Board=5, BoardColumn=6, Project=7
- Generate adapters with build_runner after model changes
- All adapters must be registered in `main.dart` (including enum adapters)
- Handle box opening/closing properly
- Use transactions for multiple related operations
- Task and Project models include `modifiedAt` for sync conflict resolution

## Additional Rules

- Keep widgets small and focused (single responsibility)
- Use meaningful widget names
- Document complex business logic
- Consider platform differences (desktop vs mobile)
- Test on target platforms (macOS, Linux)
- Use appropriate responsive design patterns

---
*This file should be updated as the project evolves and new patterns are established.*