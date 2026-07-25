import 'package:flutter/material.dart';

/// Shared EduBridge logo (`assets/logo/edubridge_logo.png`).
class EduBridgeLogo extends StatelessWidget {
  const EduBridgeLogo({super.key, this.size = 30});

  /// Display height in logical pixels (width follows aspect ratio).
  final double size;

  static const assetPath = 'assets/logo/edubridge_logo.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('EduBridge logo failed to load at "$assetPath": $error');
        return SizedBox(
          height: size,
          width: size,
          child: Center(
            child: Text(
              'eb',
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}
