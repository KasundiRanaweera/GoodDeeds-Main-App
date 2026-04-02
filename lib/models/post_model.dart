import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_parsers.dart';

class PostModel {
  const PostModel({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.description,
    required this.imageUrl,
    this.authorBio = '',
    this.authorPhotoUrl = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String authorBio;
  final String authorPhotoUrl;
  final String description;
  final String imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PostModel copyWith({
    String? id,
    String? authorUid,
    String? authorName,
    String? authorBio,
    String? authorPhotoUrl,
    String? description,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorUid: authorUid ?? this.authorUid,
      authorName: authorName ?? this.authorName,
      authorBio: authorBio ?? this.authorBio,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': id,
      'authorUid': authorUid,
      'authorName': authorName,
      'authorBio': authorBio,
      'authorPhotoUrl': authorPhotoUrl,
      'description': description,
      'imageUrl': imageUrl,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map, {required String id}) {
    return PostModel(
      id: ModelParsers.parseString(map['postId'], fallback: id),
      authorUid: ModelParsers.parseString(map['authorUid'] ?? map['uid']),
      authorName: ModelParsers.parseString(
        map['authorName'] ??
            map['name'] ??
            map['displayName'] ??
            map['fullName'],
        fallback: 'Community Member',
      ),
      authorBio: ModelParsers.parseString(
        map['authorBio'] ?? map['bio'] ?? map['about'],
      ),
      authorPhotoUrl: ModelParsers.parseString(
        map['authorPhotoUrl'] ?? map['photoUrl'] ?? map['avatarUrl'],
      ),
      description: ModelParsers.parseString(
        map['description'] ?? map['text'] ?? map['caption'],
      ),
      imageUrl: ModelParsers.parseString(map['imageUrl'] ?? map['photoUrl']),
      createdAt: ModelParsers.parseDate(map['createdAt']),
      updatedAt: ModelParsers.parseDate(map['updatedAt']),
    );
  }

  factory PostModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PostModel.fromMap(data, id: doc.id);
  }
}

class LikeModel {
  const LikeModel({required this.uid, this.createdAt});

  final String uid;
  final DateTime? createdAt;

  LikeModel copyWith({String? uid, DateTime? createdAt}) {
    return LikeModel(
      uid: uid ?? this.uid,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    };
  }

  factory LikeModel.fromMap(Map<String, dynamic> map, {required String uid}) {
    return LikeModel(
      uid: ModelParsers.parseString(map['uid'], fallback: uid),
      createdAt: ModelParsers.parseDate(map['createdAt']),
    );
  }

  factory LikeModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return LikeModel.fromMap(data, uid: doc.id);
  }
}

class CommentModel {
  const CommentModel({
    required this.id,
    required this.postId,
    required this.uid,
    required this.authorName,
    required this.text,
    this.authorPhotoUrl = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String postId;
  final String uid;
  final String authorName;
  final String authorPhotoUrl;
  final String text;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CommentModel copyWith({
    String? id,
    String? postId,
    String? uid,
    String? authorName,
    String? authorPhotoUrl,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      uid: uid ?? this.uid,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': id,
      'postId': postId,
      'uid': uid,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  factory CommentModel.fromMap(
    Map<String, dynamic> map, {
    required String id,
    required String postId,
  }) {
    return CommentModel(
      id: ModelParsers.parseString(map['commentId'], fallback: id),
      postId: ModelParsers.parseString(map['postId'], fallback: postId),
      uid: ModelParsers.parseString(map['uid'] ?? map['commenterUid']),
      authorName: ModelParsers.parseString(
        map['authorName'] ?? map['commenterName'],
        fallback: 'Community Member',
      ),
      authorPhotoUrl: ModelParsers.parseString(
        map['authorPhotoUrl'] ?? map['commenterPhotoUrl'],
      ),
      text: ModelParsers.parseString(map['text'] ?? map['comment']),
      createdAt: ModelParsers.parseDate(map['createdAt']),
      updatedAt: ModelParsers.parseDate(map['updatedAt']),
    );
  }

  factory CommentModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String postId,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    return CommentModel.fromMap(data, id: doc.id, postId: postId);
  }
}

class PostThreadModel {
  const PostThreadModel({
    required this.post,
    this.comments = const [],
    this.likes = const [],
  });

  final PostModel post;
  final List<CommentModel> comments;
  final List<LikeModel> likes;

  int get commentCount => comments.length;
  int get likeCount => likes.length;

  PostThreadModel copyWith({
    PostModel? post,
    List<CommentModel>? comments,
    List<LikeModel>? likes,
  }) {
    return PostThreadModel(
      post: post ?? this.post,
      comments: comments ?? this.comments,
      likes: likes ?? this.likes,
    );
  }
}
