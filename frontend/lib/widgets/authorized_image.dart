import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/media_session.dart';

class AuthorizedImage extends StatefulWidget {
  const AuthorizedImage(
    this.url, {
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    super.key,
  });
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  @override
  State<AuthorizedImage> createState() => _AuthorizedImageState();
}

class _AuthorizedImageState extends State<AuthorizedImage> {
  late Future<Uint8List> _bytes;
  @override
  void initState() {
    super.initState();
    MediaSession.revision.addListener(_reload);
    _bytes = _load();
  }

  Future<Uint8List> _load() {
    final future = Future<Uint8List>.sync(
      () => MediaSession.load(Uri.parse(widget.url)),
    );
    // A session change can fail before the next frame attaches FutureBuilder.
    // Observe it now; FutureBuilder still receives the same retry/fallback state.
    future.ignore();
    return future;
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _bytes = _load();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AuthorizedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _bytes = _load();
  }

  @override
  void dispose() {
    MediaSession.revision.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return Image.memory(
          snapshot.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: false,
          errorBuilder: widget.errorBuilder,
        );
      }
      if (snapshot.hasError) {
        return widget.errorBuilder?.call(context, snapshot.error!, null) ??
            SizedBox(
              width: widget.width,
              height: widget.height,
              child: const Center(
                child: Icon(Icons.image_not_supported_outlined),
              ),
            );
      }
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      );
    },
  );
}
