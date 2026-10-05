import 'dart:io';

import 'package:flutter/material.dart';

/// Displays remote artwork URLs and local images selected by the user.
class ArtworkImage extends StatelessWidget {
  const ArtworkImage({
    super.key,
    required this.source,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String source;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final value = source.trim();
    if (value.isEmpty) return fallback;
    final uri = Uri.tryParse(value);
    final ImageProvider provider;
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      provider = NetworkImage(value);
    } else {
      final path = uri?.scheme == 'file' ? uri!.toFilePath() : value;
      provider = FileImage(File(path));
    }
    return Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
