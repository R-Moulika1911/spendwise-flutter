import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import 'notification_service.dart';

class BudgetAlertService {
  /// Checks this month’s spend vs budget and fires a system notification
  /// once per month when over budget.
  static Future<bool> checkAndNotify({
    required SettingsProvider settings,
    required ExpenseProvider expenses,
    bool force = false,
  }) async {
    final budget = settings.monthlyBudget;
    if (budget == null || budget <= 0) return false;

    final now = DateTime.now();
    final total = await expenses.monthTotalUnfiltered(now);
    if (total <= budget) return false;

    final shouldAlert =
        force || await settings.shouldShowBudgetAlert(now, total);
    if (!shouldAlert) return false;

    await settings.markBudgetAlertShown(now);
    await NotificationService.instance.showBudgetExceeded(
      currency: settings.currency,
      spent: total,
      budget: budget,
    );
    return true;
  }
}
