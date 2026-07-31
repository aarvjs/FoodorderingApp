import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_ordering_app/core/config/app_colors.dart';

class OtpInputFields extends StatefulWidget {
  final int length;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;

  const OtpInputFields({
    super.key,
    this.length = 6,
    this.enabled = true,
    required this.onChanged,
    required this.onCompleted,
  });

  @override
  State<OtpInputFields> createState() => OtpInputFieldsState();
}

class OtpInputFieldsState extends State<OtpInputFields> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late List<FocusNode> _keyboardFocusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    _keyboardFocusNodes = List.generate(widget.length, (_) => FocusNode());

    // Auto focus first node after build if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void clear() {
    for (var c in _controllers) {
      c.clear();
    }
    widget.onChanged('');
    if (mounted && widget.enabled) {
      _focusNodes[0].requestFocus();
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    for (var k in _keyboardFocusNodes) {
      k.dispose();
    }
    super.dispose();
  }

  String get _currentOtp {
    return _controllers.map((c) => c.text).join();
  }

  void _onFieldChanged(String value, int index) {
    if (!widget.enabled) return;

    if (value.length > 1) {
      // User pasted multi-digit code (e.g. 6-digit SMS code)
      final cleanDigits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < widget.length; i++) {
        if (i < cleanDigits.length) {
          _controllers[i].text = cleanDigits[i];
        } else {
          _controllers[i].clear();
        }
      }
      if (cleanDigits.length >= widget.length) {
        _focusNodes[widget.length - 1].unfocus();
        widget.onCompleted(_currentOtp);
      } else if (cleanDigits.isNotEmpty) {
        _focusNodes[cleanDigits.length.clamp(0, widget.length - 1)].requestFocus();
      }
      widget.onChanged(_currentOtp);
      return;
    }

    if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    final otp = _currentOtp;
    widget.onChanged(otp);
    if (otp.length == widget.length) {
      widget.onCompleted(otp);
    }
  }

  void _onKey(KeyEvent event, int index) {
    if (!widget.enabled) return;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      widget.onChanged(_currentOtp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AutofillGroup(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(widget.length, (index) {
          return SizedBox(
            width: 46,
            height: 56,
            child: KeyboardListener(
              focusNode: _keyboardFocusNodes[index],
              onKeyEvent: (event) => _onKey(event, index),
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (val) => _onFieldChanged(val, index),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : Colors.white,
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      width: 2.0,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
