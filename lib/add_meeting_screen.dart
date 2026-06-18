import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'meeting_model.dart';
import 'notification_service.dart';
import 'app_colors.dart';

class AddMeetingScreen extends StatefulWidget {
  final MeetingModel? meeting; // null = tambah baru, terisi = edit

  const AddMeetingScreen({super.key, this.meeting});

  @override
  State<AddMeetingScreen> createState() => _AddMeetingScreenState();
}

class _AddMeetingScreenState extends State<AddMeetingScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController    = TextEditingController();
  final _clientController   = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController    = TextEditingController();

  DateTime?   _selectedDate;
  TimeOfDay?  _selectedTime;
  int         _reminderMinutes = 30;
  bool        _isLoading  = false;
  bool        _isDeleting = false;

  // Data broker yang sedang login (diisi saat initState)
  String _currentUserUid  = '';
  String _currentUserName = '';
  String _currentUserRole = ''; // 'BC' | 'MC' | lainnya

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;

  bool get _isEditMode => widget.meeting != null;

  final List<Map<String, dynamic>> _reminderOptions = const [
    {'value': 0,    'label': 'Tanpa pengingat'},
    {'value': 15,   'label': '15 menit'},
    {'value': 30,   'label': '30 menit'},
    {'value': 60,   'label': '1 jam'},
    {'value': 120,  'label': '2 jam'},
    {'value': 1440, 'label': '1 hari'},
  ];

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _loadCurrentUser();

    final m = widget.meeting;
    if (m != null) {
      _clientController.text   = m.clientName;
      _locationController.text = m.location;
      _notesController.text    = m.notes;
      _selectedDate     = DateTime(m.dateTime.year, m.dateTime.month, m.dateTime.day);
      _selectedTime     = TimeOfDay(hour: m.dateTime.hour, minute: m.dateTime.minute);
      _reminderMinutes  = m.reminderMinutes;
    } else {
      final now          = DateTime.now().add(const Duration(hours: 1));
      final roundedMin   = now.minute < 30 ? 30 : 0;
      final roundedHour  = now.minute < 30 ? now.hour : now.hour + 1;
      _selectedDate      = DateTime(now.year, now.month, now.day);
      _selectedTime      = TimeOfDay(hour: roundedHour % 24, minute: roundedMin);
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _currentUserUid = user.uid;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      setState(() {
        _currentUserName = data['name'] ?? data['fullName'] ??
            user.email?.split('@').first ?? 'Broker';
        _currentUserRole = data['role'] ?? '';
      });
    } else {
      setState(() {
        _currentUserName = user.email?.split('@').first ?? 'Broker';
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _titleController.dispose();
    _clientController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime get _combinedDateTime {
    final date = _selectedDate ?? DateTime.now();
    final time = _selectedTime ?? TimeOfDay.now();
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ── DATE & TIME PICKER ──────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ── PICK CLIENT FROM FIRESTORE ───────────────────────────────────────────────
  Future<void> _pickClient() async {
    final searchController = TextEditingController();
    String search = '';
    final user = FirebaseAuth.instance.currentUser;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.neutral.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 16),
                      const Text('Pilih Klien Anda', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.neutral.withOpacity(0.2))),
                        child: TextField(
                          controller: searchController,
                          style: const TextStyle(color: AppColors.primary, fontSize: 14),
                          onChanged: (val) => setSheetState(() => search = val.toLowerCase()),
                          decoration: const InputDecoration(
                            hintText: 'Cari nama klien...', hintStyle: TextStyle(color: AppColors.neutral, fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: AppColors.neutral, size: 20), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          // Hanya mengambil klien milik broker ini saja
                          stream: FirebaseFirestore.instance.collection('clients').where('brokerUid', isEqualTo: user?.uid).snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
                            
                            final docs = snapshot.data!.docs.where((d) {
                              final name = (d.data() as Map<String, dynamic>)['name']?.toString().toLowerCase() ?? '';
                              return search.isEmpty || name.contains(search);
                            }).toList();

                            if (docs.isEmpty) return const Center(child: Text('Anda belum memiliki klien', style: TextStyle(color: AppColors.neutral)));

                            return ListView.builder(
                              controller: scrollController,
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final data = docs[index].data() as Map<String, dynamic>;
                                final name = data['name'] ?? '';
                                final phone = data['phone'] ?? '';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(width: 40, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.primary.withOpacity(0.08)), child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)))),
                                  title: Text(name, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                                  subtitle: Text(phone, style: const TextStyle(color: AppColors.neutral, fontSize: 12)),
                                  onTap: () => Navigator.pop(context, name),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (selected != null) setState(() => _clientController.text = selected);
  }

  // ── SAVE ─────────────────────────────────────────────────────────────────────
  Future<void> _saveMeeting() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final dateTime = _combinedDateTime;

      final meetingData = MeetingModel(
        id: widget.meeting?.id ?? '',
        clientName: _clientController.text.trim(),
        location: _locationController.text.trim(),
        notes: _notesController.text.trim(),
        dateTime: dateTime,
        reminderMinutes: _reminderMinutes,
        // Broker: jika edit → pertahankan broker asli; jika baru → pakai user login
        brokerUid:  widget.meeting?.brokerUid  ?? _currentUserUid,
        brokerName: widget.meeting?.brokerName ?? _currentUserName,
        // MC & cover tetap dipertahankan saat edit oleh BC
        mcUid:          widget.meeting?.mcUid ?? '',
        mcName:         widget.meeting?.mcName ?? '',
        coverBrokerUid:  widget.meeting?.coverBrokerUid ?? '',
        coverBrokerName: widget.meeting?.coverBrokerName ?? '',
        status:  widget.meeting?.status ?? MeetingStatus.pending,
        mcNotes: widget.meeting?.mcNotes ?? '',
      );

      String docId;
      if (_isEditMode) {
        docId = widget.meeting!.id;
        await FirebaseFirestore.instance
            .collection('meetings')
            .doc(docId)
            .update(meetingData.toMap());
      } else {
        final ref = await FirebaseFirestore.instance
            .collection('meetings')
            .add(meetingData.toMap());
        docId = ref.id;
      }

      // Jadwalkan ulang notifikasi pengingat
      final notifId  = docId.hashCode & 0x7FFFFFFF;
      final timeLabel = DateFormat('HH:mm').format(dateTime);
      String body = 'Dimulai pukul $timeLabel';
      if (meetingData.clientName.isNotEmpty) body += ' • ${meetingData.clientName}';
      if (meetingData.location.isNotEmpty) body += '\n📍 ${meetingData.location}';

      await NotificationService.instance.scheduleMeetingReminder(
        id: notifId,
        title: '⏰ Meeting dengan ${meetingData.clientName}',
        body: body,
        meetingDateTime: dateTime,
        reminderMinutesBefore: _reminderMinutes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: AppColors.tertiary, size: 18),
            const SizedBox(width: 8),
            Text(_isEditMode
                ? 'Jadwal berhasil diperbarui!'
                : 'Jadwal berhasil disimpan!',
                style: const TextStyle(color: Colors.white)),
          ]),
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
          content: Text('Gagal menyimpan: $e',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF8B1A1A),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────────
  Future<void> _deleteMeeting() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Jadwal?',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
        content: Text('Apakah Anda yakin ingin menghapus jadwal dengan "${widget.meeting!.clientName}"?', style: const TextStyle(color: AppColors.neutral)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal',
                  style: TextStyle(color: AppColors.neutral, fontWeight: FontWeight.w600))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Hapus',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        final notifId = widget.meeting!.id.hashCode & 0x7FFFFFFF;
        await NotificationService.instance.cancelReminder(notifId);
        await FirebaseFirestore.instance
            .collection('meetings')
            .doc(widget.meeting!.id)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Jadwal berhasil dihapus',
                style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.neutral,
          ));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Gagal menghapus: $e',
                  style: const TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF8B1A1A)));
        }
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final reminderTime =
        _combinedDateTime.subtract(Duration(minutes: _reminderMinutes));
    final isReminderInPast =
        _reminderMinutes > 0 && reminderTime.isBefore(DateTime.now());

    // Broker display: nama broker yang membuat jadwal
    final displayBrokerName = _isEditMode
        ? widget.meeting!.brokerName
        : (_currentUserName.isEmpty ? '...' : _currentUserName);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: Text(_isEditMode ? 'Edit Jadwal' : 'Tambah Jadwal',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _isDeleting ? null : _deleteMeeting,
              tooltip: 'Hapus Jadwal',
            ),
        ],
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

                // ── Info Broker ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.12),
                        ),
                        child: const Icon(Icons.assignment_ind_outlined,
                            color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dibuat oleh (BC)',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.neutral,
                                    letterSpacing: 0.8)),
                            const SizedBox(height: 2),
                            Text(displayBrokerName,
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('BC',
                            style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Detail Jadwal ─────────────────────────────────────────────
                const _SectionHeader(label: 'Detail Jadwal'),
                const SizedBox(height: 14),
                _buildField(
                  controller: _clientController,
                  label: 'Nama Klien',
                  hint: 'Pilih atau ketik nama klien',
                  icon: Icons.person_outline,
                  validator: (v) => v!.isEmpty ? 'Nama klien harus diisi' : null,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: AppColors.secondary),
                    onPressed: _pickClient,
                    tooltip: 'Pilih dari daftar klien',
                  ),
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _locationController,
                  label: 'Lokasi / Platform Meeting',
                  hint: 'Contoh: Kantor Pusat / Zoom Meeting',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 28),

                // ── Tanggal & Waktu ────────────────────────────────────────────
                const _SectionHeader(label: 'Tanggal & Waktu'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildPickerField(
                        label: 'Tanggal',
                        value: _selectedDate != null
                            ? DateFormat('dd MMM yyyy', 'id_ID')
                                .format(_selectedDate!)
                            : 'Pilih tanggal',
                        icon: Icons.calendar_today_outlined,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPickerField(
                        label: 'Waktu',
                        value: _selectedTime != null
                            ? _selectedTime!.format(context)
                            : 'Pilih waktu',
                        icon: Icons.access_time,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Pengingat ─────────────────────────────────────────────────
                const _SectionHeader(label: 'Pengingat Notifikasi'),
                const SizedBox(height: 6),
                const Text(
                  'Anda akan menerima notifikasi sebelum jadwal dimulai.',
                  style: TextStyle(color: AppColors.neutral, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                _buildReminderSelector(),
                if (_reminderMinutes > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isReminderInPast
                              ? const Color(0xFFEF4444)
                              : AppColors.tertiary)
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: (isReminderInPast
                                  ? const Color(0xFFEF4444)
                                  : AppColors.tertiary)
                              .withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isReminderInPast
                              ? Icons.warning_amber_rounded
                              : Icons.notifications_active_outlined,
                          color: isReminderInPast
                              ? const Color(0xFFEF4444)
                              : AppColors.tertiary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isReminderInPast
                                ? 'Waktu pengingat sudah lewat. Notifikasi tidak akan dikirim.'
                                : 'Notifikasi akan muncul pada ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(reminderTime)} WIB',
                            style: TextStyle(
                              color: isReminderInPast
                                  ? const Color(0xFFEF4444)
                                  : AppColors.tertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                // ── Catatan ────────────────────────────────────────────────────
                const _SectionHeader(label: 'Catatan Tambahan'),
                const SizedBox(height: 14),
                _buildField(
                  controller: _notesController,
                  label: 'Catatan (Opsional)',
                  hint: 'Agenda, hal yang perlu disiapkan, dll.',
                  icon: Icons.notes_outlined,
                  maxLines: 4,
                ),
                const SizedBox(height: 36),

                // ── Tombol Simpan ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveMeeting,
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
                                colors: [AppColors.primary, Color(0xFF001F50)]),
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
                                  const Icon(Icons.save_outlined,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                      _isEditMode
                                          ? 'SIMPAN PERUBAHAN'
                                          : 'SIMPAN JADWAL',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 2)),
                                ],
                              ),
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

  // ── HELPER WIDGETS ───────────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.neutral.withOpacity(0.3), width: 1.5)),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: const TextStyle(
                color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: AppColors.neutral.withOpacity(0.6), fontSize: 14),
              prefixIcon: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, color: AppColors.neutral, size: 20)),
              prefixIconConstraints: const BoxConstraints(minWidth: 44),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                  vertical: maxLines > 1 ? 14 : 0,
                  horizontal: maxLines > 1 ? 16 : 0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.8)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.neutral.withOpacity(0.3), width: 1.5)),
            child: Row(
              children: [
                Icon(icon, color: AppColors.secondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(value,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderSelector() {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: _reminderOptions.map((opt) {
        final isSelected = _reminderMinutes == opt['value'];
        return GestureDetector(
          onTap: () => setState(() => _reminderMinutes = opt['value']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? AppColors.secondary.withOpacity(0.15)
                  : AppColors.surface,
              border: Border.all(
                  color: isSelected
                      ? AppColors.secondary
                      : AppColors.neutral.withOpacity(0.3),
                  width: isSelected ? 2 : 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  opt['value'] == 0
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_active_outlined,
                  size: 14,
                  color: isSelected ? AppColors.secondary : AppColors.neutral,
                ),
                const SizedBox(width: 6),
                Text(opt['label'],
                    style: TextStyle(
                        color: isSelected
                            ? AppColors.secondary
                            : AppColors.neutral,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 12.5)),
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
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
                colors: [AppColors.secondary, Color(0xFFB8860B)]),
          ),
        ),
        const SizedBox(width: 10),
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 1.5)),
      ],
    );
  }
}