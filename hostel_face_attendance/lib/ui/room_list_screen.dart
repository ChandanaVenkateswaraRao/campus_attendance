import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../models/models.dart';
import 'student_list_screen.dart';
import 'attendance_screen.dart';

class RoomListScreen extends StatefulWidget {
  final Isar isar;
  final bool isAttendanceMode;

  const RoomListScreen({super.key, required this.isar, required this.isAttendanceMode});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  List<Room> _rooms = [];

  Map<int, String> _roomStats = {};

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final rooms = await widget.isar.rooms.where().findAll();
    
    Map<int, String> stats = {};
    if (widget.isAttendanceMode) {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);
      
      for (var room in rooms) {
        final record = await widget.isar.attendanceRecords
          .filter()
          .room((q) => q.idEqualTo(room.id))
          .timestampBetween(startOfDay, endOfDay)
          .findFirst();
          
        if (record != null) {
           await record.presentStudents.load();
           final presentCount = record.presentStudents.length;
           final totalStudents = await widget.isar.students.filter().room((q) => q.idEqualTo(room.id)).count();
           final absentCount = totalStudents - presentCount;
           stats[room.id] = 'Present: $presentCount | Absent: $absentCount';
        }
      }
    }

    setState(() {
      _rooms = rooms;
      _roomStats = stats;
    });
  }

  Future<void> _addRoom() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Room'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. 101',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null) {
      final existing = await widget.isar.rooms.filter().nameEqualTo(name).findFirst();
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room already exists')));
        }
        return;
      }

      final newRoom = Room()..name = name;
      await widget.isar.writeTxn(() async {
        await widget.isar.rooms.put(newRoom);
      });
      _loadRooms();
    }
  }

  void _onRoomTapped(Room room) {
    if (widget.isAttendanceMode) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AttendanceScreen(isar: widget.isar, room: room),
        ),
      ).then((_) => _loadRooms());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentListScreen(isar: widget.isar, room: room),
        ),
      ).then((_) => _loadRooms());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(widget.isAttendanceMode ? 'Select Room to Scan' : 'Manage Rooms'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _rooms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No rooms found', style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rooms.length,
              itemBuilder: (context, index) {
                final room = _rooms[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueAccent.withOpacity(0.1),
                      child: const Icon(Icons.meeting_room, color: Colors.blueAccent),
                    ),
                    title: Text(
                      'Room ${room.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: widget.isAttendanceMode && _roomStats.containsKey(room.id)
                        ? Text(_roomStats[room.id]!, style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold))
                        : null,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _onRoomTapped(room),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRoom,
        icon: const Icon(Icons.add),
        label: const Text('Add Room'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
