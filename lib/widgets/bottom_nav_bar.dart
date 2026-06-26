import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool emphasized; // for the creator "Studio" centre action
  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.emphasized = false,
  });
}

class MillimoreBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MillimoreBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final active = i == currentIndex;
              if (item.emphasized) {
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Center(
                      child: Container(
                        width: 46,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.activeIcon, size: 24, color: Colors.white),
                      ),
                    ),
                  ),
                );
              }
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? item.activeIcon : item.icon,
                        size: 24,
                        color: active ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          color: active ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
