import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'client_list_screen.dart';
import 'login_screen.dart';
import 'app_colors.dart'; // Import AppColors

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _DashboardTab(),
    const ClientListScreen(),
    const _PlaceholderTab(title: 'Jadwal Meeting', icon: Icons.calendar_month_outlined),
    const _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: AppColors.neutral.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.neutral.withOpacity(0.6),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
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

// ==========================================
// WIDGET TAB: DASHBOARD (HOME)
// ==========================================
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  String _selectedFilter = '7 Hari'; // Default filter
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
                    Container(
                      width: 44, height: 44,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
                      child: const Icon(Icons.show_chart, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getGreeting(), style: const TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                          Text(user?.email?.split('@').first.toUpperCase() ?? 'KARYAWAN', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: const Text('Dashboard CRM', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(height: 20),

              // Konten Utama dengan StreamBuilder
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // Mengambil SEMUA data klien agar bisa diproses untuk berbagai metrik
                  stream: FirebaseFirestore.instance.collection('clients').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Terjadi kesalahan memuat data', style: TextStyle(color: Colors.white)));
                    }

                    final docs = snapshot.data!.docs;
                    
                    // --- Kalkulasi Metrik ---
                    int totalJoin = 0;
                    int joinToday = 0;
                    final now = DateTime.now();
                    final startOfToday = DateTime(now.year, now.month, now.day);

                    // --- Kalkulasi Data Pie Chart ---
                    int hot = 0, warm = 0, cold = 0, closed = 0;

                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['prospectStatus'] ?? '';
                      
                      if (status == 'Join') totalJoin++;
                      if (status == 'Hot') hot++;
                      if (status == 'Warm') warm++;
                      if (status == 'Cold') cold++;
                      if (status == 'Closed') closed++;

                      if (status == 'Join' && data['createdAt'] != null) {
                        final createdAt = (data['createdAt'] as Timestamp).toDate();
                        if (createdAt.isAfter(startOfToday)) joinToday++;
                      }
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // 1. STATS CARD ROW
                        Row(
                          children: [
                            Expanded(child: _buildStatCard('Total Join', totalJoin.toString(), Icons.emoji_events_outlined, AppColors.secondary)),
                            const SizedBox(width: 14),
                            Expanded(child: _buildStatCard('Join Hari Ini', joinToday.toString(), Icons.trending_up, AppColors.tertiary)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 2. BAR CHART: TREN JOIN KLIEN
                        _buildBarChartSection(docs),
                        const SizedBox(height: 24),

                        // 3. PIE CHART: DISTRIBUSI STATUS PROSPEK
                        _buildPieChartSection(hot, warm, cold, totalJoin, closed),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Komponen Kartu Statistik Atas
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

  // Komponen Bar Chart
  Widget _buildBarChartSection(List<QueryDocumentSnapshot> docs) {
    // Menentukan rentang hari berdasarkan filter
    int days = int.parse(_selectedFilter.split(' ')[0]);
    DateTime now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));

    // Inisialisasi map data dengan nilai 0 untuk setiap hari
    Map<String, int> joinData = {};
    for (int i = 0; i < days; i++) {
      DateTime d = startDate.add(Duration(days: i));
      joinData[DateFormat('dd/MM').format(d)] = 0;
    }

    // Mengisi data yang sesuai
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['prospectStatus'] == 'Join' && data['createdAt'] != null) {
        DateTime dt = (data['createdAt'] as Timestamp).toDate();
        if (dt.isAfter(startDate.subtract(const Duration(days: 1)))) {
          String key = DateFormat('dd/MM').format(dt);
          if (joinData.containsKey(key)) {
            joinData[key] = joinData[key]! + 1;
          }
        }
      }
    }

    // Mengkonversi map menjadi BarChartGroupData
    List<BarChartGroupData> barGroups = [];
    int index = 0;
    double maxY = 0;
    joinData.forEach((dateStr, count) {
      if (count > maxY) maxY = count.toDouble();
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: AppColors.primary,
              width: days <= 7 ? 16 : 8,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true, toY: (maxY > 5 ? maxY : 5) + 1, color: AppColors.neutral.withOpacity(0.1),
              ),
            ),
          ],
        ),
      );
      index++;
    });

    List<String> dateLabels = joinData.keys.toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral.withOpacity(0.15), width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.neutral.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tren Klien Join', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
              // Dropdown Filter
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.neutral.withOpacity(0.2))),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 20),
                    style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                    onChanged: (String? newValue) {
                      if (newValue != null) setState(() => _selectedFilter = newValue);
                    },
                    items: _filterOptions.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          // BUNGKUS DENGAN SINGLE CHILD SCROLL VIEW
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              // Lebar dinamis: Tiap 1 hari memakan lebar 35 pixel. 
              // Jika kurang dari lebar layar, pakai lebar maksimal layar.
              width: (days * 35.0) < (MediaQuery.of(context).size.width - 80) 
                  ? MediaQuery.of(context).size.width - 80 
                  : (days * 35.0),
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxY > 5 ? maxY : 5) + 1,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          int idx = value.toInt();
                          if (idx < 0 || idx >= dateLabels.length) return const SizedBox.shrink();
                          
                          // Karena sudah bisa discroll, kita TAMPILKAN SEMUA tanggalnya
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(dateLabels[idx], style: const TextStyle(color: AppColors.neutral, fontSize: 10, fontWeight: FontWeight.w600)),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(value.toInt().toString(), style: const TextStyle(color: AppColors.neutral, fontSize: 11, fontWeight: FontWeight.w600));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true, drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: AppColors.neutral.withOpacity(0.1), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Komponen Pie Chart
  Widget _buildPieChartSection(int hot, int warm, int cold, int join, int closed) {
    int totalData = hot + warm + cold + join + closed;
    
    // Warna yang selaras dengan palet sistem
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
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral.withOpacity(0.15), width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.neutral.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Distribusi Status Prospek', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 140, height: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2, centerSpaceRadius: 35,
                    sections: pieSections,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegend('Hot', hot, colorHot),
                    _buildLegend('Warm', warm, colorWarm),
                    _buildLegend('Cold', cold, colorCold),
                    _buildLegend('Join', join, colorJoin),
                    _buildLegend('Closed', closed, colorClosed),
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
    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      title: '${percentage.toStringAsFixed(0)}%',
      radius: 45,
      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
    );
  }

  Widget _buildLegend(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutral)),
          const Spacer(),
          Text(count.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
        ],
      ),
    );
  }
}

// ==========================================
// WIDGET TAB: PLACEHOLDER & PROFILE
// ==========================================
class _PlaceholderTab extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PlaceholderTab({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.neutral.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const Text('Segera Hadir', style: TextStyle(color: AppColors.neutral)),
        ],
      ),
    );
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
        title: const Text('Profil Saya', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white), 
            onPressed: () => _logout(context),
            tooltip: 'Keluar',
          ),
        ],
      ),
      // Menggunakan StreamBuilder untuk mengambil data real-time menggunakan Document ID
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          // Menampilkan loading indicator saat data sedang diambil
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Terjadi kesalahan saat memuat profil', style: TextStyle(color: AppColors.neutral)));
          }

          // Nilai default jika data tidak ditemukan
          String name = 'Nama tidak ditemukan';
          String roleText = 'Karyawan Bestprofit';

          // Memeriksa apakah dokumen ada di database
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            
            // Mengambil nama (bisa disesuaikan dengan field di Firestore Anda: 'name' atau 'fullName')
            name = data['name'] ?? data['fullName'] ?? 'Nama tidak tersedia';
            
            // Memanggil fungsi untuk menerjemahkan role MC/BC
            roleText = _getRoleName(data['role']); 
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar Pengguna
                Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, 
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.secondary.withOpacity(0.6), width: 3),
                    boxShadow: [
                      BoxShadow(color: AppColors.secondary.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))
                    ]
                  ),
                  child: const Icon(Icons.person, size: 55, color: AppColors.secondary),
                ),
                const SizedBox(height: 24),
                
                // Nama Lengkap dari Firestore
                Text(
                  name, 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)
                ),
                const SizedBox(height: 6),
                
                // Email dari Firebase Auth
                Text(
                  user.email ?? 'Tidak ada email', 
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.neutral)
                ),
                const SizedBox(height: 16),
                
                // Badge Role (MC / BC)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.work_outline, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        roleText, 
                        style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}