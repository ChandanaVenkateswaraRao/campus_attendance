import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../services/sync_service.dart';
import '../models/models.dart';

class _PendingData {
  final AttendanceRecord record;
  final List<Student> present;
  final List<Student> absent;
  _PendingData(this.record, this.present, this.absent);
}

class SyncScreen extends StatefulWidget {
  final Isar isar;
  const SyncScreen({super.key, required this.isar});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isSyncing = false;
  List<_PendingData> _pendingData = [];

  @override
  void initState() {
    super.initState();
    _loadPendingRecords();
  }

  Future<void> _loadPendingRecords() async {
    final records = await widget.isar.attendanceRecords
        .filter()
        .isSyncedEqualTo(false)
        .sortByTimestampDesc()
        .findAll();

    List<_PendingData> data = [];
    for (var record in records) {
      await record.room.load();
      await record.presentStudents.load();
      
      final roomId = record.room.value?.id;
      if (roomId != null) {
        final allStudents = await widget.isar.students.filter().room((q) => q.idEqualTo(roomId)).findAll();
        final presentIds = record.presentStudents.map((s) => s.id).toSet();
        
        final present = allStudents.where((s) => presentIds.contains(s.id)).toList();
        final absent = allStudents.where((s) => !presentIds.contains(s.id)).toList();
        
        data.add(_PendingData(record, present, absent));
      }
    }

    setState(() {
      _pendingData = data;
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
      _loadPendingRecords();
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Widget _buildStudentRow(Student s, bool isPresent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: isPresent ? Colors.teal.shade50 : Colors.red.shade50,
            child: Icon(
              isPresent ? Icons.check : Icons.close, 
              size: 12, 
              color: isPresent ? Colors.teal.shade400 : Colors.red.shade400
            ),
          ),
          const SizedBox(width: 8),
          Text(
            s.name, 
            style: TextStyle(
              fontSize: 14, 
              color: isPresent ? Colors.black87 : Colors.grey.shade600,
            )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Attendance'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            color: Colors.orange.shade50,
            child: Column(
              children: [
                Text('Pending Records: ${_pendingData.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isSyncing || _pendingData.isEmpty ? null : _startSync,
                  icon: _isSyncing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload),
                  label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _pendingData.isEmpty 
              ? const Center(child: Text('No pending records.', style: TextStyle(color: Colors.grey, fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingData.length,
                  itemBuilder: (context, index) {
                    final data = _pendingData[index];
                    final roomName = data.record.room.value?.name ?? 'Unknown';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Room $roomName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(
                                  '${data.record.timestamp.hour.toString().padLeft(2, '0')}:${data.record.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text('Present (${data.present.length})', style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...data.present.map((s) => _buildStudentRow(s, true)),
                            if (data.absent.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text('Absent (${data.absent.length})', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ...data.absent.map((s) => _buildStudentRow(s, false)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
 