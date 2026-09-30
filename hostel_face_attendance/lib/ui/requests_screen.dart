import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({Key? key}) : super(key: key);

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> leaves = [];
  List<dynamic> outings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('Not logged in');

      final leavesRes = await http.get(
        Uri.parse('http://10.131.73.51:3000/api/warden/leaves'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final outingsRes = await http.get(
        Uri.parse('http://10.131.73.51:3000/api/warden/outings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (leavesRes.statusCode == 200) {
        leaves = jsonDecode(leavesRes.body);
      }
      if (outingsRes.statusCode == 200) {
        outings = jsonDecode(outingsRes.body);
      }
    } catch (e) {
      debugPrint('Error fetching requests: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> updateStatus(String type, int id, String status) async {
    try {
      final token = await AuthService().getToken();
      final response = await http.put(
        Uri.parse('http://10.131.73.51:3000/api/warden/$type/$id/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        fetchData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request $status successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request')),
      );
    }
  }

  Widget _buildList(List<dynamic> data, String type) {
    if (data.isEmpty) {
      return const Center(child: Text('No requests found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        final isLeave = type == 'leaves';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['student_name'] ?? 'Unknown Student',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(item['status']).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['status'] ?? 'PENDING',
                        style: TextStyle(
                          color: _getStatusColor(item['status']),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Reg No: ${item['register_number'] ?? 'N/A'}'),
                Text('Room: ${item['room_number'] ?? 'N/A'}'),
                const Divider(),
                if (isLeave) ...[
                  Text('From: ${item['from_date']?.replaceAll('T', ' ')}'),
                  Text('To: ${item['to_date']?.replaceAll('T', ' ')}'),
                ] else ...[
                  Text('Date: ${item['date']}'),
                  Text('Time: ${item['start_time']} - ${item['end_time']}'),
                ],
                const SizedBox(height: 8),
                Text('Reason: ${item['reason'] ?? 'N/A'}', style: const TextStyle(fontStyle: FontStyle.italic)),
                
                if (item['status'] == 'PENDING') ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
                        onPressed: () => updateStatus(type, item['id'], 'REJECTED'),
                        child: const Text('Reject', style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade500),
                        onPressed: () => updateStatus(type, item['id'], 'APPROVED'),
                        child: const Text('Approve', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    if (status == 'APPROVED') return Colors.green;
    if (status == 'REJECTED') return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave & Outing Requests'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Leaves'),
            Tab(text: 'Outings'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(leaves, 'leaves'),
                _buildList(outings, 'outings'),
              ],
            ),
    );
  }
}
