import 'package:flutter/widgets.dart';

import 'screen_privacy.dart';

/// Blocks screenshots and screen recording while [child] is on screen. See
/// [ScreenPrivacy] for what each platform does.
class NoScreenshots extends StatefulWidget {
  const NoScreenshots({super.key, required this.child});

  final Widget child;

  @override
  State<NoScreenshots> createState() => _NoScreenshotsState();
}

class _NoScreenshotsState extends State<NoScreenshots> {
  @override
  void initState() {
    super.initState();
    ScreenPrivacy.hold();
  }

  @override
  void dispose() {
    ScreenPrivacy.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
