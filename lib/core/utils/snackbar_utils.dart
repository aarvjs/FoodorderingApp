import 'package:flutter/material.dart';

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
