import 'package:flutter/material.dart';

class TopToast {
  static OverlayEntry? _activeEntry;

  /// Display a lightweight success toast from the TOP of the screen.
  /// Auto-dismisses after 2 seconds without blocking touch events or navigation.
  static void show(BuildContext context, String message) {
    _activeEntry?.remove();
    _activeEntry = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final topPadding = MediaQuery.of(ctx).padding.top;

        return Positioned(
          top: topPadding > 0 ? topPadding + 10 : 16,
          left: 20,
          right: 20,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    _activeEntry = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2), () {
      if (_activeEntry == entry) {
        entry.remove();
        _activeEntry = null;
      }
    });
  }
}

class AppSnackbar {
  /// Show a clean floating snackbar that automatically replaces any existing snackbar,
  /// auto-dismisses in 2 seconds, and allows manual dismissal.
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    Color? backgroundColor,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: behavior,
        backgroundColor: backgroundColor,
        action: action,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  /// Clear all active snackbars immediately
  static void clear(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }
}
