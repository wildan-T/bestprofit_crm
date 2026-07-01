import 'package:bestprofit_crm/account_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'client_list_screen.dart';
import 'meeting_list_screen.dart';
import 'login_screen.dart';
import 'app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    _DashboardTab(onSeeSchedule: () => setState(() => _currentIndex = 2)),
    const ClientListScreen(),
    const MeetingListScreen(),
    const _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: AppColors.neutral.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))]),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary, unselectedItemColor: AppColors.neutral.withOpacity(0.6),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12), unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          type: BottomNavigationBarType.fixed, elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Klien'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Jadwal'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  final VoidCallback onSeeSchedule;
  const _DashboardTab({required this.onSeeSchedule});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  String _selectedFilter = '7 Hari';
  final List<String> _filterOptions = ['7 Hari', '14 Hari', '30 Hari'];

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi ☀️';
    if (hour < 15) return 'Selamat Siang 🌤';
    if (hour < 18) return 'Selamat Sore 🌇';
    return 'Selamat Malam 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    // 1. PINDAHKAN STREAM BUILDER USER KE PALING ATAS
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
        }
        
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        
        // Ekstrak Role
        final bool isMC = userData != null && userData['role'] == 'MC';
        
        // Ekstrak Nama dari Firestore (fallback ke email jika kosong)
        final String rawName = userData?['name'] ?? userData?['fullName'] ?? user.email?.split('@').first ?? 'KARYAWAN';
        final String displayName = rawName.toUpperCase();

        // Buat Stream dinamis berdasarkan Role
        Stream<QuerySnapshot> meetingStream = isMC 
            ? FirebaseFirestore.instance.collection('meetings').snapshots() 
            : FirebaseFirestore.instance.collection('meetings').where('createdByUid', isEqualTo: user.uid).snapshots();

        Stream<QuerySnapshot> clientStream = isMC 
            ? FirebaseFirestore.instance.collection('clients').snapshots()
            : FirebaseFirestore.instance.collection('clients').where('brokerUid', isEqualTo: user.uid).snapshots();

        return Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 240,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.primary, Color(0xFF001F50)]),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Row(
                      children: [
                        Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surface), child: const Icon(Icons.show_chart, color: AppColors.primary, size: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getGreeting(), style: const TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                              // MENGGUNAKAN NAMA DARI FIRESTORE DI SINI
                              Text(displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text('Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(height: 20),

                  // Menampilkan Data Klien dan Meeting
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: meetingStream,
                      builder: (context, meetingSnapshot) {
                        if (meetingSnapshot.hasError) return const Center(child: Text('Terjadi kesalahan', style: TextStyle(color: Colors.white)));
                        if (meetingSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));

                        return StreamBuilder<QuerySnapshot>(
                          stream: clientStream,
                          builder: (context, clientSnapshot) {
                            if (clientSnapshot.hasError) return const Center(child: Text('Terjadi kesalahan', style: TextStyle(color: Colors.white)));
                            if (clientSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));

                            final meetingDocs = meetingSnapshot.data!.docs;
                            final clientDocs = clientSnapshot.data!.docs;

                            // Kalkulasi Data Meeting
                            int totalMeeting = meetingDocs.length;
                            int meetingToday = 0;
                            final now = DateTime.now();
                            final startOfToday = DateTime(now.year, now.month, now.day);
                            final endOfToday = startOfToday.add(const Duration(days: 1));

                            for (var doc in meetingDocs) {
                              final data = doc.data() as Map<String, dynamic>;
                              if (data['dateTime'] != null) {
                                final dt = (data['dateTime'] as Timestamp).toDate();
                                if (dt.isAfter(startOfToday.subtract(const Duration(milliseconds: 1))) && dt.isBefore(endOfToday)) {
                                  meetingToday++;
                                }
                              }
                            }

                            // Kalkulasi Data Pie Chart Klien
                            int hot = 0, warm = 0, cold = 0, join = 0, closed = 0;
                            for (var doc in clientDocs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final status = data['prospectStatus'] ?? '';
                              if (status == 'Hot') hot++;
                              if (status == 'Warm') warm++;
                              if (status == 'Cold') cold++;
                              if (status == 'Join') join++;
                              if (status == 'Closed') closed++;
                            }

                            return ListView(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              physics: const BouncingScrollPhysics(),
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildStatCard('Total Meeting', totalMeeting.toString(), Icons.handshake_outlined, AppColors.secondary)),
                                    const SizedBox(width: 14),
                                    Expanded(child: _buildStatCard('Meeting Hari Ini', meetingToday.toString(), Icons.today, AppColors.tertiary)),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _buildUpcomingMeetingCard(meetingDocs), 
                                const SizedBox(height: 24),
                                _buildBarChartSection(meetingDocs),
                                const SizedBox(height: 24),
                                _buildPieChartSection(hot, warm, cold, join, closed),
                              ],
                            );
                          },
                        );
                      },
                    )
                  ),
                ],
              ),
            ),
          ],
        );
      }
    );
  }

  // --- WIDGET DI BAWAHNYA TETAP SAMA ---

  Widget _buildUpcomingMeetingCard(List<QueryDocumentSnapshot> meetingDocs) {
    final now = DateTime.now();
    final upcoming = meetingDocs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((m) => m['dateTime'] != null && (m['dateTime'] as Timestamp).toDate().isAfter(now))
        .toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    upcoming.sort((a, b) => (a['dateTime'] as Timestamp).compareTo(b['dateTime'] as Timestamp));
    final next = upcoming.first;
    final dateTime = (next['dateTime'] as Timestamp).toDate();
    final diff = dateTime.difference(now);
    
    String relative;
    if (diff.inMinutes < 60) {
      relative = 'Dalam ${diff.inMinutes} menit';
    } else if (diff.inHours < 24) {
      relative = 'Dalam ${diff.inHours} jam';
    } else {
      relative = 'Dalam ${diff.inDays} hari';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: widget.onSeeSchedule,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF001F50)]),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.secondary.withOpacity(0.2)),
              child: const Icon(Icons.event_note_outlined, color: AppColors.secondary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    next['clientName'] ?? 'Meeting Klien',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${DateFormat('dd MMM, HH:mm', 'id_ID').format(dateTime)} • $relative',
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral.withOpacity(0.15), width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.neutral.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(count, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutral)),
        ],
      ),
    );
  }

  Widget _buildBarChartSection(List<QueryDocumentSnapshot> meetingDocs) {
    int days = int.parse(_selectedFilter.split(' ')[0]);
    DateTime now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));

    Map<String, int> meetingDataMap = {};
    for (int i = 0; i < days; i++) {
      DateTime d = startDate.add(Duration(days: i));
      meetingDataMap[DateFormat('dd/MM').format(d)] = 0;
    }

    for (var doc in meetingDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['dateTime'] != null) {
        DateTime dt = (data['dateTime'] as Timestamp).toDate();
        if (dt.isAfter(startDate.subtract(const Duration(days: 1)))) {
          String key = DateFormat('dd/MM').format(dt);
          if (meetingDataMap.containsKey(key)) {
            meetingDataMap[key] = meetingDataMap[key]! + 1;
          }
        }
      }
    }

    List<BarChartGroupData> barGroups = [];
    int index = 0;
    double maxY = 0;
    meetingDataMap.forEach((dateStr, count) {
      if (count > maxY) maxY = count.toDouble();
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(), color: AppColors.primary, width: days <= 7 ? 16 : 8,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(show: true, toY: (maxY > 5 ? maxY : 5) + 1, color: AppColors.neutral.withOpacity(0.1)),
            ),
          ],
        ),
      );
      index++;
    });

    List<String> dateLabels = meetingDataMap.keys.toList();

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.neutral.withOpacity(0.15), width: 1.5), boxShadow: [BoxShadow(color: AppColors.neutral.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tren Meeting Klien', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
              Container(
                height: 32, padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.neutral.withOpacity(0.2))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter, icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 20),
                    style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                    onChanged: (newValue) { if (newValue != null) setState(() => _selectedFilter = newValue); },
                    items: _filterOptions.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: (days * 35.0) < (MediaQuery.of(context).size.width - 80) ? MediaQuery.of(context).size.width - 80 : (days * 35.0),
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround, maxY: (maxY > 5 ? maxY : 5) + 1, barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int idx = value.toInt();
                          if (idx < 0 || idx >= dateLabels.length) return const SizedBox.shrink();
                          return Padding(padding: const EdgeInsets.only(top: 8), child: Text(dateLabels[idx], style: const TextStyle(color: AppColors.neutral, fontSize: 10, fontWeight: FontWeight.w600)));
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(value.toInt().toString(), style: const TextStyle(color: AppColors.neutral, fontSize: 11, fontWeight: FontWeight.w600));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: AppColors.neutral.withOpacity(0.1), strokeWidth: 1)),
                  borderData: FlBorderData(show: false), barGroups: barGroups,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection(int hot, int warm, int cold, int join, int closed) {
    int totalData = hot + warm + cold + join + closed;
    
    final colorHot = const Color(0xFFEF4444);
    final colorWarm = AppColors.secondary;
    final colorCold = AppColors.primary;
    final colorJoin = AppColors.tertiary;
    final colorClosed = AppColors.neutral;

    List<PieChartSectionData> pieSections = [];
    if (totalData == 0) {
      pieSections.add(PieChartSectionData(value: 1, color: AppColors.neutral.withOpacity(0.2), showTitle: false, radius: 40));
    } else {
      if (hot > 0) pieSections.add(_buildPieSection(hot, totalData, colorHot, 'Hot'));
      if (warm > 0) pieSections.add(_buildPieSection(warm, totalData, colorWarm, 'Warm'));
      if (cold > 0) pieSections.add(_buildPieSection(cold, totalData, colorCold, 'Cold'));
      if (join > 0) pieSections.add(_buildPieSection(join, totalData, colorJoin, 'Join'));
      if (closed > 0) pieSections.add(_buildPieSection(closed, totalData, colorClosed, 'Closed'));
    }

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.neutral.withOpacity(0.15), width: 1.5), boxShadow: [BoxShadow(color: AppColors.neutral.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Distribusi Status Prospek', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(width: 140, height: 140, child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 35, sections: pieSections))),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegend('Hot', hot, colorHot), _buildLegend('Warm', warm, colorWarm), _buildLegend('Cold', cold, colorCold), _buildLegend('Join', join, colorJoin), _buildLegend('Closed', closed, colorClosed),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _buildPieSection(int value, int total, Color color, String title) {
    final double percentage = (value / total) * 100;
    return PieChartSectionData(color: color, value: value.toDouble(), title: '${percentage.toStringAsFixed(0)}%', radius: 45, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white));
  }

  Widget _buildLegend(String label, int count, Color color) {
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutral)), const Spacer(), Text(count.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary))]));
  }
}
// ==========================================
// WIDGET TAB: PROFILE
// ==========================================
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();
 
  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }
 
  // Fungsi untuk memetakan singkatan role menjadi nama lengkap
  String _getRoleName(String? roleCode) {
    if (roleCode == 'MC') {
      return 'Manager Consultant';
    } else if (roleCode == 'BC') {
      return 'Business Consultant';
    }
    // Jika data role kosong atau tidak cocok, gunakan default
    return roleCode ?? 'Karyawan Bestprofit'; 
  }
 
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sesi pengguna tidak valid'));
    }
 
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Profil Saya',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.logout, color: Colors.white),
        //     onPressed: () => _logout(context),
        //     tooltip: 'Keluar',
        //   ),
        // ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Terjadi kesalahan saat memuat profil',
                    style: TextStyle(color: AppColors.neutral)));
          }
 
          String name     = 'Nama tidak ditemukan';
          String roleCode = '';
          String phone    = '';
 
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            name     = data['name'] ?? data['fullName'] ?? 'Nama tidak tersedia';
            roleCode = data['role'] ?? '';
            phone    = data['phone'] ?? '';
          }
 
          final roleText  = _getRoleName(roleCode);
          final isMC      = roleCode == 'MC';
          final roleColor = isMC
              ? AppColors.primary
              : roleCode == 'SBC'
                  ? AppColors.secondary
                  : AppColors.tertiary;
 
          final initials = name.trim().isNotEmpty
              ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
              : '?';
 
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                // ── Avatar ─────────────────────────────────────────────────
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [roleColor, roleColor.withOpacity(0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: roleColor.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Center(
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 18),
 
                Text(name,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(user.email ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.neutral)),
                const SizedBox(height: 12),
 
                // ── Role badge ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: roleColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.work_outline, size: 15, color: roleColor),
                      const SizedBox(width: 7),
                      Text(roleText,
                          style: TextStyle(
                              color: roleColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
 
                // ── Info cards ───────────────────────────────────────────────
                _infoTile(Icons.phone_outlined, 'Nomor Telepon',
                    phone.isNotEmpty ? phone : '-'),
                const SizedBox(height: 10),
                _infoTile(Icons.email_outlined, 'Email', user.email ?? '-'),
                const SizedBox(height: 32),
 
                // ── Menu khusus MC: Manajemen Akun ───────────────────────────
                if (isMC) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('MENU MANAGER',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.neutral,
                            letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: 12),
                  _menuTile(
                    context,
                    icon: Icons.manage_accounts_outlined,
                    label: 'Manajemen Akun',
                    subtitle: 'Kelola akun MC, SBC, dan BC',
                    color: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AccountManagementScreen()),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
 
                // ── Tombol Logout ────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout,
                        color: Color(0xFFEF4444), size: 20),
                    label: const Text('Keluar',
                        style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFEF4444), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
 
  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.neutral),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.neutral,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _menuTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: color.withOpacity(0.1),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.neutral, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.neutral, size: 20),
          ],
        ),
      ),
    );
  }
}