import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/models.dart';
import 'ui/registration_screen.dart';
import 'ui/attendance_screen.dart';
import 'ui/sync_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [RoomSchema, StudentSchema, FaceEmbeddingSchema, AttendanceRecordSchema],
    directory: dir.path,
  );

  runApp(MyApp(isar: isar));
}

class MyApp extends StatelessWidget {
  final Isar isar;
  
  const MyApp({super.key, required this.isar});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hostel Face Attendance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: HomeScreen(isar: isar),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final Isar isar;
  
  const HomeScreen({super.key, required this.isar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hostel Attendance', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.face_retouching_natural, size: 100, color: Colors.teal),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('1. Register Student Face'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.teal.shade100,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegistrationScreen(isar: isar)),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('2. Take Room Attendance'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.teal.shade200,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    final _roomController = TextEditingController();
                    return AlertDialog(
                      title: const Text('Enter Room Number'),
                      content: TextField(
                        controller: _roomController,
                        decoration: const InputDecoration(hintText: 'e.g. 101'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (_roomController.text.isNotEmpty) {
                              Navigator.pop(context); // close dialog
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AttendanceScreen(
                                    isar: isar, 
                                    roomName: _roomController.text.trim()
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Start Camera'),
                        ),
                      ],
                    );
                  }
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('3. Sync Offline Data'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.teal.shade300,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SyncScreen(isar: isar)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
