import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/constants.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.showTagline = true,
    this.logoSize = 96,
    this.compact = false,
  });

  final bool showTagline;
  final double logoSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: const Color(0xFFF2EEE6),
            borderRadius: BorderRadius.circular(logoSize * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppColors.teal.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            AppConstants.logoAsset,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: compact ? 12 : 18),
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text(
            AppConstants.appTagline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ],
      ],
    );
  }
}
