import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'image_helper.dart';
import 'app_colors.dart';

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
  String _buktiTransferBase64 = '';
  bool _isLoading = false;
  bool _isUploadingProof = false;
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

  // ── HANDLE PERUBAHAN STATUS ───────────────────────────────────────────────
  Future<void> _onStatusChanged(String newStatus) async {
    final wasJoin = _selectedStatus == 'Join';
    final isNowJoin = newStatus == 'Join';

    setState(() => _selectedStatus = newStatus);

    if (isNowJoin && !wasJoin && _buktiTransferBase64.isEmpty) {
      await _pickBuktiTransfer(isRequired: true);
    }
  }

  Future<void> _pickBuktiTransfer({bool isRequired = false}) async {
    setState(() => _isUploadingProof = true);
    try {
      final base64Image = await ImageHelper.pickAndEncode(context);

      if (base64Image == null) {
        if (isRequired && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bukti transfer wajib diunggah untuk status "Join"', style: TextStyle(color: Colors.white)),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }

      setState(() => _buktiTransferBase64 = base64Image);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: const [
            Icon(Icons.check_circle, color: AppColors.tertiary, size: 18),
            SizedBox(width: 8),
            Text('Bukti transfer berhasil dipilih', style: TextStyle(color: Colors.white)),
          ]),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal memproses gambar: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF8B1A1A),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploadingProof = false);
    }
  }

  void _viewFullImage() {
    final bytes = ImageHelper.decodeToBytes(_buktiTransferBase64);
    if (bytes == null) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
            Positioned(
              top: 8, right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStatus == 'Join' && _buktiTransferBase64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Status "Join" wajib menyertakan bukti transfer', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("Sesi pengguna telah berakhir, silakan login kembali.");

      String brokerName = currentUser.email?.split('@').first ?? 'Broker';

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        brokerName = userData['name'] ?? userData['fullName'] ?? brokerName;
      }

      final clientData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'profession': _professionController.text.trim(),
        'prospectStatus': _selectedStatus,
        'brokerName': brokerName,
        'brokerUid': currentUser.uid,
        'buktiTransferBase64': _buktiTransferBase64,
        'createdAt': FieldValue.serverTimestamp(),
      };

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
                const SizedBox(height: 24),

                // ── BUKTI TRANSFER (muncul hanya jika status Join) ───────────
                if (_selectedStatus == 'Join') ...[
                  const _SectionHeader(label: 'Bukti Transfer'),
                  const SizedBox(height: 6),
                  const Text(
                    'Wajib diunggah untuk klien dengan status "Join". Gambar disimpan terkompresi langsung di database.',
                    style: TextStyle(color: AppColors.neutral, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  _buildBuktiTransferSection(),
                  const SizedBox(height: 28),
                ],

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

  // ── WIDGET BUKTI TRANSFER ──────────────────────────────────────────────────
  Widget _buildBuktiTransferSection() {
    final hasImage = _buktiTransferBase64.isNotEmpty;
    final bytes = hasImage ? ImageHelper.decodeToBytes(_buktiTransferBase64) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImage && bytes != null) ...[
          GestureDetector(
            onTap: _viewFullImage,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.tertiary.withOpacity(0.4), width: 1.5),
                image: DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
              ),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Lihat penuh', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.tertiary, size: 14),
              const SizedBox(width: 6),
              Text(
                'Tersimpan • ${ImageHelper.estimateSizeKB(_buktiTransferBase64).toStringAsFixed(0)} KB',
                style: const TextStyle(color: AppColors.tertiary, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _isUploadingProof ? null : () => _pickBuktiTransfer(),
                icon: const Icon(Icons.refresh, size: 15, color: AppColors.primary),
                label: const Text('Ganti', style: TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              ),
            ],
          ),
        ] else ...[
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _isUploadingProof ? null : () => _pickBuktiTransfer(isRequired: true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFEF4444).withOpacity(0.04),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4), width: 1.5),
              ),
              child: _isUploadingProof
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                          SizedBox(height: 12),
                          Text('Memproses gambar...', style: TextStyle(color: AppColors.neutral, fontSize: 12.5)),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Icon(Icons.upload_file_outlined, size: 36, color: const Color(0xFFEF4444).withOpacity(0.7)),
                        const SizedBox(height: 10),
                        const Text('Unggah Bukti Transfer', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Wajib diisi • Ketuk untuk pilih foto', style: TextStyle(color: const Color(0xFFEF4444).withOpacity(0.8), fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
        ],
      ],
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
          onTap: () => _onStatusChanged(opt['value']),
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
                if (opt['value'] == 'Join') ...[
                  const SizedBox(width: 4),
                  Icon(Icons.receipt_long, size: 12, color: isSelected ? color : AppColors.neutral.withOpacity(0.6)),
                ],
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