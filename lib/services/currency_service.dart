import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyInfo {
  final String code; // e.g. 'UGX', 'USD', 'EUR', 'KES', 'GBP', 'AED'
  final String symbol; // e.g. 'UGX', '$', '€', 'KSh', '£', 'AED'
  final String country; // e.g. 'Uganda', 'United States', 'Kenya'
  final String countryCode; // e.g. 'UG', 'US', 'KE'
  final double rateToUsd; // 1 USD = X in this currency

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.country,
    required this.countryCode,
    required this.rateToUsd,
  });
}

class CurrencyService extends ChangeNotifier {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;

  static const CurrencyInfo defaultCurrency = CurrencyInfo(
    code: 'UGX',
    symbol: 'UGX',
    country: 'Uganda',
    countryCode: 'UG',
    rateToUsd: 3700.0,
  );

  // Standard benchmark exchange rates relative to 1 USD
  static final Map<String, CurrencyInfo> supportedCurrencies = {
    'UGX': const CurrencyInfo(code: 'UGX', symbol: 'UGX', country: 'Uganda', countryCode: 'UG', rateToUsd: 3700.0),
    'USD': const CurrencyInfo(code: 'USD', symbol: '\$', country: 'United States', countryCode: 'US', rateToUsd: 1.0),
    'EUR': const CurrencyInfo(code: 'EUR', symbol: '€', country: 'Europe', countryCode: 'EU', rateToUsd: 0.92),
    'GBP': const CurrencyInfo(code: 'GBP', symbol: '£', country: 'United Kingdom', countryCode: 'GB', rateToUsd: 0.78),
    'KES': const CurrencyInfo(code: 'KES', symbol: 'KSh', country: 'Kenya', countryCode: 'KE', rateToUsd: 130.0),
    'TZS': const CurrencyInfo(code: 'TZS', symbol: 'TSh', country: 'Tanzania', countryCode: 'TZ', rateToUsd: 2600.0),
    'RWF': const CurrencyInfo(code: 'RWF', symbol: 'RWF', country: 'Rwanda', countryCode: 'RW', rateToUsd: 1300.0),
    'NGN': const CurrencyInfo(code: 'NGN', symbol: '₦', country: 'Nigeria', countryCode: 'NG', rateToUsd: 1500.0),
    'ZAR': const CurrencyInfo(code: 'ZAR', symbol: 'R', country: 'South Africa', countryCode: 'ZA', rateToUsd: 18.0),
    'AED': const CurrencyInfo(code: 'AED', symbol: 'AED', country: 'United Arab Emirates', countryCode: 'AE', rateToUsd: 3.67),
    'CAD': const CurrencyInfo(code: 'CAD', symbol: 'CA\$', country: 'Canada', countryCode: 'CA', rateToUsd: 1.36),
    'AUD': const CurrencyInfo(code: 'AUD', symbol: 'A\$', country: 'Australia', countryCode: 'AU', rateToUsd: 1.52),
    'INR': const CurrencyInfo(code: 'INR', symbol: '₹', country: 'India', countryCode: 'IN', rateToUsd: 83.5),
  };

  CurrencyInfo _currentCurrency = defaultCurrency;
  bool _isDetecting = false;

  CurrencyInfo get currentCurrency => _currentCurrency;
  String get currencyCode => _currentCurrency.code;
  String get currencySymbol => _currentCurrency.symbol;

  CurrencyService._internal() {
    _initCurrency();
  }

  Future<void> _initCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString('user_currency_code');
      if (savedCode != null && supportedCurrencies.containsKey(savedCode)) {
        _currentCurrency = supportedCurrencies[savedCode]!;
        notifyListeners();
        return;
      }
    } catch (_) {}

    // Auto-detect from IP in background
    autoDetectFromIp();
  }

  /// Automatically detects the user's country and local currency from their IP address.
  Future<void> autoDetectFromIp() async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      debugPrint('>>> [CurrencyService] Auto-detecting country & currency from IP...');
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final countryCode = (data['country_code'] ?? '').toString().toUpperCase();
        final currencyCode = (data['currency'] ?? '').toString().toUpperCase();
        final countryName = (data['country_name'] ?? '').toString();

        debugPrint('>>> [CurrencyService] IP Location: $countryName ($countryCode), Currency: $currencyCode');

        if (supportedCurrencies.containsKey(currencyCode)) {
          await setCurrency(currencyCode);
          _isDetecting = false;
          return;
        }

        // Fallback matching by country code
        if (countryCode == 'UG') {
          await setCurrency('UGX');
        } else if (countryCode == 'KE') {
          await setCurrency('KES');
        } else if (countryCode == 'TZ') {
          await setCurrency('TZS');
        } else if (countryCode == 'RW') {
          await setCurrency('RWF');
        } else if (countryCode == 'NG') {
          await setCurrency('NGN');
        } else if (countryCode == 'ZA') {
          await setCurrency('ZAR');
        } else if (countryCode == 'GB') {
          await setCurrency('GBP');
        } else if (countryCode == 'AE') {
          await setCurrency('AED');
        } else if (countryCode == 'US') {
          await setCurrency('USD');
        } else if (['FR', 'DE', 'ES', 'IT', 'NL', 'BE', 'PT', 'AT', 'IE', 'FI', 'GR'].contains(countryCode)) {
          await setCurrency('EUR');
        }
      }
    } catch (e) {
      debugPrint('>>> [CurrencyService] Note during IP auto-detection: $e');
    } finally {
      _isDetecting = false;
    }
  }

  /// Sets a specific currency manually.
  Future<void> setCurrency(String code) async {
    final upper = code.toUpperCase();
    if (!supportedCurrencies.containsKey(upper)) return;

    _currentCurrency = supportedCurrencies[upper]!;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_currency_code', upper);
    } catch (_) {}
  }

  /// Converts an amount given in baseline UGX to the active currency.
  double convertFromUgx(num amountInUgx) {
    if (_currentCurrency.code == 'UGX') return amountInUgx.toDouble();
    final ugxRateToUsd = supportedCurrencies['UGX']!.rateToUsd; // 3700
    final usdAmount = amountInUgx / ugxRateToUsd;
    final converted = usdAmount * _currentCurrency.rateToUsd;
    return converted;
  }

  /// Converts an amount in the active currency back to baseline UGX for storage.
  double convertToUgx(num amountInActiveCurrency) {
    if (_currentCurrency.code == 'UGX') return amountInActiveCurrency.toDouble();
    final usdAmount = amountInActiveCurrency / _currentCurrency.rateToUsd;
    final ugxRateToUsd = supportedCurrencies['UGX']!.rateToUsd; // 3700
    return usdAmount * ugxRateToUsd;
  }

  /// Formats a price value with currency symbol.
  String formatPrice(num amountInUgx) {
    final converted = convertFromUgx(amountInUgx);
    if (_currentCurrency.code == 'UGX' || _currentCurrency.code == 'TZS' || _currentCurrency.code == 'RWF') {
      return '${_currentCurrency.symbol} ${_formatWithCommas(converted.round())}';
    } else {
      final str = converted == converted.roundToDouble()
          ? converted.toStringAsFixed(0)
          : converted.toStringAsFixed(2);
      return '${_currentCurrency.symbol}$str';
    }
  }

  /// Formats a min - max range into localized currency string (e.g. "$25 - $50" or "UGX 50,000 - 100,000").
  String formatRange(num minUgx, num maxUgx) {
    final minFormatted = formatPrice(minUgx);
    final maxFormatted = formatPrice(maxUgx);
    return '$minFormatted - $maxFormatted';
  }

  static String _formatWithCommas(num n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

