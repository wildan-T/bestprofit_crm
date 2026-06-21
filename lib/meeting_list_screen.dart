import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'meeting_model.dart';
import 'add_meeting_screen.dart';
import 'notification_service.dart';
import 'app_colors.dart';

class MeetingListScreen extends StatefulWidget {
  const MeetingListScreen({super.key});

  @override
  State<MeetingListScreen> createState() => _MeetingListScreenState();
}

class _MeetingListScreenState extends State<MeetingListScreen> {
  String _tab = 'upcoming';

  // Data user yang sedang login
  String _currentUserUid  = '';
  String _currentUserRole = ''; // 'BC' | 'MC'
  String _currentUserName = '';
  bool   _userLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
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
            user.email?.split('@').first ?? '';
        _currentUserRole = data['role'] ?? '';
        _userLoaded      = true;
      });
    } else {
      setState(() {
        _currentUserName = user.email?.split('@').first ?? '';
        _userLoaded      = true;
      });
    }
  }

  bool get _isMC => _currentUserRole == 'MC';
  bool get _isBC => _currentUserRole == 'BC';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Jadwal Meeting',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          // Badge role di kanan atas
          if (_userLoaded)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isMC
                        ? AppColors.secondary.withOpacity(0.25)
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isMC ? 'MC' : _isBC ? 'BC' : 'SBC',
                    style: TextStyle(
                      color: _isMC ? AppColors.secondary : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Tab segment ──────────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentButton(
                    label: 'Mendatang',
                    icon: Icons.upcoming_outlined,
                    isSelected: _tab == 'upcoming',
                    onTap: () => setState(() => _tab = 'upcoming'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SegmentButton(
                    label: 'Riwayat',
                    icon: Icons.history,
                    isSelected: _tab == 'history',
                    onTap: () => setState(() => _tab = 'history'),
                  ),
                ),
              ],
            ),
          ),

          // ── List ─────────────────────────────────────────────────────────────
          Expanded(
            child: _userLoaded
                ? _buildList()
                : const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2)),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
              colors: [AppColors.secondary, Color(0xFFB8860B)]),
          boxShadow: [
            BoxShadow(
                color: AppColors.secondary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 6))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddMeetingScreen()),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Tambah Jadwal',
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

  Widget _buildList() {
    // 1. Filter langsung pada Stream untuk menghemat kuota Firestore
    Stream<QuerySnapshot> meetingStream;

    if (_isMC) {
      // MC berhak mengunduh seluruh data
      meetingStream = FirebaseFirestore.instance
          .collection('meetings')
          // Hapus orderBy di sini agar tidak memicu error Composite Index, 
          // karena data akan diurutkan secara lokal di langkah bawah.
          .snapshots();
    } else {
      // BC HANYA mengunduh data yang terkait dengan UID-nya
      meetingStream = FirebaseFirestore.instance
          .collection('meetings')
          .where(Filter.or(
            Filter('brokerUid', isEqualTo: _currentUserUid),
            Filter('coverBrokerUid', isEqualTo: _currentUserUid),
          ))
          .snapshots();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: meetingStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyState(
              Icons.error_outline, 'Terjadi kesalahan', 'Periksa koneksi Anda');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
        }

        final now = DateTime.now();
        var allMeetings = snapshot.requireData.docs
            .map((d) => MeetingModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList();

        // 2. Pemisahan dan Pengurutan Lokal
        List<MeetingModel> meetings;
        if (_tab == 'upcoming') {
          meetings = allMeetings.where((m) => m.dateTime.isAfter(now)).toList();
          meetings.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        } else {
          meetings = allMeetings.where((m) => !m.dateTime.isAfter(now)).toList();
          meetings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        }

        if (meetings.isEmpty) {
          return _buildEmptyState(
            _tab == 'upcoming' ? Icons.event_available_outlined : Icons.event_busy_outlined,
            _tab == 'upcoming' ? 'Belum ada jadwal' : 'Belum ada riwayat',
            _tab == 'upcoming' ? 'Tambah jadwal baru dengan tombol di bawah' : 'Jadwal yang sudah lewat akan tampil di sini',
          );
        }

        final Map<String, List<MeetingModel>> grouped = {};
        for (final m in meetings) {
          final key = DateFormat('yyyy-MM-dd').format(m.dateTime);
          grouped.putIfAbsent(key, () => []).add(m);
        }
        final groupKeys = grouped.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          itemCount: groupKeys.length,
          itemBuilder: (context, gi) {
            final key   = groupKeys[gi];
            final items = grouped[key]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: gi == 0 ? 0 : 18, bottom: 10, left: 4),
                  child: Text(
                    _formatDateHeader(items.first.dateTime),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                  ),
                ),
                ...items.map((m) => _MeetingCard(
                      meeting: m,
                      isMC: _isMC,
                      currentUserUid: _currentUserUid,
                      currentUserName: _currentUserName,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddMeetingScreen(meeting: m))),
                      onStatusAction: _isMC ? (meeting) => _showMCActionSheet(meeting) : null,
                    )),
              ],
            );
          },
        );
      },
    );
  }
  // ── MC Action Sheet ──────────────────────────────────────────────────────────
  Future<void> _showMCActionSheet(MeetingModel meeting) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MCActionSheet(
        meeting: meeting,
        mcUid: _currentUserUid,
        mcName: _currentUserName,
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  String _formatDateHeader(DateTime date) {
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff   = target.difference(today).inDays;

    if (diff == 0) {
      return 'HARI INI · ${DateFormat('dd MMM yyyy', 'id_ID').format(date)}';
    }
    if (diff == 1) {
      return 'BESOK · ${DateFormat('dd MMM yyyy', 'id_ID').format(date)}';
    }
    if (diff == -1) {
      return 'KEMARIN · ${DateFormat('dd MMM yyyy', 'id_ID').format(date)}';
    }
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date).toUpperCase();
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: AppColors.neutral.withOpacity(0.5)),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(color: AppColors.neutral, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MC ACTION SHEET — konfirmasi, selesai, batal, assign cover
// ═══════════════════════════════════════════════════════════════════════════════
class _MCActionSheet extends StatefulWidget {
  final MeetingModel meeting;
  final String mcUid;
  final String mcName;

  const _MCActionSheet({
    required this.meeting,
    required this.mcUid,
    required this.mcName,
  });

  @override
  State<_MCActionSheet> createState() => _MCActionSheetState();
}

class _MCActionSheetState extends State<_MCActionSheet> {
  final _mcNotesCtrl = TextEditingController();
  bool _isLoading = false;

  // Cover broker yang dipilih
  String _coverBrokerUid  = '';
  String _coverBrokerName = '';

  @override
  void initState() {
    super.initState();
    _mcNotesCtrl.text   = widget.meeting.mcNotes;
    _coverBrokerUid     = widget.meeting.coverBrokerUid;
    _coverBrokerName    = widget.meeting.coverBrokerName;
  }

  @override
  void dispose() {
    _mcNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(MeetingStatus status) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(widget.meeting.id)
          .update({
        'status':          status.value,
        'mcUid':           widget.mcUid,
        'mcName':          widget.mcName,
        'mcNotes':         _mcNotesCtrl.text.trim(),
        'coverBrokerUid':  _coverBrokerUid,
        'coverBrokerName': _coverBrokerName,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: AppColors.tertiary, size: 18),
            const SizedBox(width: 8),
            Text('Status diperbarui: ${status.label}',
                style: const TextStyle(color: Colors.white)),
          ]),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF8B1A1A),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickCoverBroker() async {
    final searchCtrl = TextEditingController();
    String search = '';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Pilih Cover Broker',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: Column(
              children: [
                // Search field
                Container(
                  decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.neutral.withOpacity(0.2))),
                  child: TextField(
                    controller: searchCtrl,
                    style: const TextStyle(color: AppColors.primary, fontSize: 14),
                    onChanged: (v) => setD(() => search = v.toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama broker...',
                      hintStyle:
                          TextStyle(color: AppColors.neutral, fontSize: 13),
                      prefixIcon:
                          Icon(Icons.search, color: AppColors.neutral, size: 18),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    // Ambil semua user dengan role SBC atau MC
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', whereIn: ['SBC', 'MC'])
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary, strokeWidth: 2));
                      }
                      final docs = snap.data!.docs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final uid  = d.id;
                        // Jangan tampilkan broker asli
                        if (uid == widget.meeting.brokerUid) return false;
                        final name = (data['name'] ??
                                data['fullName'] ??
                                '')
                            .toString()
                            .toLowerCase();
                        return search.isEmpty || name.contains(search);
                      }).toList();

                      if (docs.isEmpty) {
                        return const Center(
                            child: Text('Broker tidak ditemukan',
                                style:
                                    TextStyle(color: AppColors.neutral)));
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final data =
                              docs[i].data() as Map<String, dynamic>;
                          final uid  = docs[i].id;
                          final name = data['name'] ??
                              data['fullName'] ??
                              data['email'] ??
                              '';
                          final isSelected = uid == _coverBrokerUid;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.08),
                              ),
                              child: Center(
                                  child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w800))),
                            ),
                            title: Text(name,
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: AppColors.tertiary)
                                : null,
                            onTap: () => Navigator.pop(
                                context, {'uid': uid, 'name': name}),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (_coverBrokerUid.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pop(
                    context, {'uid': '', 'name': ''}),
                child: const Text('Hapus Cover',
                    style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Batal',
                  style: TextStyle(
                      color: AppColors.neutral,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _coverBrokerUid  = result['uid']!;
        _coverBrokerName = result['name']!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;
    final status  = meeting.status;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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

            // ── Header jadwal ────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.primary.withOpacity(0.08),
                  ),
                  child: const Icon(Icons.event_note_outlined,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Meeting dengan ${meeting.clientName}",
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm', 'id_ID')
                            .format(meeting.dateTime),
                        style: const TextStyle(
                            color: AppColors.neutral,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.neutral, height: 1),
            const SizedBox(height: 16),

            // ── Info BC & Client ──────────────────────────────────────────────
            _InfoRow(icon: Icons.assignment_ind_outlined,
                label: 'Broker (BC)', value: meeting.brokerName),
            if (meeting.clientName.isNotEmpty)
              _InfoRow(icon: Icons.person_outline,
                  label: 'Klien', value: meeting.clientName),
            if (meeting.location.isNotEmpty)
              _InfoRow(icon: Icons.location_on_outlined,
                  label: 'Lokasi', value: meeting.location),
            if (meeting.notes.isNotEmpty)
              _InfoRow(icon: Icons.notes_outlined,
                  label: 'Catatan BC', value: meeting.notes),

            const SizedBox(height: 20),

            // ── Cover Broker ──────────────────────────────────────────────────
            const Text('Cover Broker',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isLoading ? null : _pickCoverBroker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _coverBrokerUid.isNotEmpty
                      ? AppColors.tertiary.withOpacity(0.08)
                      : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _coverBrokerUid.isNotEmpty
                        ? AppColors.tertiary.withOpacity(0.4)
                        : AppColors.neutral.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _coverBrokerUid.isNotEmpty
                          ? Icons.swap_horiz
                          : Icons.person_add_outlined,
                      color: _coverBrokerUid.isNotEmpty
                          ? AppColors.tertiary
                          : AppColors.neutral,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _coverBrokerUid.isNotEmpty
                            ? _coverBrokerName
                            : 'Pilih cover broker untuk jadwal ini',
                        style: TextStyle(
                          color: _coverBrokerUid.isNotEmpty
                              ? AppColors.primary
                              : AppColors.neutral.withOpacity(0.7),
                          fontWeight: _coverBrokerUid.isNotEmpty
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.neutral, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Catatan MC ────────────────────────────────────────────────────
            const Text('Catatan MC',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neutral.withOpacity(0.25)),
              ),
              child: TextField(
                controller: _mcNotesCtrl,
                maxLines: 3,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Tambahkan catatan untuk meeting ini...',
                  hintStyle: TextStyle(
                      color: AppColors.neutral.withOpacity(0.6), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Action Buttons ────────────────────────────────────────────────
            if (_isLoading)
              const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2))
            else
              Column(
                children: [
                  // Konfirmasi / Acc
                  if (status == MeetingStatus.pending ||
                      status == MeetingStatus.cancelled)
                    _ActionButton(
                      icon: Icons.check_circle_outline,
                      label: 'Konfirmasi Meeting',
                      color: AppColors.tertiary,
                      onTap: () => _updateStatus(MeetingStatus.confirmed),
                    ),

                  // Tandai Selesai
                  if (status == MeetingStatus.confirmed) ...[
                    _ActionButton(
                      icon: Icons.task_alt,
                      label: 'Tandai Selesai (Ketemu)',
                      color: AppColors.primary,
                      onTap: () => _updateStatus(MeetingStatus.done),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Batalkan
                  if (status != MeetingStatus.cancelled &&
                      status != MeetingStatus.done) ...[
                    const SizedBox(height: 10),
                    _ActionButton(
                      icon: Icons.cancel_outlined,
                      label: 'Batalkan Meeting',
                      color: const Color(0xFFEF4444),
                      onTap: () => _updateStatus(MeetingStatus.cancelled),
                    ),
                  ],

                  // Re-open
                  if (status == MeetingStatus.done ||
                      status == MeetingStatus.cancelled) ...[
                    const SizedBox(height: 10),
                    _ActionButton(
                      icon: Icons.refresh,
                      label: 'Kembalikan ke Pending',
                      color: AppColors.neutral,
                      onTap: () => _updateStatus(MeetingStatus.pending),
                    ),
                  ],

                  // Simpan tanpa ganti status (cover / catatan)
                  const SizedBox(height: 10),
                  _ActionButton(
                    icon: Icons.save_outlined,
                    label: 'Simpan Catatan & Cover',
                    color: AppColors.secondary,
                    outlined: true,
                    onTap: () => _updateStatus(status),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppColors.primary : AppColors.backgroundLight,
          border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.neutral.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 17,
                color: isSelected ? Colors.white : AppColors.neutral),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.neutral,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MeetingStatus status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case MeetingStatus.confirmed: return AppColors.tertiary;
      case MeetingStatus.done:      return AppColors.primary;
      case MeetingStatus.cancelled: return const Color(0xFFEF4444);
      default:                      return AppColors.secondary;
    }
  }

  IconData get _icon {
    switch (status) {
      case MeetingStatus.confirmed: return Icons.check_circle_outline;
      case MeetingStatus.done:      return Icons.task_alt;
      case MeetingStatus.cancelled: return Icons.cancel_outlined;
      default:                      return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: 12),
          const SizedBox(width: 5),
          // Tambahkan Flexible agar teks panjang tidak menabrak batas layar
          Flexible(
            child: Text(
              status.label,
              style: TextStyle(color: _color, fontSize: 10.5, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final MeetingModel meeting;
  final bool isMC;
  final String currentUserUid;
  final String currentUserName;
  final VoidCallback onTap;
  final void Function(MeetingModel)? onStatusAction;

  const _MeetingCard({
    required this.meeting,
    required this.isMC,
    required this.currentUserUid,
    required this.currentUserName,
    required this.onTap,
    this.onStatusAction,
  });

  @override
  Widget build(BuildContext context) {
    final now       = DateTime.now();
    final isPast    = !meeting.dateTime.isAfter(now);
    final timeLabel = DateFormat('HH:mm').format(meeting.dateTime);
    final status    = meeting.status;
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isMC ? () => onStatusAction?.call(meeting) : onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kolom Waktu
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isPast ? AppColors.neutral.withOpacity(0.1) : statusColor.withOpacity(0.1),
                  ),
                  child: Column(
                    children: [
                      Text(timeLabel,
                          style: TextStyle(color: isPast ? AppColors.neutral : statusColor, fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('WIB',
                          style: TextStyle(color: (isPast ? AppColors.neutral : statusColor).withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                
                // Kolom Informasi Utama
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.clientName,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 14.5),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      if (meeting.location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _iconRow(Icons.location_on_outlined, meeting.location),
                      ],

                      // Broker info
                      const SizedBox(height: 4),
                      _iconRow(Icons.assignment_ind_outlined, 'BC: ${meeting.brokerName}', color: AppColors.secondary),

                      // Cover broker
                      if (meeting.coverBrokerName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _iconRow(Icons.swap_horiz, 'Cover: ${meeting.coverBrokerName}', color: AppColors.tertiary),
                      ],

                      // MC info
                      if (meeting.mcName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _iconRow(Icons.manage_accounts_outlined, 'MC: ${meeting.mcName}', color: AppColors.primary.withOpacity(0.7)),
                      ],

                      const SizedBox(height: 8),

                      // BAGIAN INI DIPASTIKAN HANYA MENGGUNAKAN WRAP, BUKAN ROW
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StatusBadge(status: status),
                          if (!isPast && meeting.reminderMinutes > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.notifications_active_outlined, size: 11, color: AppColors.secondary),
                                  const SizedBox(width: 4),
                                  // Menggunakan Flexible agar aman 100% dari overflow
                                  Flexible(
                                    child: Text(
                                      '${meeting.reminderMinutes} mnt',
                                      style: const TextStyle(color: AppColors.secondary, fontSize: 10.5, fontWeight: FontWeight.w800),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Icon paling kanan
                if (isMC)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.tune, color: AppColors.primary, size: 18),
                  )
                else
                  const Icon(Icons.chevron_right, color: AppColors.neutral, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color ?? AppColors.neutral),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
              style: TextStyle(color: color ?? AppColors.neutral, fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Color _statusColor(MeetingStatus s) {
    switch (s) {
      case MeetingStatus.confirmed: return AppColors.tertiary;
      case MeetingStatus.done:      return AppColors.primary;
      case MeetingStatus.cancelled: return const Color(0xFFEF4444);
      default:                      return AppColors.secondary;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.neutral),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.neutral,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              outlined ? Colors.transparent : color,
          shadowColor: Colors.transparent,
          side: outlined ? BorderSide(color: color, width: 1.5) : null,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: outlined ? color : Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: outlined ? color : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}