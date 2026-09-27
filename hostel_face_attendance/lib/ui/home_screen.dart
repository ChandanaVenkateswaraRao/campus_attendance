import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import 'room_list_screen.dart';
import 'sync_screen.dart';
import 'attendance_history_screen.dart';
import 'auth_screen.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  final Isar isar;
  const HomeScreen({super.key, required this.isar});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  String _hostelName = 'Loading...';
  String _floorNumber = '';
  String _name = '';
  String _blockName = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final hostel = await _authService.getHostelName() ?? 'Unknown Hostel';
    final floor = await _authService.getFloorNumber() ?? 'Unknown Floor';
    final name = await _authService.getName() ?? 'Unknown Name';
    final block = await _authService.getBlockName() ?? 'Unknown Block';
    final email = await _authService.getEmail() ?? '';
    
    if (mounted) {
      setState(() {
        _hostelName = hostel;
        _floorNumber = floor;
        _name = name;
        _blockName = block;
        _email = email;
      });
    }
  }

  void _showProfile() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Warden Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $_name', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Email: $_email'),
            const SizedBox(height: 8),
            Text('Hostel: $_hostelName'),
            const SizedBox(height: 8),
            Text('Block: $_blockName'),
            const SizedBox(height: 8),
            Text('Floor: $_floorNumber'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(2.0),
            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
          ),
        ),
        title: const Text('Hostel Attendance', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'profile') {
                _showProfile();
              } else if (value == 'backup') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backing up...')));
                try {
                  await SyncService(widget.isar).backupToCloud();
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup successful!')));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
                }
              } else if (value == 'restore') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Restore Data'),
                    content: const Text('This will drop all local rooms and students, replacing them with cloud data. Proceed?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restoring...')));
                          try {
                            await SyncService(widget.isar).restoreFromCloud();
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore successful!')));
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
                          }
                        },
                        child: const Text('Restore', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              } else if (value == 'logout') {
                await _authService.logout();
                if (context.mounted) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (ctx) => const AuthScreen()));
                }
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'profile', child: Text('Profile')),
              const PopupMenuItem(value: 'backup', child: Text('Backup to Cloud')),
              const PopupMenuItem(value: 'restore', child: Text('Restore from Cloud')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$_hostelName - Floor $_floorNumber',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.2),
              ),
              const SizedBox(height: 40),
              
              _buildModernCard(
                context,
                title: 'Registration',
                subtitle: 'Manage rooms & register students',
                icon: Icons.person_add_rounded,
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoomListScreen(isar: widget.isar, isAttendanceMode: false),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              
              _buildModernCard(
                context,
                title: 'Take Attendance',
                subtitle: 'Scan rooms for daily attendance',
                icon: Icons.camera_alt_rounded,
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoomListScreen(isar: widget.isar, isAttendanceMode: true),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              _buildModernCard(
                context,
                title: 'Attendance History',
                subtitle: 'View saved records in database',
                icon: Icons.history_rounded,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AttendanceHistoryScreen(isar: widget.isar)),
                  );
                },
              ),
              const SizedBox(height: 20),

              _buildModernCard(
                context,
                title: 'Sync Offline Data',
                subtitle: 'Upload pending records to server',
                icon: Icons.cloud_upload_rounded,
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SyncScreen(isar: widget.isar)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 28, color: primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
