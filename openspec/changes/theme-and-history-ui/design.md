# Design

## Context

See `proposal.md` for the motivation to revamp the UI. Currently, the app uses `Colors.teal` as a generic seed color, and `home_screen.dart` renders highly colorful cards with bright shadows. `attendance_history_screen.dart` renders uncollapsible full lists of students per room, making scrolling tedious. 

## Goals / Non-Goals

**Goals:**
- Replace multicolored dashboard cards with a clean, flat design using a single primary branding color (e.g., Indigo).
- Change the `AttendanceHistoryScreen` to use `ExpansionTile` widgets instead of standard containers, allowing lists to collapse.
- Optimize the UI specifically for wardens who need quick high-level counts with optional drill-down details.

**Non-Goals:**
- Changing the backend schema or the synchronization logic. The data structure (JSON parsing, `fetchAttendanceHistory`) remains exactly as it is.

## Decisions

### 1. Theme Configuration
We will configure `ThemeData` in `main.dart` with a professional primary color (`Colors.indigo.shade800`). We will use `Material3` and remove hard-coded individual bright colors in `_buildModernCard` in `home_screen.dart`. All cards will now use a crisp white background with a subtle gray border (`Border.all(color: Colors.grey.shade300)`) and the primary color for icons.

### 2. History Screen Component: `ExpansionTile`
Instead of standard `Card` and `Column` widgets for `_HistoryData` records, we will use Flutter's built-in `ExpansionTile`.
- **Title**: Room name and Time
- **Subtitle**: Summary counts ("Present: X, Absent: Y")
- **Children**: The detailed list of `_buildStudentRow` calls.
This natively solves the collapse/expand requirement with zero state-management overhead.

## Risks / Trade-offs

- **Risk**: The "Edit" button logic in `attendance_history_screen.dart` could be harder to tap if buried inside a collapsed tile.
  - **Mitigation**: Place the "Edit" button in the `trailing` widget of the `ExpansionTile`, keeping it always visible even when collapsed.
