import 'dart:io';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../models/models.dart';
import '../services/sync_service.dart';

class ExcelImportScreen extends StatefulWidget {
  final Isar isar;
  const ExcelImportScreen({super.key, required this.isar});

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  final _textController = TextEditingController();
  bool _isProcessing = false;

  Future<void> _pickAndProcessFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (files.isNotEmpty && files.single.path != null) {
        setState(() => _isProcessing = true);

        final file = File(files.single.path!);
        final input = await file.readAsString();
        final rows = Csv().decode(input);

        int imported = 0;

        for (var cols in rows) {
          if (cols.length < 8) continue;

          final slNo = cols[0].toString().trim().toLowerCase();
          if (slNo.contains('sl.no') || slNo.contains('sl no'))
            continue; // Skip header

          final roomNoStr = cols[1].toString().trim();
          final regNoStr = cols[2].toString().trim();
          final nameStr = cols[3].toString().trim();
          final mobileStr = cols[4].toString().trim();
          final emailStr = cols[5].toString().trim();
          final fatherStr = cols[6].toString().trim();
          final motherStr = cols[7].toString().trim();

          if (roomNoStr.isEmpty || regNoStr.isEmpty || nameStr.isEmpty)
            continue;

          await _saveToIsar(
            roomNoStr,
            regNoStr,
            nameStr,
            mobileStr,
            emailStr,
            fatherStr,
            motherStr,
          );
          imported++;
        }

        await _syncAndFinish(imported);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading CSV file: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processTextData() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final lines = text.split('\n');
      int imported = 0;

      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        final cols = line.split('\t');

        List<String> finalCols = cols;
        if (cols.length < 8 && line.contains(',')) {
          finalCols = line.split(',');
        }

        if (finalCols.length < 8) continue;

        final slNo = finalCols[0].trim().toLowerCase();
        if (slNo.contains('sl.no') || slNo.contains('sl no'))
          continue; // Skip header

        final roomNoStr = finalCols[1].trim();
        final regNoStr = finalCols[2].trim();
        final nameStr = finalCols[3].trim();
        final mobileStr = finalCols[4].trim();
        final emailStr = finalCols[5].trim();
        final fatherStr = finalCols[6].trim();
        final motherStr = finalCols[7].trim();

        if (roomNoStr.isEmpty || regNoStr.isEmpty || nameStr.isEmpty) continue;

        await _saveToIsar(
          roomNoStr,
          regNoStr,
          nameStr,
          mobileStr,
          emailStr,
          fatherStr,
          motherStr,
        );
        imported++;
      }

      await _syncAndFinish(imported);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error parsing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _saveToIsar(
    String roomNoStr,
    String regNoStr,
    String nameStr,
    String mobileStr,
    String emailStr,
    String fatherStr,
    String motherStr,
  ) async {
    await widget.isar.writeTxn(() async {
      var room = await widget.isar.rooms
          .filter()
          .nameEqualTo(roomNoStr)
          .findFirst();
      if (room == null) {
        room = Room()..name = roomNoStr;
        await widget.isar.rooms.put(room);
      }

      var student = await widget.isar.students
          .filter()
          .studentIdEqualTo(regNoStr)
          .findFirst();
      if (student == null) {
        student = Student()
          ..studentId = regNoStr
          ..name = nameStr
          ..phoneNumber = mobileStr
          ..email = emailStr
          ..fatherPhoneNumber = fatherStr
          ..motherPhoneNumber = motherStr;

        await widget.isar.students.put(student);
        student.room.value = room;
        await student.room.save();
      } else {
        student.name = nameStr;
        student.phoneNumber = mobileStr;
        student.email = emailStr;
        student.fatherPhoneNumber = fatherStr;
        student.motherPhoneNumber = motherStr;

        await widget.isar.students.put(student);
        student.room.value = room;
        await student.room.save();
      }
    });
  }

  Future<void> _syncAndFinish(int imported) async {
    try {
      await SyncService(widget.isar).backupToCloud();
    } catch (e) {
      debugPrint('Backup to cloud failed: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported $imported students.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Import Data')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Upload a CSV file or paste your Excel data below. Please ensure it follows this exact column order:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '1. Sl.No.\n'
                '2. Room No\n'
                '3. Reg No\n'
                '4. Name\n'
                '5. Student Mobile No\n'
                '6. Student Email\n'
                '7. Father Mobile.no\n'
                '8. Mother Mobile.no',
                style: TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickAndProcessFile,
              icon: const Icon(Icons.file_upload),
              label: const Text('Upload CSV File'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("OR PASTE DATA"),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Paste data here (copy directly from Excel)...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _processTextData,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.paste),
              label: Text(
                _isProcessing ? 'Processing...' : 'Import Pasted Data',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
