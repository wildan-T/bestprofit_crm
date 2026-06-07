import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'client_list_screen.dart'; // Tambahkan import ini

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Marketing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          // Perbarui bagian ini untuk menambahkan fungsi onTap
          _buildMenuCard(
            context, 
            Icons.people, 
            'Data Klien', 
            Colors.blue,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ClientListScreen()),
              );
            }
          ),
          _buildMenuCard(context, Icons.calendar_month, 'Jadwal Meeting', Colors.orange, () {}),
          _buildMenuCard(context, Icons.trending_up, 'Harga Emas', Colors.amber, () {}),
          _buildMenuCard(context, Icons.pie_chart, 'Kinerja Harian', Colors.green, () {}),
          _buildMenuCard(context, Icons.history, 'Riwayat Komunikasi', Colors.purple, () {}),
          _buildMenuCard(context, Icons.folder, 'Dokumen (KYC)', Colors.red, () {}),
        ],
      ),
    );
  }

  // Tambahkan parameter onTap
  Widget _buildMenuCard(BuildContext context, IconData icon, String title, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap, // Gunakan parameter onTap di sini
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}