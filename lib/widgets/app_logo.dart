import 'package:flutter/material.dart';

/// The BEE-Alert green circular logo.
/// Use [size] to control width/height.
/// Set [blendWithBackground] to true to wrap the logo in a white
/// rounded box so it stands out on the orange gradient background.
class AppLogo extends StatelessWidget {
  final double size;
  final bool blendWithBackground;

  const AppLogo({
    super.key,
    this.size = 60,
    this.blendWithBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (!blendWithBackground) return logo;

    // White rounded box so the green logo is visible on the orange bg
    final double padding = size < 30 ? 4 : 10;
    final double radius  = size < 30 ? 8 : 16;
    return Container(
      width: size + padding * 2,
      height: size + padding * 2,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: logo),
    );
  }
}
