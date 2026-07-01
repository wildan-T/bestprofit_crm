import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_functions/firebase_functions.dart';
import 'user_model.dart';
import 'app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CATATAN IMPLEMENTASI:
// Fitur Create Akun (dengan email/password) membutuhkan Firebase Functions
// karena Firebase Admin SDK tidak tersedia di client-side Flutter.
// Alternatif: gunakan package 'firebase_functions' dan deploy Cloud Function
// bernama 'createUser', atau gunakan secondary FirebaseApp untuk register.
// File ini menggunakan pendekatan secondary FirebaseApp agar tidak logout.
// ═══════════════════════════════════════════════════════════════════════════════

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  String _searchQuery   = '';
  String _filterRole    = 'Semua';
  final  _searchCtrl    = TextEditingController();

  final List<String> _roles = ['Semua', 'MC', 'SBC', 'BC'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Manajemen Akun',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        // actions: [
        //   // Tombol tambah akun baru
        //   Padding(
        //     padding: const EdgeInsets.only(right: 8),
        //     child: IconButton(
        //       icon: Container(
        //         padding: const EdgeInsets.all(6),
        //         decoration: BoxDecoration(
        //           color: AppColors.secondary.withOpacity(0.2),
        //           borderRadius: BorderRadius.circular(8),
        //         ),
        //         child: const Icon(Icons.person_add_outlined,
        //             color: AppColors.secondary, size: 20),
        //       ),
        //       onPressed: () => _showUserForm(context),
        //       tooltip: 'Tambah Akun',
        //     ),
        //   ),
        // ],
      ),
      body: Column(
        children: [
          // ── Search & Filter ─────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.neutral.withOpacity(0.2))),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(
                        color: AppColors.primary, fontSize: 14),
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau no. HP...',
                      hintStyle: TextStyle(
                          color: AppColors.neutral.withOpacity(0.7),
                          fontSize: 14),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.neutral, size: 20),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _roles.map((r) {
                      final isSelected = _filterRole == r;
                      final color = _roleColor(r);
                      return GestureDetector(
                        onTap: () => setState(() => _filterRole = r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: isSelected
                                ? color.withOpacity(0.12)
                                : AppColors.backgroundLight,
                            border: Border.all(
                                color: isSelected
                                    ? color
                                    : AppColors.neutral.withOpacity(0.25),
                                width: 1.5),
                          ),
                          child: Text(r == 'Semua' ? 'Semua' : _roleLabelShort(r),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? color : AppColors.neutral)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── List ─────────────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _emptyState(Icons.error_outline,
                      'Terjadi kesalahan', 'Periksa koneksi Anda');
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2));
                }

                final users = snapshot.requireData.docs
                    .map((d) => UserModel.fromMap(
                        d.data() as Map<String, dynamic>, d.id))
                    .where((u) {
                  final matchSearch = _searchQuery.isEmpty ||
                      u.name.toLowerCase().contains(_searchQuery) ||
                      u.phone.contains(_searchQuery) ||
                      u.email.toLowerCase().contains(_searchQuery);
                  final matchRole =
                      _filterRole == 'Semua' || u.role == _filterRole;
                  return matchSearch && matchRole;
                }).toList();

                if (users.isEmpty) {
                  return _emptyState(Icons.people_outline,
                      'Tidak ada akun', 'Tambah akun baru dengan tombol +');
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                  itemCount: users.length,
                  itemBuilder: (context, i) => _UserCard(
                    user: users[i],
                    onEdit: () => _showUserForm(context, user: users[i]),
                    onDelete: () => _confirmDelete(context, users[i]),
                    currentUid: FirebaseAuth.instance.currentUser?.uid,
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // FAB tambah akun
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
              colors: [AppColors.secondary, Color(0xFFB8860B)]),
          boxShadow: [
            BoxShadow(
                color: AppColors.secondary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showUserForm(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_outlined,
                      color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Tambah Akun',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Show Form ──────────────────────────────────────────────────────────────
  void _showUserForm(BuildContext context, {UserModel? user}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserFormSheet(user: user),
    );
  }

  // ── Delete Confirm ─────────────────────────────────────────────────────────
  Future<void> _confirmDelete(BuildContext context, UserModel user) async {
    // Proteksi: MC tidak boleh hapus dirinya sendiri
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (user.uid == currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tidak dapat menghapus akun Anda sendiri',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF8B1A1A),
      ));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Akun?',
            style: TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w800)),
        content: Text(
          'Hapus akun "${user.name}" (${user.roleLabel})?\n\n'
          'Data Firestore akan dihapus. Akun Firebase Auth harus dihapus manual melalui Firebase Console.',
          style: const TextStyle(color: AppColors.neutral, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal',
                  style: TextStyle(
                      color: AppColors.neutral,
                      fontWeight: FontWeight.w600))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Hapus',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Akun ${user.name} berhasil dihapus',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.neutral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal menghapus: $e',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF8B1A1A),
          ));
        }
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _roleColor(String role) {
    switch (role) {
      case 'MC':  return AppColors.primary;
      case 'SBC': return AppColors.secondary;
      case 'BC':  return AppColors.tertiary;
      default:    return AppColors.neutral;
    }
  }

  String _roleLabelShort(String role) {
    switch (role) {
      case 'MC':  return 'MC';
      case 'SBC': return 'SBC';
      case 'BC':  return 'BC';
      default:    return role;
    }
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: AppColors.neutral.withOpacity(0.4)),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  color: AppColors.neutral, fontSize: 13)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// USER CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String? currentUid;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.currentUid,
  });

  Color get _roleColor {
    switch (user.role) {
      case 'MC':  return AppColors.primary;
      case 'SBC': return AppColors.secondary;
      case 'BC':  return AppColors.tertiary;
      default:    return AppColors.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = user.uid == currentUid;
    final initials = user.name.trim().isNotEmpty
        ? user.name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _roleColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: _roleColor.withOpacity(0.12),
              ),
              child: Center(
                child: Text(initials,
                    style: TextStyle(
                        color: _roleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 12, color: AppColors.neutral),
                      const SizedBox(width: 4),
                      Text(user.phone.isNotEmpty ? user.phone : '-',
                          style: const TextStyle(
                              color: AppColors.neutral,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          size: 12, color: AppColors.neutral),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(user.email,
                            style: TextStyle(
                                color: AppColors.neutral.withOpacity(0.8),
                                fontSize: 11.5),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _roleColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(user.roleLabel,
                        style: TextStyle(
                            color: _roleColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3)),
                  ),
                ],
              ),
            ),

            // Action buttons
            Column(
              children: [
                _actionBtn(Icons.edit_outlined, AppColors.primary, onEdit),
                const SizedBox(height: 8),
                if (!isCurrentUser)
      _actionBtn(
        Icons.delete_outline,
        const Color(0xFFEF4444),
        onDelete,
      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORM SHEET — CREATE / EDIT AKUN
// ═══════════════════════════════════════════════════════════════════════════════
class _UserFormSheet extends StatefulWidget {
  final UserModel? user; // null = create, terisi = edit

  const _UserFormSheet({this.user});

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _selectedRole = 'BC';
  bool _isLoading      = false;
  bool _obscurePass    = true;

  bool get _isEditMode => widget.user != null;

  final List<Map<String, dynamic>> _roleOptions = [
    {
      'value': 'BC',
      'label': 'Business Consultant',
      'short': 'BC',
      'color': AppColors.tertiary,
      'desc': 'Broker lapangan yang mengelola klien',
    },
    {
      'value': 'SBC',
      'label': 'Senior Business Consultant',
      'short': 'SBC',
      'color': AppColors.secondary,
      'desc': 'Senior broker yang bertugas membimbing serta mendukung pengembangan BC',
    },
    {
      'value': 'MC',
      'label': 'Manager Consultant',
      'short': 'MC',
      'color': AppColors.primary,
      'desc': 'Manager dengan akses penuh ke semua fitur',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _nameCtrl.text   = widget.user!.name;
      _phoneCtrl.text  = widget.user!.phone;
      _emailCtrl.text  = widget.user!.email;
      _selectedRole    = widget.user!.role;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isEditMode) {
        if (!_isEditMode && _selectedRole == 'MC') {
  _showError('Tidak boleh membuat akun MC!');
  return;
}
        // ── UPDATE: hanya update data Firestore, tidak mengubah password ──
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user!.uid)
            .update({
          'name':  _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'role':  _selectedRole,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context);
          _showSnack('Akun berhasil diperbarui!', AppColors.primary);
        }
      } else {
        // ── CREATE: daftarkan ke Firebase Auth, lalu simpan ke Firestore ──
        // Menggunakan secondary FirebaseApp agar MC tidak ter-logout
        final secondaryApp = await Firebase.initializeApp(
          name:    'secondary',
          options: Firebase.app().options,
        );

        try {
          final cred = await FirebaseAuth.instanceFor(app: secondaryApp)
              .createUserWithEmailAndPassword(
            email:    _emailCtrl.text.trim(),
            password: _passwordCtrl.text.trim(),
          );

          final newUid = cred.user!.uid;

          // Simpan profil ke Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(newUid)
              .set({
            'name':      _nameCtrl.text.trim(),
            'phone':     _phoneCtrl.text.trim(),
            'email':     _emailCtrl.text.trim(),
            'role':      _selectedRole,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Logout secondary agar tidak interfere
          await FirebaseAuth.instanceFor(app: secondaryApp).signOut();

          if (mounted) {
            Navigator.pop(context);
            _showSnack('Akun berhasil dibuat!', AppColors.tertiary);
          }
        } finally {
          // Selalu hapus secondary app setelah selesai
          await secondaryApp.delete();
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError(_authErrorMessage(e.code));
    } catch (e) {
      _showError('Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Gunakan email lain.';
      case 'weak-password':
        return 'Password terlalu lemah (min. 6 karakter).';
      case 'invalid-email':
        return 'Format email tidak valid.';
      default:
        return 'Error: $code';
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(msg, style: const TextStyle(color: Colors.white)),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF8B1A1A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  List<Map<String, dynamic>> get _filteredRoles {
  // CREATE → tidak boleh ada MC
  if (!_isEditMode) {
    return _roleOptions.where((r) => r['value'] != 'MC').toList();
  }

  // EDIT:
  if (widget.user!.role == 'MC') {
    // Kalau edit MC → hanya MC saja
    return _roleOptions.where((r) => r['value'] == 'MC').toList();
  } else {
    // Selain MC → tidak boleh lihat MC
    return _roleOptions.where((r) => r['value'] != 'MC').toList();
  }
}

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomPadding),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.neutral.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),

              // Judul
              Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.primary.withOpacity(0.08),
                    ),
                    child: const Icon(Icons.manage_accounts_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditMode ? 'Edit Akun' : 'Tambah Akun Baru',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // ── Nama Lengkap ──────────────────────────────────────────────
              _buildLabel('Nama Lengkap'),
              const SizedBox(height: 8),
              _buildField(
                controller: _nameCtrl,
                hint: 'Masukkan nama lengkap',
                icon: Icons.person_outline,
                validator: (v) =>
                    v!.trim().isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),

              // ── No. Telepon ───────────────────────────────────────────────
              _buildLabel('Nomor Telepon / WhatsApp'),
              const SizedBox(height: 8),
              _buildField(
                controller: _phoneCtrl,
                hint: '08xx xxxx xxxx',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v!.trim().isEmpty ? 'Nomor telepon wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              // ── Email ─────────────────────────────────────────────────────
              _buildLabel('Email'),
              const SizedBox(height: 8),
              _buildField(
                controller: _emailCtrl,
                hint: 'email@bestprofit.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                readOnly: _isEditMode, // email tidak bisa diubah saat edit
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Email wajib diisi';
                  if (!v.contains('@')) return 'Format email tidak valid';
                  return null;
                },
              ),

              // ── Password (hanya saat create) ──────────────────────────────
              if (!_isEditMode) ...[
                const SizedBox(height: 16),
                _buildLabel('Password'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _passwordCtrl,
                  hint: 'Min. 6 karakter',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePass,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.neutral, size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                  validator: (v) {
                    if (v!.isEmpty) return 'Password wajib diisi';
                    if (v.length < 6) return 'Min. 6 karakter';
                    return null;
                  },
                ),
              ],

              // ── Info ubah password saat edit ──────────────────────────────
              // if (_isEditMode) ...[
              //   const SizedBox(height: 10),
              //   Container(
              //     padding: const EdgeInsets.all(11),
              //     decoration: BoxDecoration(
              //       color: AppColors.neutral.withOpacity(0.06),
              //       borderRadius: BorderRadius.circular(10),
              //       border: Border.all(
              //           color: AppColors.neutral.withOpacity(0.2)),
              //     ),
              //     child: const Row(
              //       children: [
              //         Icon(Icons.info_outline,
              //             size: 15, color: AppColors.neutral),
              //         SizedBox(width: 8),
              //         Expanded(
              //           child: Text(
              //             'Password tidak dapat diubah dari sini. Gunakan Firebase Console atau fitur reset password.',
              //             style: TextStyle(
              //                 color: AppColors.neutral,
              //                 fontSize: 11.5,
              //                 height: 1.4),
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // ],
              const SizedBox(height: 22),

              // ── Role Selector ─────────────────────────────────────────────
              _buildLabel('Role / Jabatan'),
              const SizedBox(height: 12),
              ..._filteredRoles.map((opt) {
                final isSelected = _selectedRole == opt['value'];
                final color = opt['color'] as Color;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedRole = opt['value']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.08)
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected
                              ? color
                              : AppColors.neutral.withOpacity(0.25),
                          width: isSelected ? 2 : 1.5),
                    ),
                    child: Row(
                      children: [
                        // Role badge
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            color: color.withOpacity(0.15),
                          ),
                          child: Center(
                            child: Text(opt['short'],
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(opt['label'],
                                  style: TextStyle(
                                      color: isSelected
                                          ? color
                                          : AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text(opt['desc'],
                                  style: const TextStyle(
                                      color: AppColors.neutral,
                                      fontSize: 11.5)),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle,
                              color: color, size: 20),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),

              // ── Tombol Simpan ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: EdgeInsets.zero),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _isLoading
                          ? null
                          : const LinearGradient(
                              colors: [
                                AppColors.primary,
                                Color(0xFF001F50)
                              ]),
                      color: _isLoading
                          ? AppColors.neutral.withOpacity(0.2)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isEditMode
                                      ? Icons.save_outlined
                                      : Icons.person_add_outlined,
                                  color: Colors.white, size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _isEditMode
                                      ? 'SIMPAN PERUBAHAN'
                                      : 'BUAT AKUN',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 2),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 0.8),
      );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly
            ? AppColors.backgroundLight
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.neutral.withOpacity(0.3), width: 1.5),
      ),
      child: TextFormField(
        controller:   controller,
        keyboardType: keyboardType,
        obscureText:  obscureText,
        readOnly:     readOnly,
        validator:    validator,
        style: TextStyle(
            color: readOnly ? AppColors.neutral : AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: AppColors.neutral.withOpacity(0.6), fontSize: 14),
          prefixIcon: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: AppColors.neutral, size: 20)),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          errorStyle: const TextStyle(
              color: Color(0xFFEF4444), fontSize: 11),
        ),
      ),
    );
  }
}