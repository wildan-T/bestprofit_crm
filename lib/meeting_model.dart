import 'package:cloud_firestore/cloud_firestore.dart';

/// Status lifecycle sebuah jadwal meeting
enum MeetingStatus {
  pending,   // Baru dibuat oleh BC, menunggu konfirmasi MC
  confirmed, // MC telah approve / konfirmasi meeting akan berlangsung
  done,      // MC menandai meeting sudah selesai / terlaksana
  cancelled, // MC membatalkan meeting
}

extension MeetingStatusX on MeetingStatus {
  String get label {
    switch (this) {
      case MeetingStatus.pending:   return 'Menunggu Konfirmasi';
      case MeetingStatus.confirmed: return 'Dikonfirmasi';
      case MeetingStatus.done:      return 'Selesai';
      case MeetingStatus.cancelled: return 'Dibatalkan';
    }
  }

  String get value {
    switch (this) {
      case MeetingStatus.pending:   return 'pending';
      case MeetingStatus.confirmed: return 'confirmed';
      case MeetingStatus.done:      return 'done';
      case MeetingStatus.cancelled: return 'cancelled';
    }
  }

  static MeetingStatus fromString(String? s) {
    switch (s) {
      case 'confirmed': return MeetingStatus.confirmed;
      case 'done':      return MeetingStatus.done;
      case 'cancelled': return MeetingStatus.cancelled;
      default:          return MeetingStatus.pending;
    }
  }
}

class MeetingModel {
  final String id;
  final String clientName;
  final String location;
  final String notes;
  final DateTime dateTime;
  final int reminderMinutes;

  // Broker / BC yang membuat jadwal
  final String brokerUid;
  final String brokerName;

  // MC yang mengkonfirmasi / mengelola
  final String mcUid;
  final String mcName;

  // Cover broker (ditugaskan MC jika broker utama berhalangan)
  final String coverBrokerUid;
  final String coverBrokerName;

  // Status lifecycle
  final MeetingStatus status;

  // Catatan dari MC saat acc/cancel
  final String mcNotes;

  MeetingModel({
    required this.id,
    required this.clientName,
    required this.location,
    required this.notes,
    required this.dateTime,
    required this.reminderMinutes,
    required this.brokerUid,
    required this.brokerName,
    this.mcUid = '',
    this.mcName = '',
    this.coverBrokerUid = '',
    this.coverBrokerName = '',
    this.status = MeetingStatus.pending,
    this.mcNotes = '',
  });

  /// ID int unik untuk flutter_local_notifications
  int get notificationId => id.hashCode & 0x7FFFFFFF;

  Map<String, dynamic> toMap() {
    return {
      'clientName': clientName,
      'location': location,
      'notes': notes,
      'dateTime': Timestamp.fromDate(dateTime),
      'reminderMinutes': reminderMinutes,
      'brokerUid': brokerUid,
      'brokerName': brokerName,
      'mcUid': mcUid,
      'mcName': mcName,
      'coverBrokerUid': coverBrokerUid,
      'coverBrokerName': coverBrokerName,
      'status': status.value,
      'mcNotes': mcNotes,
    };
  }

  factory MeetingModel.fromMap(Map<String, dynamic> map, String docId) {
    return MeetingModel(
      id: docId,
      clientName: map['clientName'] ?? '',
      location: map['location'] ?? '',
      notes: map['notes'] ?? '',
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      reminderMinutes: map['reminderMinutes'] ?? 30,
      brokerUid: map['brokerUid'] ?? '',
      brokerName: map['brokerName'] ?? '',
      mcUid: map['mcUid'] ?? '',
      mcName: map['mcName'] ?? '',
      coverBrokerUid: map['coverBrokerUid'] ?? '',
      coverBrokerName: map['coverBrokerName'] ?? '',
      status: MeetingStatusX.fromString(map['status']),
      mcNotes: map['mcNotes'] ?? '',
    );
  }

  MeetingModel copyWith({
    String? mcUid,
    String? mcName,
    String? coverBrokerUid,
    String? coverBrokerName,
    MeetingStatus? status,
    String? mcNotes,
  }) {
    return MeetingModel(
      id: id,
      clientName: clientName,
      location: location,
      notes: notes,
      dateTime: dateTime,
      reminderMinutes: reminderMinutes,
      brokerUid: brokerUid,
      brokerName: brokerName,
      mcUid: mcUid ?? this.mcUid,
      mcName: mcName ?? this.mcName,
      coverBrokerUid: coverBrokerUid ?? this.coverBrokerUid,
      coverBrokerName: coverBrokerName ?? this.coverBrokerName,
      status: status ?? this.status,
      mcNotes: mcNotes ?? this.mcNotes,
    );
  }
}