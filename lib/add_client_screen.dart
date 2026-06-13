import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_colors.dart'; // Import AppColors

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _professionController = TextEditingController();

  String _selectedStatus = 'Cold';
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

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
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("Sesi pengguna telah berakhir, silakan login kembali.");

      // Default fallback jika data di Firestore tidak ditemukan
      String brokerName = currentUser.email?.split('@').first ?? 'Broker';
      
      // Langsung mengambil dokumen berdasarkan Document ID yang sama dengan UID user
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid) // <--- Mencari berdasarkan Document ID
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        brokerName = userData['name'] ?? userData['fullName'] ?? brokerName;
      }

      // Menyusun data klien siap simpan
      final clientData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'profession': _professionController.text.trim(),
        'prospectStatus': _selectedStatus,
        'brokerName': brokerName,
        'brokerUid': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(), 
      };

      // Menyimpan data ke koleksi 'clients'
      await FirebaseFirestore.instance.collection('clients').add(clientData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.tertiary, size: 18), 
              SizedBox(width: 8), 
              Text('Data klien berhasil disimpan!', style: TextStyle(color: Colors.white))
            ]
          ),
          backgroundColor: AppColors.primary, 
          behavior: SnackBarBehavior.floating, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
          margin: const EdgeInsets.all(16),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menyimpan: $e', style: const TextStyle(color: Colors.white)), 
          backgroundColor: const Color(0xFF8B1A1A)
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text('Tambah Klien Baru', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveClient,
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
                            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.save_outlined, color: Colors.white, size: 20), SizedBox(width: 10), Text('SIMPAN DATA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2))]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
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