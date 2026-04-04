import 'package:shared_preferences/shared_preferences.dart';

/// Manages the daily video upload limit for free users.
/// Free: 3 videos/day. Premium: unlimited.
class UsageLimitService {
  static const int freeLimit = 3;
  static const String _countKey = 'daily_upload_count';
  static const String _dateKey = 'daily_upload_date';
  static const String _premiumKey = 'is_premium_user';

  /// Check if user can upload (has remaining uploads today)
  static Future<bool> canUpload() async {
    if (await isPremium()) return true;
    final remaining = await getRemainingUploads();
    return remaining > 0;
  }

  /// Get remaining uploads for today
  static Future<int> getRemainingUploads() async {
    if (await isPremium()) return 999;
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final savedDate = prefs.getString(_dateKey) ?? '';

    if (savedDate != today) {
      // New day — reset counter
      await prefs.setInt(_countKey, 0);
      await prefs.setString(_dateKey, today);
      return freeLimit;
    }

    final used = prefs.getInt(_countKey) ?? 0;
    return (freeLimit - used).clamp(0, freeLimit);
  }

  /// Record one upload used
  static Future<void> recordUpload() async {
    if (await isPremium()) return;
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final savedDate = prefs.getString(_dateKey) ?? '';

    if (savedDate != today) {
      await prefs.setString(_dateKey, today);
      await prefs.setInt(_countKey, 1);
    } else {
      final current = prefs.getInt(_countKey) ?? 0;
      await prefs.setInt(_countKey, current + 1);
    }
  }

  /// Check if user has premium subscription
  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumKey) ?? false;
  }

  /// Set premium status (called by billing service)
  static Future<void> setPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, value);
  }

  /// Get today's date as string (YYYY-MM-DD)
  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
