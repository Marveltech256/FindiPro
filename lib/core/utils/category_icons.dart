import 'package:flutter/material.dart';

String _normalizeKey(String category) {
  return category.toLowerCase().replaceAll(RegExp(r'[\s_&/\\-]'), '');
}

IconData categoryIcon(String category) {
  final key = _normalizeKey(category);

  switch (key) {
    case 'plumbing':
      return Icons.plumbing;

    case 'electrical':
      return Icons.electrical_services;

    case 'cleaning':
      return Icons.cleaning_services;

    case 'mechanic':
      return Icons.car_repair;

    case 'painting':
      return Icons.format_paint;

    case 'gardening':
      return Icons.yard;

    case 'carpentry':
      return Icons.carpenter;

    case 'moving':
      return Icons.local_shipping;

    case 'beauty':
      return Icons.face_retouching_natural;

    case 'construction':
      return Icons.construction;

    case 'ittechnology':
    case 'it':
    case 'technology':
      return Icons.devices;

    case 'acrepair':
    case 'ac':
    case 'hvac':
      return Icons.hvac;

    case 'roofing':
      return Icons.roofing;

    case 'welding':
      return Icons.precision_manufacturing;

    case 'security':
      return Icons.shield;

    case 'tiling':
      return Icons.grid_view;

    case 'pestcontrol':
      return Icons.pest_control;

    case 'appliancerepair':
    case 'appliance':
      return Icons.home_repair_service;

    case 'householditems':
    case 'household':
      return Icons.chair;

    case 'foodsandbeverages':
    case 'foodbeverages':
    case 'food':
      return Icons.restaurant;

    case 'phonesandaccessories':
    case 'phonesaccessories':
    case 'phones':
      return Icons.smartphone;

    case 'other':
      return Icons.category;

    default:
      return Icons.build_circle_outlined;
  }
}

Color categoryColor(String category) {
  final key = _normalizeKey(category);

  switch (key) {
    case 'plumbing':
      return const Color(0xFF0284C7); // Deep Sky / Cyan

    case 'electrical':
      return const Color(0xFFF59E0B); // Vibrant Gold

    case 'cleaning':
      return const Color(0xFF10B981); // Emerald Green

    case 'mechanic':
      return const Color(0xFF475569); // Slate Steel

    case 'painting':
      return const Color(0xFFF97316); // Warm Amber/Orange

    case 'gardening':
      return const Color(0xFF22C55E); // Lush Garden Green

    case 'carpentry':
      return const Color(0xFFD97706); // Warm Wood Amber

    case 'moving':
      return const Color(0xFF6366F1); // Indigo

    case 'beauty':
      return const Color(0xFFEC4899); // Rose Pink

    case 'construction':
      return const Color(0xFFEA580C); // Safety Orange

    case 'ittechnology':
    case 'it':
    case 'technology':
      return const Color(0xFF8B5CF6); // Modern Violet

    case 'acrepair':
    case 'ac':
    case 'hvac':
      return const Color(0xFF06B6D4); // Cool Cyan

    case 'roofing':
      return const Color(0xFFB45309); // Terracotta Amber

    case 'welding':
      return const Color(0xFFE11D48); // Industrial Red/Flame

    case 'security':
      return const Color(0xFF2563EB); // Royal Blue Security

    case 'tiling':
      return const Color(0xFF0D9488); // Teal Tile

    case 'pestcontrol':
      return const Color(0xFF84CC16); // Lime Green

    case 'appliancerepair':
    case 'appliance':
      return const Color(0xFF4F46E5); // Indigo Appliance

    case 'householditems':
    case 'household':
      return const Color(0xFF78350F); // Warm Earth Brown

    case 'foodsandbeverages':
    case 'foodbeverages':
    case 'food':
      return const Color(0xFFDC2626); // Crimson Dining

    case 'phonesandaccessories':
    case 'phonesaccessories':
    case 'phones':
      return const Color(0xFF14B8A6); // Modern Mint

    case 'other':
      return const Color(0xFF64748B); // Slate Grey

    default:
      return const Color(0xFF548C2F); // FindiPro Forest Green
  }
}