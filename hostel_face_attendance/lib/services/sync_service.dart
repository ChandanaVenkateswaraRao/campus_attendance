import 'package:isar/isar.dart';
import '../models/models.dart';

class SyncService {
  final Isar isar;

  SyncService(this.isar);

  Future<void> syncPendingRecords() async {
    final pendingRecords = await isar.attendanceRecords
        .filter()
        .isSyncedEqualTo(false)
        .findAll();

    if (pendingRecords.isEmpty) {
      return;
    }

    try {
      // Mock API Call
      // await http.post('https://api.hostel.com/sync', body: pendingRecords.toJson());
      
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      // Mark as synced locally
      await isar.writeTxn(() async {
        for (var record in pendingRecords) {
          record.isSynced = true;
          await isar.attendanceRecords.put(record);
        }
      });
      
    } catch (e) {
      // Handle network error (e.g., offline)
      rethrow;
    }
  }
}
