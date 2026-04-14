import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../core/session/active_voice_profile_store.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ActiveVoiceProfileStore>();
    final profile = store.profile;
    final textTheme = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          sliver: SliverList.list(
            children: [
              Text(
                'HOME',
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Welcome',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Record your voice, then synthesize narration from the Library workspace.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Image.asset(
                  'assets/branding/app_logo.png',
                  height: 100,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.graphic_eq,
                    size: 88,
                    color: AppColors.primaryPurple.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: AppRadii.xlBorder,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: profile != null
                      ? ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.verified_rounded, color: AppColors.primaryPurple),
                          title: const Text('Voice locked'),
                          subtitle: Text(
                            profile.id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.mic_none_rounded,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                          title: const Text('No voice enrolled yet'),
                          subtitle: const Text('Use Record to capture up to two minutes.'),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.go('/record'),
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Record & lock voice'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/library'),
                icon: const Icon(Icons.library_music_rounded),
                label: const Text('Open Library workspace'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
