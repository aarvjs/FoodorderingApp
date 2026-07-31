class AuthValidators {
  /// Validates standard 10-digit Indian phone number
  static String? validatePhoneNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return 'Mobile number is required';
    }
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length != 10) {
      return 'Enter a valid 10-digit mobile number';
    }
    final indianPhoneRegex = RegExp(r'^[6-9]\d{9}$');
    if (!indianPhoneRegex.hasMatch(cleanPhone)) {
      return 'Mobile number must start with 6, 7, 8, or 9';
    }
    return null;
  }

  /// Checks if phone number is valid (returns boolean)
  static bool isValidPhone(String phone) {
    return validatePhoneNumber(phone) == null;
  }

  /// Validates 6-digit OTP
  static String? validateOtp(String? otp) {
    if (otp == null || otp.trim().isEmpty) {
      return 'OTP is required';
    }
    if (otp.trim().length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp.trim())) {
      return 'Enter valid 6-digit OTP';
    }
    return null;
  }

  /// Checks if OTP is valid (returns boolean)
  static bool isValidOtp(String otp) {
    return validateOtp(otp) == null;
  }

  /// Validates Full Name
  static String? validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Full Name is required';
    }
    if (name.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  /// Validates optional email
  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return null; // Optional
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }
}
