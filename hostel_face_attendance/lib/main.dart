import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/models.dart';
import 'ui/home_screen.dart';
import 'ui/auth_screen.dart';
import 'services/auth_service.dart';

late Isar globalIsar;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final dir = await getApplicationDocumentsDirectory();
  globalIsar = await Isar.open(
    [RoomSchema, StudentSchema, FaceEmbeddingSchema, AttendanceRecordSchema],
    directory: dir.path,
  );

  runApp(MyApp(isar: globalIsar));
}

class MyApp extends StatelessWidget {
  final Isar isar;
  
  const MyApp({super.key, required this.isar});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hostel Face Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: AuthService().isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.data == true) {
            return HomeScreen(isar: globalIsar);
          }
          return const AuthScreen();
        },
      ),
    );
  }
}
