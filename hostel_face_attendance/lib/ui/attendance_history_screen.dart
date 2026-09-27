import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/models.dart';
import '../services/sync_service.dart';

enum StudentFilter { all, present, absent }

class _HistoryData {
  final Map<String, dynamic> record;
  final List<Student> present;
  final List<Student> absent;
  final DateTime timestamp;
  _HistoryData(this.record, this.present, this.absent, this.timestamp);
}

class AttendanceHistoryScreen extends StatefulWidget {
  final Isar isar;
  const AttendanceHistoryScreen({super.key, required this.isar});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<_HistoryData> _historyData = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  StudentFilter _filter = StudentFilter.all;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    
    try {
      final syncService = SyncService(widget.isar);
      final records = await syncService.fetchAttendanceHistory(_selectedDate);
      
      final Map<String, Map<String, dynamic>> latestRecords = {};
      for (var r in records) {
        final roomName = r['room_name'] as String;
        if (!latestRecords.containsKey(roomName)) {
          latestRecords[roomName] = r;
        }
      }

      List<_HistoryData> data = [];
      for (var record in latestRecords.values) {
        final roomName = record['room_name'] as String;
        final room = await widget.isar.rooms.filter().nameEqualTo(roomName).findFirst();
        final roomId = room?.id;
        
        List<Student> allStudents = [];
        if (roomId != null) {
          allStudents = await widget.isar.students.filter().room((q) => q.idEqualTo(roomId)).findAll();
        }
        
        final presentStudentsList = record['present_students'] as List<dynamic>;
        final presentIds = presentStudentsList.map((s) => s['id'] as int).toSet();
        
        final present = <Student>[];
        final absent = <Student>[];
        for (var s in allStudents) {
          if (presentIds.contains(s.id)) {
            present.add(s);
          } else {
            absent.add(s);
          }
        }
        
        data.add(_HistoryData(record, present, absent, DateTime.parse(record['timestamp'])));
      }

      if (mounted) {
        setState(() {
          _historyData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyData = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load history. Ensure you have an internet connection. Error: $e')));
      }
    }
  }

  Widget _buildStudentRow(Student s, bool isPresent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isPresent ? Colors.teal.shade50 : Colors.red.shade50,
            child: Icon(
              isPresent ? Icons.check : Icons.close, 
              size: 14, 
              color: isPresent ? Colors.teal.shade400 : Colors.red.shade400
            ),
          ),
          const SizedBox(width: 12),
          Text(
            s.name, 
            style: TextStyle(
              fontSize: 15, 
              fontWeight: FontWeight.w500,
              color: isPresent ? Colors.black87 : Colors.grey.shade600,
            )
          ),
          const Spacer(),
          Text(s.studentId, style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  void _openEditModal(_HistoryData data) {
    final allStudents = [...data.present, ...data.absent];
    final selectedStudentIds = data.present.map((s) => s.id).toSet();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edit Attendance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: allStudents.length,
                        itemBuilder: (context, index) {
                          final s = allStudents[index];
                          final isPresent = selectedStudentIds.contains(s.id);
                          return CheckboxListTile(
                            title: Text(s.name),
                            subtitle: Text(s.studentId),
                            value: isPresent,
                            onChanged: (bool? val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedStudentIds.add(s.id);
                                } else {
                                  selectedStudentIds.remove(s.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isSaving)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: () async {
                          setModalState(() => isSaving = true);
                          try {
                            final presentStudentsList = allStudents
                                .where((s) => selectedStudentIds.contains(s.id))
                                .map((s) => {'id': s.id, 'name': s.name, 'studentId': s.studentId})
                                .toList();
                            
                            // Import sync_service.dart and call update
                            final syncService = SyncService(widget.isar);
                            await syncService.updateAttendanceRecord(data.record['id'] as int, presentStudentsList);
                            
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance updated successfully!')));
                              _loadRecords(); // Refresh the list
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update. Ensure you have an internet connection. Error: $e')));
                            }
                            setModalState(() => isSaving = false);
                          }
                        },
                        child: const Text('Save Changes'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Attendance History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Date selection header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Date: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _selectedDate = date);
                          _loadRecords();
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Change'),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<StudentFilter>(
                    segments: const [
                      ButtonSegment(value: StudentFilter.all, label: Text('All')),
                      ButtonSegment(value: StudentFilter.present, label: Text('Present')),
                      ButtonSegment(value: StudentFilter.absent, label: Text('Absent')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (Set<StudentFilter> newSelection) {
                      setState(() {
                        _filter = newSelection.first;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _historyData.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No attendance records for this date.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _historyData.length,
                    itemBuilder: (context, index) {
                      final data = _historyData[index];
                      final record = data.record;
                      final roomName = record['room_name'] as String? ?? 'Unknown Room';
                      final presentCount = data.present.length;
                      final absentCount = data.absent.length;
                      
                      List<Widget> studentWidgets = [];
                      if (_filter == StudentFilter.all || _filter == StudentFilter.present) {
                        for (var s in data.present) {
                          studentWidgets.add(_buildStudentRow(s, true));
                        }
                      }
                      if (_filter == StudentFilter.all || _filter == StudentFilter.absent) {
                        for (var s in data.absent) {
                          studentWidgets.add(_buildStudentRow(s, false));
                        }
                      }
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Room $roomName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(
                                  '${data.timestamp.hour.toString().padLeft(2, '0')}:${data.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 14),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                                  const SizedBox(width: 4),
                                  Text('$presentCount Present', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                  const SizedBox(width: 16),
                                  Icon(Icons.cancel, color: Colors.red.shade600, size: 16),
                                  const SizedBox(width: 4),
                                  Text('$absentCount Absent', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                                  onPressed: () => _openEditModal(data),
                                ),
                                const Icon(Icons.expand_more),
                              ],
                            ),
                            children: [
                              if (studentWidgets.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                  child: Column(
                                    children: [
                                      const Divider(height: 1),
                                      const SizedBox(height: 12),
                                      ...studentWidgets,
                                    ],
                                  ),
                                ),
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
