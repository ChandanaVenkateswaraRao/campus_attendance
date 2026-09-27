import 'package:isar/isar.dart';

part 'models.g.dart';

@collection
class Room {
  Id id = Isar.autoIncrement;

  late String name;
}

@collection
class Student {
  Id id = Isar.autoIncrement;

  late String name;
  late String studentId;
  String? phoneNumber;
  String? fatherPhoneNumber;
  String? motherPhoneNumber;
  String? email;

  // The room the student belongs to
  final room = IsarLink<Room>();

  // A list of 1D float arrays (face embeddings)
  // Isar doesn't directly support nested lists of floats, so we'll store a list of floats
  // If we have multiple embeddings (e.g. 5 angles of 128-dim each), we can concatenate them
  // or store a list of objects. For simplicity, we'll store multiple FaceEmbedding objects.
  @Backlink(to: 'student')
  final faceEmbeddings = IsarLinks<FaceEmbedding>();
}

@collection
class FaceEmbedding {
  Id id = Isar.autoIncrement;

  // The 128 or 192 dimensional float array from MobileFaceNet
  List<double> vector = [];

  final student = IsarLink<Student>();
}

@collection
class AttendanceRecord {
  Id id = Isar.autoIncrement;

  final room = IsarLink<Room>();

  // Use dateTime for querying
  late DateTime timestamp;

  // Has this been synced to the server?
  bool isSynced = false;

  // Which students were present?
  final presentStudents = IsarLinks<Student>();
}
