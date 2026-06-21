import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

/// Helper untuk memilih, mengompres, dan mengkonversi gambar menjadi
/// base64 string agar bisa disimpan langsung di dokumen Firestore
/// (tanpa Firebase Storage / tanpa biaya tambahan).
///
/// Batas aman: dokumen Firestore maksimal ~1 MB. Untuk berjaga-jaga,
/// kita kompres hingga base64 di bawah ~700 KB (setara file asli ~500 KB).
class ImageHelper {
  static const int _maxBase64Bytes = 700 * 1024; // ~700 KB
  static const int _initialMaxDimension = 1280; // px, sisi terpanjang
  static const int _minQuality = 30;

  /// Menampilkan pilihan sumber gambar (kamera / galeri), lalu
  /// mengompres dan meng-encode menjadi base64.
  /// Mengembalikan null jika user membatalkan.
  static Future<String?> pickAndEncode(BuildContext context) async {
    final source = await _showSourcePicker(context);
    if (source == null) return null;

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 90, // kompresi awal ringan dari picker
      maxWidth: 1920,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    return _compressToBase64(bytes);
  }

  static Future<ImageSource?> _showSourcePicker(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Unggah Bukti Transfer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  /// Mengompres bytes gambar secara progresif (resize + turunkan quality)
  /// sampai hasil base64 di bawah batas aman, lalu mengembalikan base64 string
  /// dengan prefix data URI agar mudah dirender langsung oleh Image.memory
  /// atau Image.network setelah decode.
  static Future<String> _compressToBase64(Uint8List bytes) async {
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Gagal membaca gambar. Coba file lain.');
    }

    int maxDimension = _initialMaxDimension;
    int quality = 85;
    Uint8List? result;

    // Loop progresif: turunkan ukuran/kualitas sampai cukup kecil,
    // maksimal 6 percobaan agar tidak infinite loop.
    for (int attempt = 0; attempt < 6; attempt++) {
      img.Image resized = decoded;
      if (decoded.width > maxDimension || decoded.height > maxDimension) {
        resized = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxDimension : null,
          height: decoded.height > decoded.width ? maxDimension : null,
        );
      }

      final encoded = img.encodeJpg(resized, quality: quality);
      final b64Length = base64.encode(encoded).length;

      if (b64Length <= _maxBase64Bytes || quality <= _minQuality) {
        result = Uint8List.fromList(encoded);
        break;
      }

      // Perkecil dimensi & quality untuk percobaan berikutnya
      maxDimension = (maxDimension * 0.8).round();
      quality = (quality - 15).clamp(_minQuality, 100);
    }

    result ??= Uint8List.fromList(img.encodeJpg(decoded, quality: _minQuality));

    final b64 = base64.encode(result);
    if (b64.length > _maxBase64Bytes) {
      throw Exception(
          'Ukuran gambar masih terlalu besar setelah dikompres. Coba foto dengan resolusi lebih rendah.');
    }

    return 'data:image/jpeg;base64,$b64';
  }

  /// Mengubah data URI base64 (atau base64 polos) menjadi bytes
  /// untuk ditampilkan via Image.memory.
  static Uint8List? decodeToBytes(String base64String) {
    if (base64String.isEmpty) return null;
    try {
      final raw = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Estimasi ukuran file dalam KB dari base64 string (untuk ditampilkan ke user).
  static double estimateSizeKB(String base64String) {
    if (base64String.isEmpty) return 0;
    final raw = base64String.contains(',')
        ? base64String.split(',').last
        : base64String;
    // base64 menambah ~33% overhead dari ukuran asli
    final bytes = (raw.length * 3) / 4;
    return bytes / 1024;
  }
}