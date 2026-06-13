import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_model.dart';
import 'app_colors.dart'; // Mengambil AppColors

class ClientDetailScreen extends StatefulWidget {
  final ClientModel client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _professionController;

  late String _selectedStatus;
  bool _isLoading = false;
  bool _isDeleting = false;

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': 'Cold', 'color': AppColors.primary},
    {'value': 'Warm', 'color': AppColors.secondary},
    {'value': 'Hot', 'color': const Color(0xFFEF4444)},
    {'value': 'Join', 'color': AppColors.tertiary},
    {'value': 'Closed', 'color': AppColors.neutral},
  ];

  @override
  void initState() {
    super.initState();
    // Mengisi controller dengan data klien yang dipilih
    _nameController = TextEditingController(text: widget.client.name);
    _phoneController = TextEditingController(text: widget.client.phone);
    _addressController = TextEditingController(text: widget.client.address);
    _professionController = TextEditingController(text: widget.client.profession);
    _selectedStatus = widget.client.prospectStatus;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  // --- FUNGSI UPDATE DATA ---
  Future<void> _updateClient() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Melakukan update pada dokumen berdasarkan ID
      await FirebaseFirestore.instance.collection('clients').doc(widget.client.id).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'profession': _professionController.text.trim(),
        'prospectStatus': _selectedStatus,
        'updatedAt': FieldValue.serverTimestamp(), // Melacak kapan terakhir diedit
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [Icon(Icons.check_circle, color: AppColors.tertiary, size: 18), SizedBox(width: 8), Text('Data klien berhasil diperbarui!', style: TextStyle(color: Colors.white))]),
          backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16),
        ));
        Navigator.pop(context); // Kembali ke halaman sebelumnya
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memperbarui: $e', style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF8B1A1A)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNGSI HAPUS DATA ---
  Future<void> _deleteClient() async {
    // Tampilkan dialog konfirmasi terlebih dahulu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Data?', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
        content: Text('Apakah Anda yakin ingin menghapus data ${widget.client.name}? Tindakan ini tidak dapat dibatalkan.', style: const TextStyle(color: AppColors.neutral)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.neutral, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        await FirebaseFirestore.instance.collection('clients').doc(widget.client.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Data klien berhasil dihapus', style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.neutral, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
          Navigator.pop(context); // Kembali ke list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e', style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF8B1A1A)));
        }
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
        title: const Text('Detail & Edit Klien', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          // Tombol Hapus di pojok kanan atas
          IconButton(
            icon: _isDeleting 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _isDeleting ? null : _deleteClient,
            tooltip: 'Hapus Klien',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge Info Broker
              if (widget.client.brokerName.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_ind_outlined, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Ditambahkan oleh: ${widget.client.brokerName}', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              const _SectionHeader(label: 'Informasi Utama'),
              const SizedBox(height: 14),
              _buildField(controller: _nameController, label: 'Nama Lengkap', hint: 'Masukkan nama lengkap', icon: Icons.person_outline, validator: (v) => v!.isEmpty ? 'Nama tidak boleh kosong' : null),
              const SizedBox(height: 14),
              _buildField(controller: _phoneController, label: 'Nomor WhatsApp / HP', hint: '08xx xxxx xxxx', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Nomor HP tidak boleh kosong' : null),
              const SizedBox(height: 14),
              _buildField(controller: _professionController, label: 'Profesi / Pekerjaan', hint: 'Contoh: Pengusaha, Karyawan Swasta', icon: Icons.work_outline),
              const SizedBox(height: 28),
              
              const _SectionHeader(label: 'Alamat Klien'),
              const SizedBox(height: 14),
              _buildField(controller: _addressController, label: 'Alamat Lengkap', hint: 'Jl. ... No. ..., Kota', icon: Icons.location_on_outlined, maxLines: 3),
              const SizedBox(height: 28),
              
              const _SectionHeader(label: 'Status Prospek'),
              const SizedBox(height: 14),
              _buildStatusSelector(),
              const SizedBox(height: 36),
              
              // Tombol Simpan Perubahan
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateClient,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: EdgeInsets.zero),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _isLoading ? null : const LinearGradient(colors: [AppColors.primary, Color(0xFF001F50)]),
                      color: _isLoading ? AppColors.neutral.withOpacity(0.2) : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.save_outlined, color: Colors.white, size: 20), SizedBox(width: 10), Text('SIMPAN PERUBAHAN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2))]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required String hint, required IconData icon, String? Function(String?)? validator, TextInputType? keyboardType, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.neutral.withOpacity(0.3), width: 1.5)),
          child: TextFormField(
            controller: controller, keyboardType: keyboardType, maxLines: maxLines, validator: validator,
            style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint, hintStyle: TextStyle(color: AppColors.neutral.withOpacity(0.6), fontSize: 14),
              prefixIcon: Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, color: AppColors.neutral, size: 20)),
              prefixIconConstraints: const BoxConstraints(minWidth: 44),
              border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: maxLines > 1 ? 14 : 0, horizontal: maxLines > 1 ? 16 : 0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSelector() {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: _statusOptions.map((opt) {
        final isSelected = _selectedStatus == opt['value'];
        final color = opt['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() => _selectedStatus = opt['value']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? color.withOpacity(0.15) : AppColors.surface,
              border: Border.all(color: isSelected ? color : AppColors.neutral.withOpacity(0.3), width: isSelected ? 2 : 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.check_circle, color: color, size: 14)),
                Text(opt['value'], style: TextStyle(color: isSelected ? color : AppColors.neutral, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: const LinearGradient(colors: [AppColors.secondary, Color(0xFFB8860B)]))),
        const SizedBox(width: 10),
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1.5)),
      ],
    );
  }
}