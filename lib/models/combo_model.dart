class ComboModel {
  final String id;
  final String name;
  final String image;
  final String description;
  final bool isActive;
  final String? availableFrom;
  final String? availableUntil;
  final List<String>? availableDays;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, dynamic>? branchAvailability;
  final String restaurantId;
  final String? branchId;
  final List<String> branchIds;
  final DateTime? createdAt;

  const ComboModel({
    required this.id,
    required this.name,
    required this.image,
    this.description = '',
    this.isActive = true,
    this.availableFrom,
    this.availableUntil,
    this.availableDays,
    this.startDate,
    this.endDate,
    this.branchAvailability,
    required this.restaurantId,
    this.branchId,
    required this.branchIds,
    this.createdAt,
  });

  static final Map<int, String> _shortDays = {
    1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'
  };
  static final Map<int, String> _longDays = {
    1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday'
  };

  static bool isDayAvailable(List<dynamic>? days) {
    if (days == null || days.isEmpty) return true;
    final now = DateTime.now();
    final shortToday = _shortDays[now.weekday]?.toLowerCase();
    final longToday = _longDays[now.weekday]?.toLowerCase();
    return days.any((d) {
      final s = d.toString().trim().toLowerCase();
      return s == shortToday || s == longToday;
    });
  }

  static int? parseTimeToMinutes(String timeStr) {
    if (timeStr.isEmpty) return null;
    try {
      final cleaned = timeStr.trim().toUpperCase();
      final isPM = cleaned.contains('PM');
      final isAM = cleaned.contains('AM');
      final digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = digitsOnly.split(':');
      if (parts.isEmpty || parts[0].isEmpty) return null;

      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 && parts[1].isNotEmpty ? int.parse(parts[1]) : 0;

      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      return hour * 60 + minute;
    } catch (_) {
      return null;
    }
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  bool isCurrentlyAvailableForBranch(String? targetBranchId) {
    if (!isActive) return false;

    bool bActive = isActive;
    String sFrom = availableFrom ?? '';
    String sUntil = availableUntil ?? '';
    List<dynamic>? days = availableDays;
    DateTime? dtStart = startDate;
    DateTime? dtEnd = endDate;

    if (branchAvailability != null && branchAvailability!.isNotEmpty) {
      dynamic override;
      if (targetBranchId != null && targetBranchId.isNotEmpty) {
        override = branchAvailability![targetBranchId];
      }

      if (override is Map) {
        final Map map = override;
        if (map.containsKey('isActive')) {
          bActive = map['isActive'] == true;
        } else if (map.containsKey('isAvailable')) {
          bActive = map['isAvailable'] == true;
        }

        final fromMap = _firstNonEmpty([map['availableFrom']]);
        if (fromMap.isNotEmpty) sFrom = fromMap;

        final untilMap = _firstNonEmpty([map['availableUntil']]);
        if (untilMap.isNotEmpty) sUntil = untilMap;

        if (map['availableDays'] is List) {
          days = List<String>.from((map['availableDays'] as List).map((e) => e.toString()));
        }

        if (map['startDate'] != null && map['startDate'].toString().isNotEmpty) {
          if (map['startDate'] is String) dtStart = DateTime.tryParse(map['startDate']);
        }
        if (map['endDate'] != null && map['endDate'].toString().isNotEmpty) {
          if (map['endDate'] is String) dtEnd = DateTime.tryParse(map['endDate']);
        }
      }
    }

    if (!bActive) return false;

    final now = DateTime.now();
    if (dtStart != null) {
      final startDateOnly = DateTime(dtStart.year, dtStart.month, dtStart.day);
      final todayOnly = DateTime(now.year, now.month, now.day);
      if (todayOnly.isBefore(startDateOnly)) return false;
    }

    if (dtEnd != null) {
      final endDateEnd = DateTime(dtEnd.year, dtEnd.month, dtEnd.day, 23, 59, 59);
      if (now.isAfter(endDateEnd)) return false;
    }

    if (!isDayAvailable(days)) return false;
    return _isWithinTimeSchedule(sFrom, sUntil);
  }

  bool _isWithinTimeSchedule(String sFrom, String sUntil) {
    final startMinutesParsed = parseTimeToMinutes(sFrom);
    final endMinutesParsed = parseTimeToMinutes(sUntil);

    if (startMinutesParsed == null && endMinutesParsed == null) return true;

    final startMinutes = startMinutesParsed ?? 0;
    final endMinutes = endMinutesParsed ?? 1439;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    if (endMinutes > startMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else if (startMinutes > endMinutes) {
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    } else {
      return true;
    }
  }

  factory ComboModel.fromFirestore(Map<String, dynamic> data, String docId) {
    final rawBranchIds = data['branchIds'];
    final List<String> branchIdsList = (rawBranchIds is List)
        ? rawBranchIds.map((b) => b.toString().trim()).where((b) => b.isNotEmpty).toList()
        : (rawBranchIds is Map
            ? rawBranchIds.values.map((b) => b.toString().trim()).where((b) => b.isNotEmpty).toList()
            : []);

    final String name = (data['name'] ?? data['title'] ?? 'Combo').toString();
    final String image = (data['image'] ?? data['imageUrl'] ?? data['bannerUrl'] ?? 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop').toString();
    final String description = (data['description'] ?? '').toString();

    final String? statusStr = data['status']?.toString().toUpperCase();
    final bool isActive = (statusStr == null || statusStr == 'ACTIVE') &&
        (data['isActive'] != false) &&
        (data['isAvailable'] != false) &&
        (data['active'] != false);
    final String restaurantId = (data['restaurantId'] ?? '').toString();
    final String? branchId = data['branchId']?.toString();

    final String? availableFrom = data['availableFrom']?.toString();
    final String? availableUntil = data['availableUntil']?.toString();
    final List<String>? availableDays = (data['availableDays'] as List?)?.map((e) => e.toString()).toList();
    final Map<String, dynamic>? branchAvailability = data['branchAvailability'] is Map
        ? Map<String, dynamic>.from(data['branchAvailability'])
        : null;

    DateTime? startDate;
    if (data['startDate'] is String && (data['startDate'] as String).isNotEmpty) {
      startDate = DateTime.tryParse(data['startDate']);
    }

    DateTime? endDate;
    if (data['endDate'] is String && (data['endDate'] as String).isNotEmpty) {
      endDate = DateTime.tryParse(data['endDate']);
    }

    DateTime? createdAt;
    if (data['createdAt'] is String) {
      createdAt = DateTime.tryParse(data['createdAt']);
    }

    return ComboModel(
      id: docId,
      name: name,
      image: image,
      description: description,
      isActive: isActive,
      availableFrom: availableFrom,
      availableUntil: availableUntil,
      availableDays: availableDays,
      startDate: startDate,
      endDate: endDate,
      branchAvailability: branchAvailability,
      restaurantId: restaurantId,
      branchId: branchId,
      branchIds: branchIdsList,
      createdAt: createdAt,
    );
  }
}
