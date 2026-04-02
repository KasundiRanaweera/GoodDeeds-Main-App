import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/user/comments_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);

String _toText(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

DateTime? _toDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  try {
    final dynamic date = value?.toDate();
    if (date is DateTime) return date;
  } catch (_) {}
  return null;
}

String _nameInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'U';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _timeAgo(DateTime? date) {
  if (date == null) return 'Just now';
  final diff = DateTime.now().difference(date);
  if (diff.inDays >= 7) {
    final weeks = (diff.inDays / 7).floor();
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  }
  if (diff.inDays > 0) {
    return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
  }
  if (diff.inHours > 0) {
    return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
  }
  if (diff.inMinutes > 0) {
    return diff.inMinutes == 1
        ? '1 minute ago'
        : '${diff.inMinutes} minutes ago';
  }
  return 'Just now';
}

class SocialPostCard extends StatelessWidget {
  const SocialPostCard({
    super.key,
    required this.postId,
    required this.postData,
    required this.isDark,
  });

  final String postId;
  final Map<String, dynamic> postData;
  final bool isDark;

  Future<void> _toggleLike(
    BuildContext context,
    String currentUid,
    bool hasLiked,
  ) async {
    if (currentUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like posts.')),
      );
      return;
    }
    if (postId.isEmpty) return;

    final likeRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(currentUid);

    try {
      if (hasLiked) {
        await likeRef.delete();
      } else {
        await likeRef.set({
          'uid': currentUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update like right now.')),
      );
    }
  }

  Future<List<Map<String, String>>> _loadUsers(List<String> uids) async {
    if (uids.isEmpty) return const [];

    final users = <Map<String, String>>[];
    for (var index = 0; index < uids.length; index += 10) {
      final end = (index + 10 < uids.length) ? index + 10 : uids.length;
      final batch = uids.sublist(index, end);
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        users.add({
          'uid': doc.id,
          'name': _toText(
            data['name'] ?? data['displayName'] ?? data['fullName'],
            fallback: 'Community Member',
          ),
          'photoUrl': _toText(data['photoUrl'] ?? data['avatarUrl']),
        });
      }
    }

    final byUid = {for (final user in users) user['uid']!: user};
    return [
      for (final uid in uids)
        byUid[uid] ?? {'uid': uid, 'name': 'Community Member', 'photoUrl': ''},
    ];
  }

  Future<void> _showLikesSheet(
    BuildContext context,
    List<String> likerIds,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              12 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Liked by',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (likerIds.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'No likes yet.',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    FutureBuilder<List<Map<String, String>>>(
                      future: _loadUsers(likerIds),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final users = snapshot.data ?? const [];
                        if (users.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'No likes yet.',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }

                        return Expanded(
                          child: ListView.separated(
                            itemCount: users.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final name = user['name'] ?? 'Community Member';
                              final photoUrl = user['photoUrl'] ?? '';

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: _kPrimaryColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  backgroundImage: photoUrl.isNotEmpty
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl.isEmpty
                                      ? Text(
                                          _nameInitials(name),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCommentsSheet(BuildContext context) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment.')),
      );
      return;
    }

    var commenterName = 'Community Member';
    var commenterPhotoUrl = '';

    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final currentUserData =
          currentUserDoc.data() ?? const <String, dynamic>{};
      commenterName = _toText(
        currentUserData['name'] ??
            currentUserData['displayName'] ??
            currentUserData['fullName'],
        fallback: 'Community Member',
      );
      commenterPhotoUrl = _toText(
        currentUserData['photoUrl'] ?? currentUserData['avatarUrl'],
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Unable to load profile details. Using fallback.'),
          ),
        );
      }
    }

    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CommentsScreen(
          postId: postId,
          isDark: isDark,
          currentUserId: currentUserId,
          commenterName: commenterName,
          commenterPhotoUrl: commenterPhotoUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final imageUrl = _toText(postData['imageUrl'] ?? postData['photoUrl']);
    final description = _toText(
      postData['description'] ?? postData['text'] ?? postData['caption'],
    );
    final authorName = _toText(
      postData['authorName'] ??
          postData['name'] ??
          postData['displayName'] ??
          postData['fullName'],
      fallback: 'Community Member',
    );
    final authorPhotoUrl = _toText(
      postData['authorPhotoUrl'] ??
          postData['photoUrl'] ??
          postData['avatarUrl'],
    );
    final authorBio = _toText(
      postData['authorBio'] ?? postData['bio'] ?? postData['about'],
    );
    final createdAt = _toDate(postData['createdAt']);

    final likeStream = postId.isEmpty
        ? FirebaseFirestore.instance
              .collection('posts')
              .where(FieldPath.documentId, isEqualTo: '__none__')
              .snapshots()
        : FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .collection('likes')
              .snapshots();

    final commentStream = postId.isEmpty
        ? FirebaseFirestore.instance
              .collection('posts')
              .where(FieldPath.documentId, isEqualTo: '__none__')
              .snapshots()
        : FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: likeStream,
      builder: (context, likesSnapshot) {
        final likerIds = (likesSnapshot.data?.docs ?? const [])
            .map((doc) => doc.id)
            .toList();
        final hasLiked =
            currentUserId.isNotEmpty && likerIds.contains(currentUserId);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: commentStream,
          builder: (context, commentsSnapshot) {
            final commentCount = commentsSnapshot.data?.docs.length ?? 0;

            return Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _kPrimaryColor.withValues(
                            alpha: 0.18,
                          ),
                          backgroundImage: authorPhotoUrl.isNotEmpty
                              ? NetworkImage(authorPhotoUrl)
                              : null,
                          child: authorPhotoUrl.isEmpty
                              ? Text(
                                  _nameInitials(authorName),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authorName,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (authorBio.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  authorBio,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade700,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 3),
                              Text(
                                _timeAgo(createdAt),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stackTrace) {
                              return Container(
                                color: isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey,
                                    size: 36,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        description,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _toggleLike(context, currentUserId, hasLiked),
                          icon: Icon(
                            hasLiked ? Icons.favorite : Icons.favorite_border,
                            color: hasLiked
                                ? const Color(0xFFFF3B5C)
                                : (isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700),
                          ),
                        ),
                        InkWell(
                          onTap: () => _showLikesSheet(context, likerIds),
                          child: Text(
                            '${likerIds.length} ${likerIds.length == 1 ? 'Like' : 'Likes'}',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showCommentsSheet(context),
                          icon: Icon(
                            Icons.mode_comment_outlined,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '$commentCount ${commentCount == 1 ? 'Comment' : 'Comments'}',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
