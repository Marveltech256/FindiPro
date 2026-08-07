import 'package:flutter/material.dart';
import 'package:findipro/theme/app_theme.dart';

class SkillChip extends StatelessWidget {
  final String label;
  const SkillChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: AppTheme.accentColor.withOpacity(0.1),
      labelStyle: const TextStyle(
        color: AppTheme.accentColor,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
    );
  }
}