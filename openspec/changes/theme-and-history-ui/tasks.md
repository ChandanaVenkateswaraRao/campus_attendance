# Tasks

## 1. Global Theme Updates

- [x] 1.1 In `lib/main.dart`, change `seedColor: Colors.teal` to `Colors.indigo.shade800` to establish the new professional brand color. Verify by running the app and seeing the primary color change.
- [x] 1.2 In `lib/ui/home_screen.dart`, update `_buildModernCard` to remove the multiple distinct colors (Blue, Green, Purple, Orange) and heavy glowing drop shadows. Replace them with a flat design featuring a subtle border `Border.all(color: Colors.grey.shade300)` and a white background. Use the primary color for the icons. Verify by navigating to the home screen and seeing the new flat, monochrome card design.

## 2. History UI Updates

- [x] 2.1 In `lib/ui/attendance_history_screen.dart`, modify the `ListView.builder` inside `build()` to return a `Card` containing an `ExpansionTile` for each room, instead of a simple column. Set the tile's title to the room name and time, and the subtitle to the present/absent counts. Verify by running the app and navigating to attendance history to see collapsed room cards.
- [x] 2.2 In `lib/ui/attendance_history_screen.dart`, configure the `children` property of the `ExpansionTile` to display the detailed lists of present and absent students using `_buildStudentRow`. Verify by tapping a room card to expand it and viewing the full student list.
- [x] 2.3 In `lib/ui/attendance_history_screen.dart`, move the `IconButton(icon: Icon(Icons.edit))` to the `trailing` property of the `ExpansionTile` (or integrate it into the title row if trailing overrides the expand chevron). Verify by seeing the edit button visible even when the tile is collapsed, and confirming the edit modal still opens.
