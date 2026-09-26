import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_face_attendance/models/models.dart';
import 'package:isar/isar.dart';
import 'dart:io';

void main() {
  late Isar isar;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    
    // Create a temp directory for the test database
    final dir = await Directory.systemTemp.createTemp('isar_test_');
    
    isar = await Isar.open(
      [RoomSchema, StudentSchema, FaceEmbeddingSchema, AttendanceRecordSchema],
      directory: dir.path,
    );
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
  });

  test('Basic CRUD for Room and Student', () async {
    // CREATE
    final room = Room()..name = 'Room 101';
    
    await isar.writeTxn(() async {
      await isar.rooms.put(room);
    });

    expect(room.id, isNotNull);

    final student = Student()
      ..name = 'John Doe'
      ..studentId = 'STU001';
      
    student.room.value = room;

    await isar.writeTxn(() async {
      await isar.students.put(student);
      await student.room.save();
    });

    // READ
    final fetchedStudent = await isar.students.where().findFirst();
    expect(fetchedStudent?.name, 'John Doe');
    
    await fetchedStudent?.room.load();
    expect(fetchedStudent?.room.value?.name, 'Room 101');
    
    // UPDATE
    await isar.writeTxn(() async {
      fetchedStudent!.name = 'John Smith';
      await isar.students.put(fetchedStudent);
    });
    
    final updatedStudent = await isar.students.get(fetchedStudent!.id);
    expect(updatedStudent?.name, 'John Smith');
    
    // DELETE
    await isar.writeTxn(() async {
      await isar.students.delete(student.id);
    });
    
    expect(await isar.students.count(), 0);
  });
}
