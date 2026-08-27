import '../models/user_model.dart';

class PlanPrice {
  final String plan;
  final String region;
  final String currency;
  final String currencySymbol;
  final num monthlyPrice;
  final num yearlyPrice;
  final num standardYearlyTotal;
  final int discountPercent;

  const PlanPrice({
    required this.plan,
    required this.region,
    required this.currency,
    required this.currencySymbol,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.standardYearlyTotal,
    this.discountPercent = 20,
  });

  String get formattedMonthly {
    if (monthlyPrice == 0) return 'Free';
    if (currency == 'UGX') {
      return 'UGX ${_formatNumber(monthlyPrice.round())}/month';
    } else if (currency == 'EUR') {
      final str = monthlyPrice == monthlyPrice.roundToDouble()
          ? monthlyPrice.toStringAsFixed(0)
          : monthlyPrice.toStringAsFixed(2);
      return '€$str/month';
    } else {
      final str = monthlyPrice == monthlyPrice.roundToDouble()
          ? monthlyPrice.toStringAsFixed(0)
          : monthlyPrice.toStringAsFixed(2);
      return '\$$str/month';
    }
  }

  String get formattedYearly {
    if (yearlyPrice == 0) return 'Free';
    if (currency == 'UGX') {
      return 'UGX ${_formatNumber(yearlyPrice.round())}/year';
    } else if (currency == 'EUR') {
      final str = yearlyPrice == yearlyPrice.roundToDouble()
          ? yearlyPrice.toStringAsFixed(0)
          : yearlyPrice.toStringAsFixed(2);
      return '€$str/year';
    } else {
      final str = yearlyPrice == yearlyPrice.roundToDouble()
          ? yearlyPrice.toStringAsFixed(0)
          : yearlyPrice.toStringAsFixed(2);
      return '\$$str/year';
    }
  }

  String get formattedSaving {
    if (yearlyPrice == 0) return '';
    return 'Save $discountPercent%';
  }

  static String _formatNumber(num n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

class ProviderEntitlementService {
  static const String supportWhatsApp = '+256763294426';

  // Product identifiers for subscription architectures
  static const String verifiedMonthlyProductId = 'findipro_verified_monthly';
  static const String verifiedYearlyProductId = 'findipro_verified_yearly';
  static const String premiumMonthlyProductId = 'findipro_premium_monthly';
  static const String premiumYearlyProductId = 'findipro_premium_yearly';

  /// Whether the user is on the free Basic plan (or expired from a paid tier).
  static bool isBasic(UserModel user) {
    if (!user.isProvider) return true;
    return user.effectivePlan == 'basic';
  }

  /// Whether the provider is entitled to Verified benefits.
  static bool isVerified(UserModel user) {
    if (!user.isProvider) return false;
    return user.isVerifiedBadge;
  }

  /// Whether the provider is entitled to Premium benefits.
  static bool isPremium(UserModel user) {
    if (!user.isProvider) return false;
    return user.isPremiumBadge;
  }

  /// Maximum allowed portfolio / work images by plan:
  /// - Basic: 2
  /// - Verified: 5
  /// - Premium: 10
  static int getPortfolioImageLimit(UserModel user) {
    if (isPremium(user)) return 10;
    if (isVerified(user)) return 5;
    return 2;
  }

  /// Checks whether provider can upload an additional portfolio image.
  static bool canUploadPortfolioImage(UserModel user, int currentImageCount) {
    return currentImageCount < getPortfolioImageLimit(user);
  }

  /// Whether provider receives priority ranking in marketplace queries.
  static bool hasPriorityRanking(UserModel user) {
    return isPremium(user);
  }

  /// Whether provider receives featured badge / banner placement.
  static bool hasFeaturedPlacement(UserModel user) {
    return isPremium(user);
  }

  /// Whether provider can view detailed analytics.
  static bool hasAnalytics(UserModel user) {
    return isPremium(user);
  }

  /// Whether provider has access to promotional / boost tools.
  static bool hasPromotionalTools(UserModel user) {
    return isPremium(user);
  }

  /// Whether provider has unlimited service listing capacity.
  static bool hasUnlimitedServices(UserModel user) {
    return isPremium(user);
  }

  /// Whether provider has access to priority / instant support.
  static bool hasPrioritySupport(UserModel user) {
    return isVerified(user) || isPremium(user);
  }

  /// Automatically detects the pricing region in preferred order:
  /// 1. GPS coordinates (latitude, longitude)
  /// 2. Stored user subscription region / profile location
  /// 3. Location string keyword matches
  /// 4. Safe default fallback: 'Africa'
  static String detectRegion({
    double? latitude,
    double? longitude,
    String? location,
    String? storedRegion,
  }) {
    // 1. Check GPS coordinates if available
    if (latitude != null && longitude != null) {
      // USA bounding box approx
      if ((latitude >= 24.0 && latitude <= 50.0 && longitude >= -125.0 && longitude <= -66.0) ||
          (latitude >= 18.0 && latitude <= 23.0 && longitude >= -161.0 && longitude <= -154.0) || // Hawaii
          (latitude >= 51.0 && latitude <= 72.0 && longitude >= -170.0 && longitude <= -130.0)) { // Alaska
        return 'USA';
      }
      // Europe bounding box approx
      if (latitude >= 35.0 && latitude <= 72.0 && longitude >= -25.0 && longitude <= 45.0) {
        return 'Europe';
      }
      // Africa bounding box approx
      if (latitude >= -35.0 && latitude <= 38.0 && longitude >= -18.0 && longitude <= 52.0) {
        return 'Africa';
      }
    }

    // 2. Stored subscription region preference
    if (storedRegion != null && storedRegion.isNotEmpty) {
      final s = storedRegion.toLowerCase();
      if (s.contains('europe') || s.contains('eur')) return 'Europe';
      if (s.contains('usa') || s.contains('united states') || s.contains('usd')) return 'USA';
      if (s.contains('africa') || s.contains('ugx')) return 'Africa';
    }

    // 3. Location string keyword match
    if (location != null && location.isNotEmpty) {
      final loc = location.toLowerCase();
      final europeKeywords = [
        'uk', 'united kingdom', 'great britain', 'england', 'london',
        'germany', 'france', 'paris', 'berlin', 'italy', 'rome',
        'spain', 'madrid', 'netherlands', 'amsterdam', 'sweden',
        'norway', 'denmark', 'poland', 'ireland', 'europe', 'eu',
        'belgium', 'brussels', 'austria', 'vienna', 'switzerland', 'zurich',
        'portugal', 'lisbon', 'greece', 'athens', 'finland', 'helsinki'
      ];
      for (final k in europeKeywords) {
        if (loc.contains(k)) return 'Europe';
      }

      final usaKeywords = [
        'usa', 'united states', 'u.s.', 'america', 'california',
        'texas', 'new york', 'florida', 'chicago', 'los angeles',
        'seattle', 'san francisco', 'miami', 'boston', 'austin',
        'atlanta', 'dallas', 'houston', 'washington', 'denver'
      ];
      for (final k in usaKeywords) {
        if (loc.contains(k)) return 'USA';
      }

      final africaKeywords = [
        'uganda', 'kampala', 'entebbe', 'jinja', 'kenya', 'nairobi',
        'mombasa', 'tanzania', 'dar es salaam', 'rwanda', 'kigali',
        'nigeria', 'lagos', 'abuja', 'ghana', 'accra', 'south africa',
        'johannesburg', 'cape town', 'africa'
      ];
      for (final k in africaKeywords) {
        if (loc.contains(k)) return 'Africa';
      }
    }

    // 4. Default safe fallback is Africa (UGX)
    return 'Africa';
  }

  /// Returns the pricing tier details for a plan and region.
  /// Monthly prices:
  /// - Africa (UGX): Basic Free, Verified UGX 10,000/mo, Premium UGX 25,000/mo
  /// - Europe (EUR): Basic Free, Verified €9.99/mo, Premium €24.99/mo
  /// - USA (USD): Basic Free, Verified $10/mo, Premium $25/mo
  /// Yearly pricing is dynamically calculated: monthlyPrice * 12 * 0.80 (20% discount).
  static PlanPrice getPlanPrice({
    required String plan,
    required String region,
  }) {
    final normPlan = plan.toLowerCase();
    final normRegion = region.toLowerCase();

    num monthlyPrice = 0;
    String currency = 'UGX';
    String currencySymbol = 'UGX';
    String resolvedRegion = 'Africa';

    if (normRegion == 'europe') {
      resolvedRegion = 'Europe';
      currency = 'EUR';
      currencySymbol = '€';
      if (normPlan == 'verified') {
        monthlyPrice = 9.99;
      } else if (normPlan == 'premium') {
        monthlyPrice = 24.99;
      }
    } else if (normRegion == 'usa') {
      resolvedRegion = 'USA';
      currency = 'USD';
      currencySymbol = '\$';
      if (normPlan == 'verified') {
        monthlyPrice = 10;
      } else if (normPlan == 'premium') {
        monthlyPrice = 25;
      }
    } else {
      // Default: Africa / Uganda
      resolvedRegion = 'Africa';
      currency = 'UGX';
      currencySymbol = 'UGX';
      if (normPlan == 'verified') {
        monthlyPrice = 10000;
      } else if (normPlan == 'premium') {
        monthlyPrice = 25000;
      }
    }

    // Dynamic 20% discount calculation from monthly price
    final standardYearlyTotal = monthlyPrice is int
        ? monthlyPrice * 12
        : double.parse((monthlyPrice * 12).toStringAsFixed(2));

    final num yearlyDiscounted;
    if (monthlyPrice is int || monthlyPrice == monthlyPrice.roundToDouble()) {
      yearlyDiscounted = (monthlyPrice * 12 * 0.80).round();
    } else {
      yearlyDiscounted = double.parse((monthlyPrice * 12 * 0.80).toStringAsFixed(2));
    }

    return PlanPrice(
      plan: normPlan,
      region: resolvedRegion,
      currency: currency,
      currencySymbol: currencySymbol,
      monthlyPrice: monthlyPrice,
      yearlyPrice: yearlyDiscounted,
      standardYearlyTotal: standardYearlyTotal,
      discountPercent: 20,
    );
  }
}
