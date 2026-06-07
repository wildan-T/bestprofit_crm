import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_model.dart';
import 'add_client_screen.dart';

class ClientListScreen extends StatelessWidget {
  const ClientListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Klien'),
      ),
      // StreamBuilder untuk menarik data secara real-time dari Firestore
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clients').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Terjadi kesalahan data.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.requireData;

          if (data.size == 0) {
            return const Center(child: Text('Belum ada data klien.'));
          }

          return ListView.builder(
            itemCount: data.size,
            itemBuilder: (context, index) {
              // Mengubah data Firestore menjadi Object ClientModel
              var clientData = data.docs[index].data() as Map<String, dynamic>;
              var client = ClientModel.fromMap(clientData, data.docs[index].id);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(client.prospectStatus),
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${client.phone} • ${client.prospectStatus}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Nantinya diarahkan ke halaman detail klien
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddClientScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // Fungsi untuk memberi warna indikator status prospek
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Hot': return Colors.red;
      case 'Warm': return Colors.orange;
      case 'Join': return Colors.green;
      case 'Closed': return Colors.grey;
      default: return Colors.blue; // Cold
    }
  }
}