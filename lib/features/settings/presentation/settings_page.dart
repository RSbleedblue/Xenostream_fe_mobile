import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          sliver: SliverList.list(
            children: [
              Text(
                'SETTINGS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Preferences',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Account, API keys, and quality defaults will live here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
