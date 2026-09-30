# Proposal

## Why

The current UI design uses large, bright, multicolored components with heavy drop shadows, which gives it an informal, "AI-generated" appearance. Since this is an application intended for collegiate administration, the UI must be sharper, cleaner, and more professional. Additionally, the attendance history screen renders all students per room in one massively long scrollable vertical list, making it extremely tedious to navigate for a warden overseeing hundreds of students across multiple rooms.

## What Changes

- Re-theme the app to use a professional, unified collegiate color palette (e.g., deep Indigo/Teal primary accent with neutral gray/white backgrounds).
- Standardize all app cards to a flatter, crisp design (smaller corner radii, removal of highly colored glowing box shadows, using simple 1px borders).
- Redesign the `AttendanceHistoryScreen` to display a grouped list of rooms.
- Implement an accordion/expansion tile layout in the history screen so that room cards start collapsed (showing only the room number, time, and present/absent summary) and expand on tap to show detailed student lists.
- Optimize the history detail view to be more space-efficient (e.g., chips or smaller rows).

## Capabilities

### New Capabilities
- `attendance/room-grouped-history`: The attendance history view must group records by room, displaying a high-level summary by default, and allowing the warden to drill down into student-level details on demand.

### Modified Capabilities

## Impact

- `lib/main.dart`: Global `ThemeData` changes.
- `lib/ui/home_screen.dart`: Dashboard card restyling.
- `lib/ui/attendance_history_screen.dart`: Complete structural redesign of how `_historyData` is rendered (incorporating `ExpansionTile`).
