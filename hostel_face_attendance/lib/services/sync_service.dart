import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import '../models/models.dart';
import 'auth_service.dart';

class SyncService {
  final Isar isar;
  // Replace with your local machine's IP address if testing on a physical device,
  // or use 10.0.2.2 if testing on Android Emulator
  final String backendUrl = 'http://10.131.73.51:3000/api/sync';

  SyncService(this.isar);

  Future<List<dynamic>> fetchAttendanceHistory(DateTime date) async {
    final token = await AuthService().getToken();
    if (token == null) throw Exception('Not logged in');

    // Format date as YYYY-MM-DD
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    final response = await http.get(
      Uri.parse('http://10.131.73.51:3000/api/attendance?date=$dateString'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      print('Fetched ${data.length} records from server.');
      return data;
    } else {
      throw Exception('Failed to fetch history: ${response.statusCode}');
    }
  }

  Future<int> getPendingRecordsCount() async {
    return await isar.attendanceRecords
        .filter()
        .isSyncedEqualTo(false)
        .count();
  }

  Future<void> syncPendingRecords() async {
    final pendingRecords = await isar.attendanceRecords
        .filter()
        .isSyncedEqualTo(false)
        .findAll();

    if (pendingRecords.isEmpty) {
      return;
    }

    try {
      final payload = pendingRecords.map((r) {
        final roomName = r.room.value?.name ?? 'Unknown';
        // Need to load the links if not loaded
        r.presentStudents.loadSync();
        final students = r.presentStudents.map((s) => {
          'id': s.id,
          'name': s.name,
          'studentId': s.studentId,
        }).toList();

        return {
          'id': r.id,
          'roomName': roomName,
          'timestamp': r.timestamp.toIso8601String(),
          'presentStudents': students,
        };
      }).toList();

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'records': payload}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Mark as synced locally
        await isar.writeTxn(() async {
          for (var record in pendingRecords) {
            record.isSynced = true;
            await isar.attendanceRecords.put(record);
          }
        });
      } else {
        throw Exception('Failed to sync. Server returned ${response.statusCode}');
      }
    } catch (e) {
      // Handle network error (e.g., offline)
      print('Sync Error: $e');
      rethrow;
    }
  }

  Future<void> backupToCloud() async {
    final token = await AuthService().getToken();
    if (token == null) throw Exception('Not logged in');

    final rooms = await isar.rooms.where().findAll();
    final students = await isar.students.where().findAll();
    final faceEmbeddings = await isar.faceEmbeddings.where().findAll();

    final payload = {
      'rooms': rooms.map((r) => {'id': r.id, 'name': r.name}).toList(),
      'students': students.map((s) {
        s.room.loadSync();
        return {
          'id': s.id,
          'name': s.name,
          'studentId': s.studentId,
          'room_local_id': s.room.value?.id,
          'phoneNumber': s.phoneNumber,
          'fatherPhoneNumber': s.fatherPhoneNumber,
          'motherPhoneNumber': s.motherPhoneNumber,
          'email': s.email
        };
      }).toList(),
      'faceEmbeddings': faceEmbeddings.map((f) {
        f.student.loadSync();
        return {
          'id': f.id,
          'vector': f.vector,
          'student_local_id': f.student.value?.id
        };
      }).toList(),
    };

    final response = await http.post(
      Uri.parse('http://10.131.73.51:3000/api/backup'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Backup failed: ${response.statusCode}');
    }
  }

  Future<void> restoreFromCloud() async {
    final token = await AuthService().getToken();
    if (token == null) throw Exception('Not logged in');

    final response = await http.get(
      Uri.parse('http://10.131.73.51:3000/api/restore'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      await isar.writeTxn(() async {
        await isar.rooms.clear();
        await isar.students.clear();
        await isar.faceEmbeddings.clear();
        
        final rooms = (data['rooms'] as List).map((r) {
          final roomId = r['local_id'] ?? r['id'];
          final room = Room()..name = r['name'];
          if (roomId != null) room.id = roomId;
          return room;
        }).toList();
        await isar.rooms.putAll(rooms);

        final students = (data['students'] as List).map((s) {
          final studentId = s['local_id'] ?? s['id'];
          final student = Student()
            ..name = s['name']
            ..studentId = s['studentId']
            ..phoneNumber = s['phoneNumber']
            ..fatherPhoneNumber = s['fatherPhoneNumber']
            ..motherPhoneNumber = s['motherPhoneNumber']
            ..email = s['email'];
          if (studentId != null) student.id = studentId;
          return MapEntry(s, student);
        }).toList();
        
        await isar.students.putAll(students.map((e) => e.value).toList());

        for (var entry in students) {
          final sData = entry.key;
          final student = entry.value;
          final roomLocalId = sData['room_local_id'] ?? sData['room_id'];
          if (roomLocalId != null) {
            final room = await isar.rooms.get(roomLocalId);
            if (room != null) {
              student.room.value = room;
              await student.room.save();
            }
          }
        }

        final embeddings = (data['faceEmbeddings'] as List).map((f) {
          final embId = f['local_id'] ?? f['id'];
          final emb = FaceEmbedding()
            ..vector = List<double>.from(f['vector']);
          if (embId != null) emb.id = embId;
          return MapEntry(f, emb);
        }).toList();

        await isar.faceEmbeddings.putAll(embeddings.map((e) => e.value).toList());

        for (var entry in embeddings) {
          final fData = entry.key;
          final emb = entry.value;
          final studentLocalId = fData['student_local_id'] ?? fData['student_id'];
          if (studentLocalId != null) {
            final student = await isar.students.get(studentLocalId);
            if (student != null) {
              emb.student.value = student;
              await emb.student.save();
            }
          }
        }
      });
    } else {
      throw Exception('Restore failed: ${response.statusCode}');
    }
  }

  Future<void> updateAttendanceRecord(int recordId, List<dynamic> presentStudents) async {
    final token = await AuthService().getToken();
    if (token == null) throw Exception('Not logged in');

    final payload = {
      'present_students': presentStudents,
    };

    final response = await http.put(
      Uri.parse('http://10.131.73.51:3000/api/attendance/$recordId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to update record: ${response.statusCode}');
    }
    print('Record updated successfully.');
  }

  Future<List<dynamic>> fetchLeaves() async {
    final token = await AuthService().getToken();
    if (token == null) return [];
    try {
      final res = await http.get(
        Uri.parse('http://10.131.73.51:3000/api/warden/leaves'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('Error fetching leaves: $e');
    }
    return [];
  }
}

