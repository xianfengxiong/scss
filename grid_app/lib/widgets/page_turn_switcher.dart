import 'package:flutter/material.dart';

/// Animates page changes as a directional slide: the incoming page slides in
/// from the side being turned toward while the outgoing one slides away —
/// so a swipe reads as pushing the page, not swapping it. Rebuild with a new
/// [pageIndex] (and the [direction] of travel) to run the transition.
class PageTurnSwitcher extends StatelessWidget {
  final int pageIndex;

  /// +1 = turning forward (new page enters from the right), -1 = back.
  final int direction;

  final Widget child;

  const PageTurnSwitcher({
    super.key,
    required this.pageIndex,
    required this.direction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (c, animation) {
        // The incoming child animates 0→1 from the turned-toward side; the
        // outgoing child's animation runs 1→0, so its tween lands it on the
        // opposite side — one continuous push.
        final incoming = c.key == ValueKey(pageIndex);
        final from = incoming ? direction.toDouble() : -direction.toDouble();
        return SlideTransition(
          position: Tween(begin: Offset(from, 0), end: Offset.zero)
              .animate(animation),
          child: c,
        );
      },
      child: KeyedSubtree(key: ValueKey(pageIndex), child: child),
    );
  }
}
