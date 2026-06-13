import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  // 'upcoming' = jadwal mendatang, 'history' = jadwal yang sudah lewat
  String _tab = 'upcoming';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Jadwal Meeting',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('meetings')
                  .orderBy('dateTime')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildEmptyState(
                    Icons.error_outline,
                    'Terjadi kesalahan',
                    'Periksa koneksi Anda',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                  );
                }

                final now = DateTime.now();
                final allMeetings = snapshot.requireData.docs
                    .map((d) => MeetingModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                    .toList();

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
                    _tab == 'upcoming'
                        ? 'Tambah jadwal baru dengan tombol di bawah'
                        : 'Jadwal yang sudah lewat akan tampil di sini',
                  );
                }

                // Kelompokkan berdasarkan tanggal
                final Map<String, List<MeetingModel>> grouped = {};
                for (final m in meetings) {
                  final key = DateFormat('yyyy-MM-dd').format(m.dateTime);
                  grouped.putIfAbsent(key, () => []).add(m);
                }

                final groupKeys = grouped.keys.toList();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                  itemCount: groupKeys.length,
                  itemBuilder: (context, groupIndex) {
                    final key = groupKeys[groupIndex];
                    final items = grouped[key]!;
                    final date = items.first.dateTime;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: groupIndex == 0 ? 0 : 18, bottom: 10, left: 4),
                          child: Text(
                            _formatDateHeader(date),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...items.map((m) => _MeetingCard(
                              meeting: m,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AddMeetingScreen(meeting: m)),
                              ),
                            )),
                      ],
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
          boxShadow: [
            BoxShadow(color: AppColors.secondary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6)),
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
                  Text('Tambah Jadwal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'HARI INI · ${DateFormat('dd MMM yyyy', 'id_ID').format(date)}';
    if (diff == 1) return 'BESOK · ${DateFormat('dd MMM yyyy', 'id_ID').format(date)}';
    if (diff == -1) return 'KEMARIN · ${DateFormat('dd MMM yyyy', 'id_ID').format(date)}';
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date).toUpperCase();
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
          Text(subtitle, style: const TextStyle(color: AppColors.neutral, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

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
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.neutral.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: isSelected ? Colors.white : AppColors.neutral),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.neutral,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final MeetingModel meeting;
  final VoidCallback onTap;

  const _MeetingCard({required this.meeting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPast = !meeting.dateTime.isAfter(now);
    final timeLabel = DateFormat('HH:mm').format(meeting.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kolom waktu
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isPast ? AppColors.neutral.withOpacity(0.1) : AppColors.primary.withOpacity(0.08),
                  ),
                  child: Column(
                    children: [
                      Text(
                        timeLabel,
                        style: TextStyle(
                          color: isPast ? AppColors.neutral : AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'WIB',
                        style: TextStyle(
                          color: (isPast ? AppColors.neutral : AppColors.primary).withOpacity(0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.title,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (meeting.clientName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 13, color: AppColors.neutral),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                meeting.clientName,
                                style: const TextStyle(color: AppColors.neutral, fontSize: 12.5, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (meeting.location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: AppColors.neutral),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                meeting.location,
                                style: TextStyle(color: AppColors.neutral.withOpacity(0.8), fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _statusChip(now),
                          if (!isPast && meeting.reminderMinutes > 0) ...[
                            const SizedBox(width: 6),
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
                                  Text(
                                    '${meeting.reminderMinutes} mnt',
                                    style: const TextStyle(color: AppColors.secondary, fontSize: 10.5, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.neutral, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(DateTime now) {
    final diff = meeting.dateTime.difference(now);
    String label;
    Color color;

    if (diff.isNegative) {
      label = 'Selesai';
      color = AppColors.neutral;
    } else if (diff.inMinutes <= 30) {
      label = diff.inMinutes <= 1 ? 'Segera dimulai' : 'Dalam ${diff.inMinutes} menit';
      color = const Color(0xFFEF4444);
    } else if (diff.inHours < 24) {
      label = diff.inMinutes < 120 ? 'Dalam ${diff.inMinutes} menit' : 'Dalam ${diff.inHours} jam';
      color = const Color(0xFFEF4444).withOpacity(0.85);
    } else {
      label = 'Dalam ${diff.inDays} hari';
      color = AppColors.tertiary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}