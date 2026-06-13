import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_detail_screen.dart';
import 'client_model.dart';
import 'add_client_screen.dart';
import 'app_colors.dart'; // Import AppColors

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  String _searchQuery = '';
  String _filterStatus = 'Semua';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
  backgroundColor: AppColors.primary,
  elevation: 0,
  automaticallyImplyLeading: false, // Mencegah tombol back otomatis muncul
  title: const Text('Data Klien', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.neutral.withOpacity(0.2))),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppColors.primary, fontSize: 14),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau nomor HP...',
                      hintStyle: TextStyle(color: AppColors.neutral.withOpacity(0.8), fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: AppColors.neutral, size: 20),
                      border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Semua', 'Hot', 'Warm', 'Cold', 'Join', 'Closed'].map((status) => _FilterChip(
                      label: status, isSelected: _filterStatus == status, color: _getStatusColor(status),
                      onTap: () => setState(() => _filterStatus = status),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('clients').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return _buildEmptyState(Icons.error_outline, 'Terjadi kesalahan', 'Periksa koneksi Anda');
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));

                final allDocs = snapshot.requireData.docs;
                final clients = allDocs.map((d) => ClientModel.fromMap(d.data() as Map<String, dynamic>, d.id)).where((c) {
                  final matchSearch = _searchQuery.isEmpty || c.name.toLowerCase().contains(_searchQuery) || c.phone.contains(_searchQuery);
                  final matchFilter = _filterStatus == 'Semua' || c.prospectStatus == _filterStatus;
                  return matchSearch && matchFilter;
                }).toList();

                if (clients.isEmpty) return _buildEmptyState(Icons.person_search, 'Tidak ada klien', _searchQuery.isNotEmpty ? 'Coba kata kunci lain' : 'Tambah klien baru dengan tombol +');

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    return _ClientCard(
                      client: clients[index],
                      onTap: () {
                        // Navigasi ke halaman detail dengan membawa data klien
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientDetailScreen(client: clients[index]),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [AppColors.secondary, Color(0xFFB8860B)]),
          boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddClientScreen())),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Tambah Klien', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: AppColors.neutral.withOpacity(0.5)),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.neutral, fontSize: 13)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Hot': return const Color(0xFFEF4444);
      case 'Warm': return AppColors.secondary;
      case 'Cold': return AppColors.primary;
      case 'Join': return AppColors.tertiary;
      case 'Closed': return AppColors.neutral;
      default: return AppColors.primary;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? color.withOpacity(0.1) : AppColors.backgroundLight,
          border: Border.all(color: isSelected ? color : AppColors.neutral.withOpacity(0.3), width: 1.5),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? color : AppColors.neutral)),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final ClientModel client;
  final VoidCallback onTap;

  const _ClientCard({required this.client, required this.onTap});

  Color _statusColor(String s) {
    switch (s) {
      case 'Hot': return const Color(0xFFEF4444);
      case 'Warm': return AppColors.secondary;
      case 'Cold': return AppColors.primary;
      case 'Join': return AppColors.tertiary;
      case 'Closed': return AppColors.neutral;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(client.prospectStatus);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.neutral.withOpacity(0.2))),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: color.withOpacity(0.1)),
                  child: Center(child: Text(client.name.isNotEmpty ? client.name[0].toUpperCase() : '?', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.name, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14.5)),
                      const SizedBox(height: 3),
                      Text(client.phone, style: const TextStyle(color: AppColors.neutral, fontSize: 12.5, fontWeight: FontWeight.w500)),
                      if (client.profession.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(client.profession, style: TextStyle(color: AppColors.neutral.withOpacity(0.8), fontSize: 12), overflow: TextOverflow.ellipsis),
                      ],
                      if (client.brokerName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.assignment_ind_outlined, size: 12, color: AppColors.secondary),
                            const SizedBox(width: 4),
                            Text('Broker: ${client.brokerName}', style: const TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: color.withOpacity(0.1)),
                      child: Text(client.prospectStatus, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                    const SizedBox(height: 6),
                    const Icon(Icons.chevron_right, color: AppColors.neutral, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}