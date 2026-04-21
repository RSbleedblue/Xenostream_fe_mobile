import 'package:flutter/material.dart';

import '../../core/constants/app_brand.dart';
import '../theme/app_radii.dart';

Decoration _brandMarkPlateDecoration(
  BuildContext context, {
  BorderRadius? borderRadius,
}) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.secondary,
    borderRadius: borderRadius ?? AppRadii.lgBorder,
  );
}

/// Hero / home logo.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.height = 100,
    this.fit = BoxFit.contain,
    this.tint,
    this.useContrastPlate = true,
  });

  final double height;
  final BoxFit fit;
  final Color? tint;

  /// When true, sits on a white “plate” so light artwork does not wash into the canvas.
  final bool useContrastPlate;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      kBrandMarkPng,
      height: height,
      fit: fit,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      gaplessPlayback: true,
      color: tint,
      colorBlendMode: tint != null ? BlendMode.srcIn : null,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return Icon(
          Icons.broken_image_outlined,
          size: height * 0.15,
          color: Theme.of(context).colorScheme.outline,
        );
      },
    );

    if (!useContrastPlate) {
      return image;
    }

    return DecoratedBox(
      decoration: _brandMarkPlateDecoration(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: image,
      ),
    );
  }
}

/// Compact mark for the app header.
class AppHeaderBrandMark extends StatelessWidget {
  const AppHeaderBrandMark({
    super.key,
    this.height = 20,
    this.tint,
    this.useContrastPlate = true,
  });

  final double height;
  final Color? tint;
  final bool useContrastPlate;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      kBrandMarkPng,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      gaplessPlayback: true,
      color: tint,
      colorBlendMode: tint != null ? BlendMode.srcIn : null,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return Icon(
          Icons.broken_image_outlined,
          size: height * 0.55,
          color: Theme.of(context).colorScheme.outline,
        );
      },
    );

    if (!useContrastPlate) {
      return SizedBox(
        height: height,
        width: height * 1.15,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          child: image,
        ),
      );
    }

    return DecoratedBox(
      decoration: _brandMarkPlateDecoration(
        context,
        borderRadius: AppRadii.mdBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: SizedBox(
          height: height,
          // width: height * 1.12,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            child: image,
          ),
        ),
      ),
    );
  }
}
