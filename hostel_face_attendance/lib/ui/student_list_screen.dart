import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../models/models.dart';
import 'registration_screen.dart';

class StudentListScreen extends StatefulWidget {
  final Isar isar;
  final Room room;

  const StudentListScreen({super.key, required this.isar, required this.room});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  List<Student> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final students = await widget.isar.students
        .filter()
        .room((q) => q.idEqualTo(widget.room.id))
        .findAll();
    setState(() {
      _students = students;
    });
  }

  void _addStudent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegistrationScreen(isar: widget.isar, room: widget.room),
      ),
    ).then((_) {
      _loadStudents(); // Refresh when returning
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Room ${widget.room.name} Students'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _students.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No students registered in this room', 
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.withOpacity(0.1),
                      child: const Icon(Icons.person, color: Colors.teal),
                    ),
                    title: Text(
                      student.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text('ID: ${student.studentId}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(student),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStudent,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Future<void> _confirmDelete(Student student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to remove ${student.name} from this room? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteStudent(student);
    }
  }

  Future<void> _deleteStudent(Student student) async {
    await widget.isar.writeTxn(() async {
      // Load and delete all associated face embeddings
      await student.faceEmbeddings.load();
      final embeddingIds = student.faceEmbeddings.map((e) => e.id).toList();
      await widget.isar.faceEmbeddings.deleteAll(embeddingIds);

      // Delete the student
      await widget.isar.students.delete(student.id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${student.name} deleted successfully')),
      );
      _loadStudents(); // Refresh the list
    }
  }
}
