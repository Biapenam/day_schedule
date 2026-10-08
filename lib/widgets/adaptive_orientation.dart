import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../utils/responsive.dart';

/// Android phones stay portrait; tablets follow the system rotation setting.
class AdaptiveOrientation extends StatefulWidget {
  const AdaptiveOrientation({super.key, required this.child});

  final Widget child;

  @override
  State<AdaptiveOrientation> createState() => _AdaptiveOrientationState();
}

class _AdaptiveOrientationState extends State<AdaptiveOrientation>
    with WidgetsBindingObserver {
  ui.FlutterView? _view;
  bool? _portraitLocked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.maybeOf(context);
    _updateOrientation();
  }

  @override
  void didChangeMetrics() => _updateOrientation();

  void _updateOrientation() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final display = _view?.display;
    if (display == null ||
        display.size.isEmpty ||
        !display.size.isFinite ||
        display.devicePixelRatio <= 0 ||
        !display.devicePixelRatio.isFinite) {
      // Do not lock a tablet using incomplete startup metrics. The observer
      // retries when the display becomes ready.
      return;
    }

    // A letterboxed or split-screen app window can be smaller than the device.
    // Use the complete display so a tablet cannot inherit a phone's lock.
    final logicalDisplaySize = display.size / display.devicePixelRatio;
    final lockPortrait =
        logicalDisplaySize.shortestSide < Responsive.tabletBreakpoint;
    if (_portraitLocked == lockPortrait) return;
    _portraitLocked = lockPortrait;
    unawaited(
      SystemChrome.setPreferredOrientations(
        lockPortrait ? [DeviceOrientation.portraitUp] : [],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _view = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
