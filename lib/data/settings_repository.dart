import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../utils/constants.dart';

class SettingsRepository {
  static const _currencyKey = 'currency';
  static const _themeKey = 'themeMode';
  static const _budgetKey = 'monthlyBudget';
  static const _backendUrlKey = 'backendBaseUrl';
  static const _cloudSyncKey = 'cloudSyncEnabled';
  static const _aiConsentKey = 'aiConsent';
  static const _budgetAlertMonthKey = 'budgetAlertMonth';
  static const _onboardingKey = 'onboardingComplete';
  static const _initialSetupKey = 'initialSetupComplete';

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, value);
  }

  Future<bool> isInitialSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_initialSetupKey) ?? false;
  }

  Future<void> setInitialSetupComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_initialSetupKey, value);
  }

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final budget = prefs.getDouble(_budgetKey);
    return AppSettings(
      currency: prefs.getString(_currencyKey) ?? '₹',
      themeMode: AppSettings.themeModeFromKey(
        prefs.getString(_themeKey) ?? 'system',
      ),
      monthlyBudget: budget,
      backendBaseUrl: prefs.getString(_backendUrlKey) ??
          AppConstants.defaultBackendBaseUrl,
      cloudSyncEnabled: prefs.getBool(_cloudSyncKey) ?? true,
      setupComplete: prefs.getBool(_initialSetupKey) ?? false,
      aiConsent: prefs.getBool(_aiConsentKey) ?? false,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, settings.currency);
    await prefs.setString(_themeKey, settings.themeModeKey);
    if (settings.monthlyBudget == null) {
      await prefs.remove(_budgetKey);
    } else {
      await prefs.setDouble(_budgetKey, settings.monthlyBudget!);
    }
    if (settings.backendBaseUrl == null || settings.backendBaseUrl!.isEmpty) {
      await prefs.remove(_backendUrlKey);
    } else {
      await prefs.setString(_backendUrlKey, settings.backendBaseUrl!);
    }
    await prefs.setBool(_cloudSyncKey, settings.cloudSyncEnabled);
    await prefs.setBool(_aiConsentKey, settings.aiConsent);
    await prefs.setBool(_initialSetupKey, settings.setupComplete);
  }

  Future<String?> getBudgetAlertMonth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_budgetAlertMonthKey);
  }

  Future<void> setBudgetAlertMonth(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_budgetAlertMonthKey, key);
  }
}
