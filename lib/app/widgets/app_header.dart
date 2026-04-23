import 'package:flutter/material.dart';

import '../../core/constants/app_brand.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import 'brand_logo.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.onAvatarTap,
    this.backgroundColor,
    this.bottomBorder = true,
  });

  final String? title;

  final Widget? leading;

  final Widget? trailing;

  final VoidCallback? onAvatarTap;

  final Color? backgroundColor;

  final bool bottomBorder;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = title ?? kAppDisplayName;
    final bg = backgroundColor ?? AppColors.canvas;
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w900,
      color: Theme.of(context).colorScheme.secondary,
      letterSpacing: -0.2,
    );

    return Material(
      color: bg,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          border: bottomBorder
              ? Border(bottom: BorderSide(color: NeutralPalette.n200))
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              leading ?? const AppHeaderBrandMark(),
              Expanded(
                child: Text(
                  resolvedTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
              trailing ?? _DefaultAvatar(onTap: onAvatarTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ring = PrimaryPalette.p400.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: 1.5),
            color: NeutralPalette.n100,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: NeutralPalette.n200,
              child: Icon(
                Icons.person_rounded,
                size: 22,
                color: SecondaryPalette.s800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
