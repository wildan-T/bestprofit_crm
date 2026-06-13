import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingModel {
  final String id;
  final String title;
  final String clientName;
  final String location;
  final String notes;
  final DateTime dateTime;
  final int reminderMinutes; // 0 = tanpa pengingat
  final String createdByUid;
  final String createdByName;
  final bool isDone;

  MeetingModel({
    required this.id,
    required this.title,
    required this.clientName,
    required this.location,
    required this.notes,
    required this.dateTime,
    required this.reminderMinutes,
    required this.createdByUid,
    required this.createdByName,
    this.isDone = false,
  });

  /// ID numerik unik untuk keperluan flutter_local_notifications
  /// (plugin notifikasi mewajibkan id berupa int).
  int get notificationId => id.hashCode & 0x7FFFFFFF;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'clientName': clientName,
      'location': location,
      'notes': notes,
      'dateTime': Timestamp.fromDate(dateTime),
      'reminderMinutes': reminderMinutes,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'isDone': isDone,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory MeetingModel.fromMap(Map<String, dynamic> map, String docId) {
    return MeetingModel(
      id: docId,
      title: map['title'] ?? '',
      clientName: map['clientName'] ?? '',
      location: map['location'] ?? '',
      notes: map['notes'] ?? '',
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      reminderMinutes: map['reminderMinutes'] ?? 30,
      createdByUid: map['createdByUid'] ?? '',
      createdByName: map['createdByName'] ?? '',
      isDone: map['isDone'] ?? false,
    );
  }
}