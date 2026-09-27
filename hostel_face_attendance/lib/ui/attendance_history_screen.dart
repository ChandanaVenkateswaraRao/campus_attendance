import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/models.dart';
import '../services/sync_service.dart';

enum StudentFilter { all, present, absent }

class _HistoryData {
  final AttendanceRecord record;
  final List<Student> present;
  final List<Student> absent;
  _HistoryData(this.record, this.present, this.absent);
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
    
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59, 999);
    
    final records = await widget.isar.attendanceRecords
        .filter()
        .timestampBetween(startOfDay, endOfDay)
        .sortByTimestampDesc()
        .findAll();
    
    // Only keep the latest record for each room (since it's sorted descending)
    final Map<int, AttendanceRecord> latestRecords = {};
    for (var r in records) {
      await r.room.load();
      final roomId = r.room.value?.id;
      if (roomId != null && !latestRecords.containsKey(roomId)) {
        await r.presentStudents.load();
        latestRecords[roomId] = r;
      }
    }

    List<_HistoryData> data = [];
    for (var record in latestRecords.values) {
      final roomId = record.room.value!.id;
      final allStudents = await widget.isar.students.filter().room((q) => q.idEqualTo(roomId)).findAll();
      final presentIds = record.presentStudents.map((s) => s.id).toSet();
      
      final present = <Student>[];
      final absent = <Student>[];
      for (var s in allStudents) {
        if (presentIds.contains(s.id)) {
          present.add(s);
        } else {
          absent.add(s);
        }
      }
      data.add(_HistoryData(record, present, absent));
    }

    setState(() {
      _historyData = data;
      _isLoading = false;
    });
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
                            await syncService.updateAttendanceRecord(data.record.id, presentStudentsList);
                            
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
                      final roomName = record.room.value?.name ?? 'Unknown Room';
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
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Room $roomName', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  Row(
                                    children: [
                                      Text(
                                        '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _openEditModal(data),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      Text('$presentCount Present', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.cancel, color: Colors.red, size: 20),
                                      const SizedBox(width: 8),
                                      Text('$absentCount Absent', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                ],
                              ),
                              if (studentWidgets.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                ...studentWidgets,
                              ]
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
