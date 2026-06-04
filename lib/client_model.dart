class ClientModel {
  String id;
  String name;
  String phone;
  String address;
  String profession;
  String idNumber; // KTP/SIM/Paspor
  String prospectStatus; // Hot, Warm, Cold, Closed, Join
  
  ClientModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.profession,
    required this.idNumber,
    required this.prospectStatus,
  });

  // Mapping dari Firebase Firestore ke Object Dart
  factory ClientModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ClientModel(
      id: documentId,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      profession: data['profession'] ?? '',
      idNumber: data['idNumber'] ?? '',
      prospectStatus: data['prospectStatus'] ?? 'Cold',
    );
  }

  // Mapping Object Dart ke Firebase Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'profession': profession,
      'idNumber': idNumber,
      'prospectStatus': prospectStatus,
    };
  }
}