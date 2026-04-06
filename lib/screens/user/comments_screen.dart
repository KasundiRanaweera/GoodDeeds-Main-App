import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

class CommentsScreen extends StatefulWidget {
  const CommentsScreen({
    super.key,
    required this.postId,
    required this.isDark,
    required this.currentUserId,
    required this.commenterName,
    required this.commenterPhotoUrl,
  });

  final String postId;
  final bool isDark;
  final String currentUserId;
  final String commenterName;
  final String commenterPhotoUrl;

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();

  DocumentReference<Map<String, dynamic>> get _postRef =>
      FirebaseFirestore.instance.collection('posts').doc(widget.postId);

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      _postRef.collection('comments');

  void _showCommentSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _deleteComment(String commentId) async {
    if (widget.postId.isEmpty || commentId.isEmpty) return;

    try {
      await _commentsRef.doc(commentId).delete();
      await _postRef.set({
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _showCommentSnackBar('Comment deleted successfully.');
    } catch (_) {}
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      final commentRef = _commentsRef.doc();
      await commentRef.set({
        'commentId': commentRef.id,
        'uid': widget.currentUserId,
        'authorName': widget.commenterName,
        'authorPhotoUrl': widget.commenterPhotoUrl,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _postRef.set({
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _commentController.clear();
      _showCommentSnackBar('Comment added successfully.');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text(
          'Comments',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _commentsRef
                    .orderBy('createdAt', descending: true)
                    .limit(80)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load comments right now.',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final comments = snapshot.data?.docs ?? const [];
                  if (comments.isEmpty) {
                    return Center(
                      child: Text(
                        'No comments yet. Be the first to comment.',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: comments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final commentDoc = comments[index];
                      final commentData = commentDoc.data();
                      final commentId = commentDoc.id;
                      final commenterUid = _toText(commentData['uid']);
                      final commentText = _toText(
                        commentData['text'] ?? commentData['comment'],
                      );
                      final commentedAt = _toDate(commentData['createdAt']);
                      final commenterName = _toText(
                        commentData['authorName'],
                        fallback: 'Community Member',
                      );
                      final commenterPhoto = _toText(
                        commentData['authorPhotoUrl'],
                      );

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: _kPrimaryColor.withValues(
                                alpha: 0.2,
                              ),
                              backgroundImage: commenterPhoto.isNotEmpty
                                  ? NetworkImage(commenterPhoto)
                                  : null,
                              child: commenterPhoto.isEmpty
                                  ? Text(
                                      _nameInitials(commenterName),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                        fontSize: 11,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          commentText,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (commenterUid == widget.currentUserId)
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'Delete comment',
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: isDark
                                                ? Colors.redAccent
                                                : Colors.red.shade600,
                                          ),
                                          onPressed: () async {
                                            final shouldDelete =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (dialogContext) {
                                                    return AlertDialog(
                                                      title: const Text(
                                                        'Delete comment?',
                                                      ),
                                                      content: const Text(
                                                        'This comment will be permanently removed.',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(false),
                                                          child: const Text(
                                                            'Cancel',
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(true),
                                                          child: const Text(
                                                            'Delete',
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );

                                            if (shouldDelete != true) return;
                                            await _deleteComment(commentId);
                                          },
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _timeAgo(commentedAt),
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
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _submitComment,
                    style: IconButton.styleFrom(
                      backgroundColor: _kPrimaryColor,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}