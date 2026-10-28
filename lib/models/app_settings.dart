import 'package:flutter/material.dart';

class AppSettings {
  final String currency;
  final ThemeMode themeMode;
  final double? monthlyBudget;
  final String? backendBaseUrl;
  final bool cloudSyncEnabled;
  final bool setupComplete;
  /// User opted in to send short expense text / AI prompts to the backend.
  final bool aiConsent;

  const AppSettings({
    this.currency = '₹',
    this.themeMode = ThemeMode.system,
    this.monthlyBudget,
    this.backendBaseUrl,
    this.cloudSyncEnabled = true,
    this.setupComplete = false,
    this.aiConsent = false,
  });

  AppSettings copyWith({
    String? currency,
    ThemeMode? themeMode,
    double? monthlyBudget,
    bool clearBudget = false,
    String? backendBaseUrl,
    bool clearBackendUrl = false,
    bool? cloudSyncEnabled,
    bool? setupComplete,
    bool? aiConsent,
  }) {
    return AppSettings(
      currency: currency ?? this.currency,
      themeMode: themeMode ?? this.themeMode,
      monthlyBudget: clearBudget ? null : (monthlyBudget ?? this.monthlyBudget),
      backendBaseUrl:
          clearBackendUrl ? null : (backendBaseUrl ?? this.backendBaseUrl),
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      setupComplete: setupComplete ?? this.setupComplete,
      aiConsent: aiConsent ?? this.aiConsent,
    );
  }

  String get themeModeKey {
    switch (themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode themeModeFromKey(String key) {
    switch (key) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Map<String, dynamic> toFirestore() => {
        'currency': currency,
        'themeMode': themeModeKey,
        'monthlyBudget': monthlyBudget,
        'cloudSyncEnabled': cloudSyncEnabled,
        'setupComplete': setupComplete,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  factory AppSettings.fromFirestore(
    Map<String, dynamic> map, {
    AppSettings? fallback,
  }) {
    final base = fallback ?? const AppSettings();
    return AppSettings(
      currency: (map['currency'] as String?) ?? base.currency,
      themeMode: AppSettings.themeModeFromKey(
        (map['themeMode'] as String?) ?? base.themeModeKey,
      ),
      monthlyBudget:
          (map['monthlyBudget'] as num?)?.toDouble() ?? base.monthlyBudget,
      backendBaseUrl: base.backendBaseUrl,
      cloudSyncEnabled:
          map['cloudSyncEnabled'] as bool? ?? base.cloudSyncEnabled,
      setupComplete: map['setupComplete'] as bool? ?? base.setupComplete,
      aiConsent: base.aiConsent,
    );
  }
}

const List<String> supportedCurrencies = [
  '₹',
  '\$',
  '€',
  '£',
  '¥',
  '₩',
  '₽',
  'A\$',
  'C\$',
];
