import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/brand_header.dart';
import 'initial_setup_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    _OnboardPage(
      icon: Icons.receipt_long_rounded,
      title: 'Log spends in seconds',
      body: 'Capture amount, category, and a quick note before you forget.',
    ),
    _OnboardPage(
      icon: Icons.pie_chart_rounded,
      title: 'See where money goes',
      body: 'Monthly charts and category totals make patterns obvious.',
    ),
    _OnboardPage(
      icon: Icons.cloud_sync_rounded,
      title: 'Stay in sync',
      body: 'Works offline. Sign in when you want cloud backup across devices.',
    ),
  ];

  Future<void> _finish({bool openRegister = false, bool openLogin = false}) async {
    await context.read<SettingsProvider>().completeOnboarding();
    if (!mounted) return;

    if (openRegister) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
      return;
    }
    if (openLogin) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // Offline path → currency + monthly budget setup next
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const InitialSetupScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;

    return AppScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _finish(),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(height: 8),
              const BrandHeader(logoSize: 108),
              const SizedBox(height: 28),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final page = _pages[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page.icon, size: 38, color: AppColors.teal),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.65),
                                height: 1.45,
                              ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.teal
                          : AppColors.teal.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              if (!isLast)
                FilledButton(
                  onPressed: () => _controller.nextPage(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Continue'),
                )
              else ...[
                FilledButton(
                  onPressed: () => _finish(openRegister: true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Create account'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _finish(openLogin: true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('I already have an account'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _finish(),
                  child: const Text('Continue offline'),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                AppConstants.appTagline,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.coral,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage {
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
