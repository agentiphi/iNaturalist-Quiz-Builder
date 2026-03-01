import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class PhotoViewer extends StatefulWidget {
  final String photoUrl;
  final List<String> allPhotoUrls;
  final bool showSwipeHints;

  const PhotoViewer({
    super.key,
    required this.photoUrl,
    this.allPhotoUrls = const [],
    this.showSwipeHints = false,
  });

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pageController;
  int _currentPage = 0;

  List<String> get _urls =>
      widget.allPhotoUrls.isNotEmpty ? widget.allPhotoUrls : [widget.photoUrl];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant PhotoViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenGallery(
          photoUrls: _urls,
          initialPage: _currentPage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    final hasMultiple = urls.length > 1;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasMultiple)
            PageView.builder(
              controller: _pageController,
              itemCount: urls.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) => GestureDetector(
                onTap: _openFullscreen,
                child: _PhotoImage(url: urls[index]),
              ),
            )
          else
            GestureDetector(
              onTap: _openFullscreen,
              child: _PhotoImage(url: urls.first),
            ),
          // Dot indicators
          if (hasMultiple)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(urls.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentPage
                          ? Colors.white
                          : Colors.white54,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          // Fullscreen hint icon
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.fullscreen,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoImage extends StatelessWidget {
  final String url;

  const _PhotoImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(color: Colors.white),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.shade200,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Photo unavailable', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _FullscreenGallery extends StatefulWidget {
  final List<String> photoUrls;
  final int initialPage;

  const _FullscreenGallery({
    required this.photoUrls,
    this.initialPage = 0,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: widget.photoUrls.length > 1
            ? Text('${_currentPage + 1} / ${widget.photoUrls.length}')
            : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photoUrls.length,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemBuilder: (context, index) {
          final url =
              widget.photoUrls[index].replaceFirst('/medium.', '/large.');
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child:
                      Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
