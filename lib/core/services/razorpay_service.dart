import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/razorpay_config.dart';

class RazorpayService {
  late final Razorpay _razorpay;

  Function(PaymentSuccessResponse response)? _onSuccess;
  Function(PaymentFailureResponse response)? _onFailure;
  Function(ExternalWalletResponse response)? _onExternalWallet;

  RazorpayService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Razorpay Success: paymentId=${response.paymentId}, orderId=${response.orderId}');
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Razorpay Failure: code=${response.code}, message=${response.message}');
    _onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('Razorpay External Wallet: walletName=${response.walletName}');
    _onExternalWallet?.call(response);
  }

  /// Clean customer phone number safely to valid 10-digit Indian mobile number string
  static String cleanPhoneNumber(String rawPhone) {
    String digits = rawPhone.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }

    return '9876543210';
  }

  /// Open Razorpay Checkout standard UI
  void startPayment({
    required double amount,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String description = 'Food Order',
    required Function(PaymentSuccessResponse response) onSuccess,
    required Function(PaymentFailureResponse response) onFailure,
    Function(ExternalWalletResponse response)? onExternalWallet,
  }) {
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _onExternalWallet = onExternalWallet;

    final String cleanPhone = cleanPhoneNumber(customerPhone);
    final String cleanName = customerName.trim().isNotEmpty ? customerName.trim() : 'Customer';
    final String email = (customerEmail != null && customerEmail.trim().isNotEmpty)
        ? customerEmail.trim()
        : '$cleanPhone@customer.app';

    // Convert amount in INR to smallest currency unit (paise: 1 INR = 100 Paise)
    final int amountInPaise = (amount * 100).round();

    final options = {
      'key': RazorpayConfig.keyId,
      'amount': amountInPaise,
      'name': 'Perfect Pizza',
      'description': description,
      'prefill': {
        'contact': cleanPhone,
        'email': email,
        'name': cleanName,
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay open exception: $e');
      _onFailure?.call(PaymentFailureResponse(
        Razorpay.UNKNOWN_ERROR,
        'Failed to open Razorpay Checkout: $e',
        {'error': e.toString()},
      ));
    }
  }

  /// Clean up Razorpay instance resources
  void clear() {
    _razorpay.clear();
  }
}
