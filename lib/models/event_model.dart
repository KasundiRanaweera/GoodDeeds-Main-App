import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_parsers.dart';
import 'post_model.dart';
import 'user_model.dart';

class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.category,
    required this.impactPoints,
    this.eventDate,
    this.imageUrl = '',
    this.organizerName = '',
    this.organizerContactNumber = '',
    this.createdByUid = '',
    this.createdByName = '',
    this.participantsCount = 0,
    this.participantIds = const [],
    this.checkedInIds = const [],
    this.awardedParticipantIds = const [],
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String location;
  final String category;
  final int impactPoints;
  final DateTime? eventDate;
  final String imageUrl;
  final String organizerName;
  final String organizerContactNumber;
  final String createdByUid;
  final String createdByName;
  final int participantsCount;
  final List<String> participantIds;
  final List<String> checkedInIds;
  final List<String> awardedParticipantIds;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCompleted {
    if (status.toLowerCase() == 'completed') return true;
    if (eventDate == null) return false;
    return DateTime.now().isAfter(eventDate!);
  }

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    String? category,
    int? impactPoints,
    DateTime? eventDate,
    String? imageUrl,
    String? organizerName,
    String? organizerContactNumber,
    String? createdByUid,
    String? createdByName,
    int? participantsCount,
    List<String>? participantIds,
    List<String>? checkedInIds,
    List<String>? awardedParticipantIds,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      category: category ?? this.category,
      impactPoints: impactPoints ?? this.impactPoints,
      eventDate: eventDate ?? this.eventDate,
      imageUrl: imageUrl ?? this.imageUrl,
      organizerName: organizerName ?? this.organizerName,
      organizerContactNumber:
          organizerContactNumber ?? this.organizerContactNumber,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      participantsCount: participantsCount ?? this.participantsCount,
      participantIds: participantIds ?? this.participantIds,
      checkedInIds: checkedInIds ?? this.checkedInIds,
      awardedParticipantIds:
          awardedParticipantIds ?? this.awardedParticipantIds,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'category': category,
      'impactPoints': impactPoints,
      'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate!),
      'imageUrl': imageUrl,
      'organizerName': organizerName,
      'organizerContactNumber': organizerContactNumber,
      'contactNumber': organizerContactNumber,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'participantsCount': participantsCount,
      'participantIds': participantIds,
      'checkedInIds': checkedInIds,
      'awardedParticipantIds': awardedParticipantIds,
      'status': status,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map, {required String id}) {
    return EventModel(
      id: id,
      title: ModelParsers.parseString(
        map['title'] ?? map['eventName'] ?? map['name'],
        fallback: 'Untitled Event',
      ),
      description: ModelParsers.parseString(
        map['description'] ?? map['details'] ?? map['about'],
      ),
      location: ModelParsers.parseString(
        map['location'] ?? map['venue'] ?? map['address'],
      ),
      category: ModelParsers.parseString(
        map['category'] ?? map['type'] ?? map['eventCategory'],
      ),
      impactPoints: ModelParsers.parseInt(
        map['impactPoints'] ?? map['points'] ?? map['rewardPoints'],
      ),
      eventDate: ModelParsers.parseDate(
        map['eventDate'] ?? map['date'] ?? map['startDate'],
      ),
      imageUrl: ModelParsers.parseString(
        map['imageUrl'] ?? map['bannerUrl'] ?? map['photoUrl'],
      ),
      organizerName: ModelParsers.parseString(
        map['organizerName'] ?? map['createdByName'],
      ),
      organizerContactNumber: ModelParsers.parseString(
        map['organizerContactNumber'] ?? map['contactNumber'] ?? map['phone'],
      ),
      createdByUid: ModelParsers.parseString(
        map['createdByUid'] ??
            map['organizerId'] ??
            map['userId'] ??
            map['ownerId'],
      ),
      createdByName: ModelParsers.parseString(
        map['createdByName'] ?? map['organizerName'],
      ),
      participantsCount: ModelParsers.parseInt(
        map['participantsCount'] ??
            map['participantCount'] ??
            map['joinedCount'],
      ),
      participantIds: ModelParsers.parseStringList(map['participantIds']),
      checkedInIds: ModelParsers.parseStringList(map['checkedInIds']),
      awardedParticipantIds: ModelParsers.parseStringList(
        map['awardedParticipantIds'],
      ),
      status: ModelParsers.parseString(map['status'], fallback: 'active'),
      createdAt: ModelParsers.parseDate(map['createdAt']),
      updatedAt: ModelParsers.parseDate(map['updatedAt']),
    );
  }

  factory EventModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return EventModel.fromMap(data, id: doc.id);
  }
}

class EventEngagementModel {
  const EventEngagementModel({required this.event, this.likes = const []});

  final EventModel event;
  final List<LikeModel> likes;

  int get likeCount => likes.length;

  EventEngagementModel copyWith({EventModel? event, List<LikeModel>? likes}) {
    return EventEngagementModel(
      event: event ?? this.event,
      likes: likes ?? this.likes,
    );
  }
}

class EventRosterModel {
  const EventRosterModel({
    required this.event,
    this.organizer,
    this.participants = const [],
  });

  final EventModel event;
  final UserAggregateModel? organizer;
  final List<UserAggregateModel> participants;

  int get participantCount => participants.length;

  EventRosterModel copyWith({
    EventModel? event,
    UserAggregateModel? organizer,
    List<UserAggregateModel>? participants,
  }) {
    return EventRosterModel(
      event: event ?? this.event,
      organizer: organizer ?? this.organizer,
      participants: participants ?? this.participants,
    );
  }
}
