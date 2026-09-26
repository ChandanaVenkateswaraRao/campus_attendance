import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../services/sync_service.dart';
import '../models/models.dart';

class SyncScreen extends StatefulWidget {
  final Isar isar;
  const SyncScreen({super.key, required this.isar});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isSyncing = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final count = await widget.isar.attendanceRecords
        .filter()
        .isSyncedEqualTo(false)
        .count();
    setState(() {
      _pendingCount = count;
    });
  }

  Future<void> _startSync() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final syncService = SyncService(widget.isar);
      await syncService.syncPendingRecords();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync failed. Please check internet.')),
        );
      }
    } finally {
      _loadPendingCount();
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Attendance'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Pending Records: $_pendingCount', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _isSyncing || _pendingCount == 0 ? null : _startSync,
              icon: _isSyncing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload),
              label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
