import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_screen.dart';

void main() async {
  // Wajib dipanggil sebelum inisialisasi Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi koneksi ke Firebase backend
  await Firebase.initializeApp();
  
  runApp(const MobileCRMApp());
}

class MobileCRMApp extends StatelessWidget {
  const MobileCRMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BPF Mobile CRM',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const LoginScreen(), // Mengarah ke halaman login pertama kali
      debugShowCheckedModeBanner: false,
    );
  }
}