class ClientModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String profession;
  final String prospectStatus;
  final String brokerName;
  final String brokerUid;

  ClientModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.profession,
    required this.prospectStatus,
    required this.brokerName,
    required this.brokerUid,
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
    );
  }
}