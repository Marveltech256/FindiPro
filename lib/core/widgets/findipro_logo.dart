import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable branding widget for FindiPro.
/// Supports both SVG and PNG assets, full horizontal logo and standalone icon mark,
/// while strictly preserving the official brand colors, typography, and aspect ratios.
class FindiProLogo extends StatelessWidget {
  /// Whether to show only the logo symbol/icon or the full horizontal logo with text.
  final bool isIconOnly;

  /// Optional width constraint.
  final double? width;

  /// Optional height constraint.
  final double? height;

  /// Box fit for logo scaling (defaults to BoxFit.contain to ensure no distortion).
  final BoxFit fit;

  /// Optional hero tag for smooth transitions.
  final String? heroTag;

  const FindiProLogo({
    super.key,
    this.isIconOnly = false,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.heroTag,
  });

  /// Factory constructor for the standalone app icon/mark.
  const FindiProLogo.icon({
    super.key,
    double? size,
    this.fit = BoxFit.contain,
    this.heroTag,
  })  : isIconOnly = true,
        width = size,
        height = size;

  /// Factory constructor for the full horizontal logo.
  const FindiProLogo.full({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.heroTag,
  }) : isIconOnly = false;

  @override
  Widget build(BuildContext context) {
    final svgAsset = isIconOnly
        ? 'assets/branding/App Icon.svg'
        : 'assets/branding/Primary logo.svg';

    final pngFallback = isIconOnly
        ? 'assets/branding/App Icon.png'
        : 'assets/branding/Primary logo.png';

    Widget logoWidget = SvgPicture.asset(
      svgAsset,
      width: width,
      height: height,
      fit: fit,
      placeholderBuilder: (BuildContext context) => Image.asset(
        pngFallback,
        width: width,
        height: height,
        fit: fit,
      ),
    );

    if (heroTag != null) {
      logoWidget = Hero(
        tag: heroTag!,
        child: logoWidget,
      );
    }

    return logoWidget;
  }
}
