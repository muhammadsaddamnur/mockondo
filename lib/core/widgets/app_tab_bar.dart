import 'package:flutter/material.dart';
import 'package:mockondo/core/colors.dart';

/// Consistent tab bar used across the entire app.
/// Tabs have a bottom-border highlight when selected.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onTap,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.textD.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isActive = i == selected;
          return InkWell(
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive
                        ? AppColors.secondaryD
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: isActive
                        ? AppColors.textD
                        : AppColors.textD.withValues(alpha: 0.45),
                    fontSize: AppTextSize.small,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
