import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:payu_checkoutpro_flutter/payu_checkoutpro_flutter.dart';
import 'package:payu_checkoutpro_flutter/PayUConstantKeys.dart';
import '../config/payu_config.dart';

class PayUService implements PayUCheckoutProProtocol {
  late final PayUCheckoutProFlutter _payuCheckoutProFlutter;

  Function(Map<String, dynamic> response)? _onSuccess;
  Function(Map<String, dynamic> response)? _onFailure;
  Function(Map<String, dynamic> response)? _onCancel;
  Function(Map<String, dynamic> response)? _onError;

  PayUService() {
    _payuCheckoutProFlutter = PayUCheckoutProFlutter(this);
  }

  /// Generate a unique transaction ID satisfying PayU format restrictions (max 30 alphanumeric characters)
  /// Example: PP20260820121500123456
  static String generateTransactionId() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final randomDigits = Random().nextInt(900000) + 100000;
    return 'PP$dateStr$randomDigits';
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

  /// Start PayU Checkout Pro Payment Flow
  Future<void> startPayment({
    required String transactionId,
    required double amount,
    required String customerName,
    required String customerPhone,
    String productInfo = 'Food Order',
    required Function(Map<String, dynamic> response) onSuccess,
    required Function(Map<String, dynamic> response) onFailure,
    required Function(Map<String, dynamic> response) onCancel,
    required Function(Map<String, dynamic> response) onError,
  }) async {
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _onCancel = onCancel;
    _onError = onError;

    final String cleanPhone = cleanPhoneNumber(customerPhone);
    final String cleanName = customerName.trim().isNotEmpty ? customerName.trim() : 'Customer';
    final String sdkEmail = '$cleanPhone@customer.app';

    final Map<String, dynamic> additionalParams = {
      PayUAdditionalParamKeys.udf1: '',
      PayUAdditionalParamKeys.udf2: '',
      PayUAdditionalParamKeys.udf3: '',
      PayUAdditionalParamKeys.udf4: '',
      PayUAdditionalParamKeys.udf5: '',
    };

    final Map<String, dynamic> paymentParams = {
      PayUPaymentParamKey.key: PayUConfig.merchantKey,
      PayUPaymentParamKey.transactionId: transactionId,
      PayUPaymentParamKey.amount: amount.toStringAsFixed(2),
      PayUPaymentParamKey.productInfo: productInfo,
      PayUPaymentParamKey.firstName: cleanName,
      PayUPaymentParamKey.email: sdkEmail,
      PayUPaymentParamKey.phone: cleanPhone,
      PayUPaymentParamKey.android_surl: 'https://payu.herokuapp.com/success',
      PayUPaymentParamKey.android_furl: 'https://payu.herokuapp.com/failure',
      PayUPaymentParamKey.ios_surl: 'https://payu.herokuapp.com/success',
      PayUPaymentParamKey.ios_furl: 'https://payu.herokuapp.com/failure',
      PayUPaymentParamKey.environment: PayUConfig.isTestMode ? '1' : '0',
      PayUPaymentParamKey.userCredential: '${PayUConfig.merchantKey}:$sdkEmail',
      PayUPaymentParamKey.additionalParam: additionalParams,
    };

    final Map<String, dynamic> payuConfig = {
      PayUCheckoutProConfigKeys.merchantName: 'Perfect Pizza',
      PayUCheckoutProConfigKeys.merchantResponseTimeout: 30000,
      PayUCheckoutProConfigKeys.showExitConfirmationOnCheckoutScreen: true,
      PayUCheckoutProConfigKeys.showExitConfirmationOnPaymentScreen: true,
    };

    try {
      _payuCheckoutProFlutter.openCheckoutScreen(
        payUPaymentParams: paymentParams,
        payUCheckoutProConfig: payuConfig,
      );
    } catch (e) {
      debugPrint('PayU openCheckoutScreen exception: $e');
      _onError?.call({'message': 'Failed to initialize PayU payment: $e'});
    }
  }

  /// Implementation of PayUCheckoutProProtocol callback to fetch hash from secure Next.js backend
  @override
  generateHash(Map response) async {
    String generatedHash = '';
    final String hashName = (response['hashName'] ?? response[PayUHashConstantsKeys.hashName] ?? '').toString();
    final String hashString = (response['hashString'] ?? response[PayUHashConstantsKeys.hashString] ?? '').toString();
    final String postSalt = (response['postSalt'] ?? response[PayUHashConstantsKeys.postSalt] ?? '').toString();

    debugPrint('PayU generateHash request: hashName=$hashName, hashStringLength=${hashString.length}');

    try {
      final Map<String, dynamic> requestPayload = {
        'hashName': hashName,
        'hashString': hashString,
        'postSalt': postSalt,
        'mkey': PayUConfig.merchantKey,
      };

      response.forEach((key, value) {
        if (key != null && value != null) {
          requestPayload[key.toString()] = value.toString();
        }
      });

      final res = await http.post(
        Uri.parse(PayUConfig.hashApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestPayload),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        generatedHash = (data['hash'] ?? data[hashName] ?? '').toString();
      } else {
        debugPrint('PayU backend hash API status: ${res.statusCode}, using fallback SHA-512');
      }
    } catch (e) {
      debugPrint('PayU backend HTTP exception: $e, using fallback SHA-512');
    }

    if (generatedHash.isEmpty && hashString.isNotEmpty) {
      generatedHash = _calculateFallbackHash(hashString, postSalt);
    }

    debugPrint('PayU returning generated hash for $hashName: hashPresent=${generatedHash.isNotEmpty}');

    final Map<String, String> hashMap = {
      hashName: generatedHash,
    };

    _payuCheckoutProFlutter.hashGenerated(hash: hashMap);
  }

  /// Backup hash calculator to prevent SDK freeze if backend server is unreachable during local testing
  String _calculateFallbackHash(String hashString, String postSalt) {
    const merchantSalt = 'jtXYzpJhrGdPLiYt9aHOz9Q6EhBILvBo';
    if (hashString.isEmpty) return '';

    String strToHash = hashString;
    if (!strToHash.endsWith(merchantSalt)) {
      if (strToHash.endsWith('|')) {
        strToHash = strToHash + merchantSalt;
      } else {
        strToHash = strToHash + '|' + merchantSalt;
      }
    }

    if (postSalt.isNotEmpty && !strToHash.endsWith(postSalt)) {
      if (strToHash.endsWith('|')) {
        strToHash = strToHash + postSalt;
      } else {
        strToHash = strToHash + '|' + postSalt;
      }
    }

    final bytes = utf8.encode(strToHash);
    return sha512.convert(bytes).toString().toLowerCase();
  }

  @override
  onPaymentSuccess(dynamic response) {
    debugPrint('PayU onPaymentSuccess callback: $response');
    if (response is Map) {
      _onSuccess?.call(Map<String, dynamic>.from(response));
    } else {
      _onSuccess?.call({'response': response});
    }
  }

  @override
  onPaymentFailure(dynamic response) {
    debugPrint('PayU onPaymentFailure callback: $response');
    if (response is Map) {
      _onFailure?.call(Map<String, dynamic>.from(response));
    } else {
      _onFailure?.call({'response': response});
    }
  }

  @override
  onPaymentCancel(Map? response) {
    debugPrint('PayU onPaymentCancel callback: $response');
    _onCancel?.call(response != null ? Map<String, dynamic>.from(response) : {'status': 'CANCELLED'});
  }

  @override
  onError(Map? response) {
    debugPrint('PayU onError callback: $response');
    _onError?.call(response != null ? Map<String, dynamic>.from(response) : {'error': 'Unknown PayU Error'});
  }

  /// Verify transaction result with Next.js backend `/api/payu/verify`
  static Future<Map<String, dynamic>> verifyPaymentWithServer({
    required String transactionId,
    Map<String, dynamic>? payuResponse,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(PayUConfig.verifyApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'txnid': transactionId,
          if (payuResponse != null) 'payuResponse': payuResponse,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data);
      } else {
        return {
          'verified': false,
          'paymentStatus': 'FAILED',
          'message': 'Backend verification HTTP error ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('PayU verifyPaymentWithServer exception: $e');
      return {
        'verified': false,
        'paymentStatus': 'FAILED',
        'message': 'Failed to reach payment verification server: $e',
      };
    }
  }
}
