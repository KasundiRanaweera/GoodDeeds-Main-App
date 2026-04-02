import 'package:flutter/material.dart';

class SafeAvatar extends StatelessWidget {
  const SafeAvatar({
    super.key,
    required this.radius,
    required this.imageUrl,
    required this.backgroundColor,
    required this.iconColor,
    this.iconSize,
  });

  final double radius;
  final String? imageUrl;
  final Color backgroundColor;
  final Color iconColor;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      onForegroundImageError: (exception, stackTrace) {},
      child: Icon(Icons.person, size: iconSize ?? radius, color: iconColor),
    );
  }
}
