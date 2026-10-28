import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../data/settings_repository.dart';
import '../models/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({SettingsRepository? repository})
      : _repo = repository ?? SettingsRepository();

  final SettingsRepository _repo;
  AppSettings _settings = const AppSettings();
  bool _loaded = false;
  bool _onboardingComplete = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _loaded;
  bool get onboardingComplete => _onboardingComplete;
  bool get initialSetupComplete => _settings.setupComplete;
  String get currency => _settings.currency;
  ThemeMode get themeMode => _settings.themeMode;
  double? get monthlyBudget => _settings.monthlyBudget;
  String? get backendBaseUrl => _settings.backendBaseUrl;
  bool get cloudSyncEnabled => _settings.cloudSyncEnabled;
  bool get aiConsent => _settings.aiConsent;

  Future<void> load() async {
    _settings = await _repo.load();
    _onboardingComplete = await _repo.isOnboardingComplete();
    _loaded = true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    await _repo.setOnboardingComplete(true);
    notifyListeners();
  }

  Future<void> completeInitialSetup() async {
    _settings = _settings.copyWith(setupComplete: true);
    await _repo.save(_settings);
    notifyListeners();
  }

  Future<void> setCurrency(String currency) async {
    _settings = _settings.copyWith(currency: currency);
    await _repo.save(_settings);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    await _repo.save(_settings);
    notifyListeners();
  }

  Future<void> setMonthlyBudget(double? budget) async {
    _settings = budget == null
        ? _settings.copyWith(clearBudget: true)
        : _settings.copyWith(monthlyBudget: budget);
    await _repo.save(_settings);
    notifyListeners();
  }

  Future<void> setBackendBaseUrl(String? url) async {
    _settings = (url == null || url.trim().isEmpty)
        ? _settings.copyWith(clearBackendUrl: true)
        : _settings.copyWith(backendBaseUrl: url.trim());
    await _repo.save(_settings);
    notifyListeners();
  }

  Future<void> setCloudSyncEnabled(bool enabled) async {
    _settings = _settings.copyWith(cloudSyncEnabled: enabled);
    await _repo.save(_settings);
    notifyListeners();
  }

  Future<void> setAiConsent(bool enabled) async {
    _settings = _settings.copyWith(aiConsent: enabled);
    await _repo.save(_settings);
    notifyListeners();
  }

  Future<bool> shouldShowBudgetAlert(DateTime month, double spent) async {
    final budget = _settings.monthlyBudget;
    if (budget == null || budget <= 0 || spent <= budget) return false;
    final key = '${month.year}-${month.month}';
    final last = await _repo.getBudgetAlertMonth();
    return last != key;
  }

  Future<void> markBudgetAlertShown(DateTime month) async {
    await _repo.setBudgetAlertMonth('${month.year}-${month.month}');
  }

  Future<void> clearAllData() async {
    await DatabaseHelper.instance.clearAllData();
    await setMonthlyBudget(null);
  }
}
