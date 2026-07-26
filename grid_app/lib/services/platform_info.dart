import 'package:flutter/foundation.dart';

/// Desktop (macOS/Windows/Linux) is the design-first side: template list as
/// home, sync served from here, mouse affordances (visible delete buttons,
/// instant palette drag). Phones/tablets get the fill-first home. Reads
/// [defaultTargetPlatform] so tests can override it.
bool get isDesktopPlatform => switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };
