import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_model.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers untuk menangkap input teks
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _professionController = TextEditingController();
  final _idNumberController = TextEditingController();
  
  String _selectedStatus = 'Cold';
  bool _isLoading = false;

  Future<void> _saveClient() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        // Membuat object client baru
        ClientModel newClient = ClientModel(
          id: '', // ID akan di-generate otomatis oleh Firebase
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          profession: _professionController.text.trim(),
          idNumber: _idNumberController.text.trim(),
          prospectStatus: _selectedStatus,
        );

        // Menyimpan ke Firestore
        await FirebaseFirestore.instance
            .collection('clients')
            .add(newClient.toMap());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data klien berhasil disimpan!')),
          );
          Navigator.pop(context); // Kembali ke halaman sebelumnya
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Klien Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Nomor WhatsApp / HP', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Nomor HP tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Alamat Lengkap', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _professionController,
                decoration: const InputDecoration(labelText: 'Profesi / Pekerjaan', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nomor Identitas (KTP/SIM/Paspor)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Status Prospek', border: OutlineInputBorder()),
                items: ['Cold', 'Warm', 'Hot', 'Join', 'Closed'].map((String status) {
                  return DropdownMenuItem(value: status, child: Text(status));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value!;
                  });
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveClient,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SIMPAN DATA', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}