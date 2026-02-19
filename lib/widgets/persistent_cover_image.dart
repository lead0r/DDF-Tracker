import 'package:flutter/material.dart';

import '../services/cover_storage/cover_image_loader.dart';

class PersistentCoverImage extends StatefulWidget {
  const PersistentCoverImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorIconColor,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadiusGeometry? borderRadius;
  final Color? errorIconColor;

  @override
  State<PersistentCoverImage> createState() => _PersistentCoverImageState();
}

class _PersistentCoverImageState extends State<PersistentCoverImage> {
  late Future<ImageProvider?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = loadPersistentCover(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant PersistentCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageFuture = loadPersistentCover(widget.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<ImageProvider?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholder();
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _buildErrorWidget();
        }

        return Image(
          image: snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      },
    );

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: content,
      );
    }
    return content;
  }

  Widget _buildPlaceholder() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Icon(
        Icons.broken_image,
        color: widget.errorIconColor,
      ),
    );
  }
}
