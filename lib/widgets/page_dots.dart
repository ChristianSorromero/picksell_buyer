import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Progress indicator: the active dot stretches into a coral pill.
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.currentIndex, this.count = 3});

  final int currentIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.dotInactive,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
