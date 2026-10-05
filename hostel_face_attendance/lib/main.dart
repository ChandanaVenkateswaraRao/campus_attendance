import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'models/models.dart';
import 'ui/home_screen.dart';
import 'ui/auth_screen.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';

late Isar globalIsar;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo.shade800),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: AuthService().isLoggedIn().then((loggedIn) async {
          if (loggedIn) {
            try {
              await SyncService(globalIsar).restoreFromCloud();
            } catch (e) {
              // Ignore failure on splash, let user retry later if needed
            }
          } else {
            await Future.delayed(const Duration(seconds: 2));
          }
          return loggedIn;
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Kalasalingam University',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hostel Attendance System',
                      style: TextStyle(fontSize: 18, color: Colors.indigo),
                    ),
                    const SizedBox(height: 32),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Syncing data from server...',
                      style: TextStyle(color: Colors.indigo.shade300, fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
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
