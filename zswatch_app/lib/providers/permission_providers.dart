import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const permissionOnboardingCompletedKey = 'permission_onboarding_completed';

final permissionOnboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(permissionOnboardingCompletedKey) ?? false;
});
