class ClientModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String profession;
  final String prospectStatus;
  final String brokerName;
  final String brokerUid;

  /// Bukti transfer disimpan sebagai base64 string langsung di Firestore
  /// (tanpa Firebase Storage agar tetap gratis). Gambar di-compress dulu
  /// di sisi klien sebelum di-encode agar ukurannya kecil.
  final String buktiTransferBase64;

  ClientModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.profession,
    required this.prospectStatus,
    required this.brokerName,
    required this.brokerUid,
    this.buktiTransferBase64 = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'profession': profession,
      'prospectStatus': prospectStatus,
      'brokerName': brokerName,
      'brokerUid': brokerUid,
      'buktiTransferBase64': buktiTransferBase64,
      // Field ini ditambahkan manual di AddClientScreen untuk timestamp
      // 'createdAt': FieldValue.serverTimestamp(), 
    };
  }

  factory ClientModel.fromMap(Map<String, dynamic> map, String docId) {
    return ClientModel(
      id: docId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      profession: map['profession'] ?? '',
      prospectStatus: map['prospectStatus'] ?? 'Cold',
      brokerName: map['brokerName'] ?? '',
      brokerUid: map['brokerUid'] ?? '',
      buktiTransferBase64: map['buktiTransferBase64'] ?? '',
    );
  }

  ClientModel copyWith({
    String? prospectStatus,
    String? buktiTransferBase64,
  }) {
    return ClientModel(
      id: id,
      name: name,
      phone: phone,
      address: address,
      profession: profession,
      prospectStatus: prospectStatus ?? this.prospectStatus,
      brokerName: brokerName,
      brokerUid: brokerUid,
      buktiTransferBase64: buktiTransferBase64 ?? this.buktiTransferBase64,
    );
  }
}