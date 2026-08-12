import 'package:flutter/material.dart';

IconData categoryIcon(String category) {
  switch (category.toLowerCase()) {
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
      return Icons.grass;

    case 'carpentry':
      return Icons.carpenter;

    case 'moving':
      return Icons.local_shipping;

    case 'beauty':
      return Icons.face_retouching_natural;

    case 'construction':
      return Icons.construction;

    case 'it & technology':
      return Icons.computer;

    default:
      return Icons.miscellaneous_services;
  }
}