import '../../models/country_profile.dart';

/// Centralized configuration for all countries supported by FindiPro.
class CountryConfig {
  static const CountryProfile defaultCountry = CountryProfile(
    code: 'UG',
    name: 'Uganda',
    currency: 'UGX',
    currencySymbol: 'USh',
    phonePrefix: '+256',
    flagEmoji: '🇺🇬',
    locale: 'en_UG',
  );

  static const List<CountryProfile> supportedCountries = [
    defaultCountry,
    CountryProfile(
      code: 'KE',
      name: 'Kenya',
      currency: 'KES',
      currencySymbol: 'KSh',
      phonePrefix: '+254',
      flagEmoji: '🇰🇪',
      locale: 'en_KE',
    ),
    CountryProfile(
      code: 'TZ',
      name: 'Tanzania',
      currency: 'TZS',
      currencySymbol: 'TSh',
      phonePrefix: '+255',
      flagEmoji: '🇹🇿',
      locale: 'sw_TZ',
    ),
    CountryProfile(
      code: 'RW',
      name: 'Rwanda',
      currency: 'RWF',
      currencySymbol: 'FRw',
      phonePrefix: '+250',
      flagEmoji: '🇷🇼',
      locale: 'rw_RW',
    ),
    CountryProfile(
      code: 'NG',
      name: 'Nigeria',
      currency: 'NGN',
      currencySymbol: '₦',
      phonePrefix: '+234',
      flagEmoji: '🇳🇬',
      locale: 'en_NG',
    ),
    CountryProfile(
      code: 'GH',
      name: 'Ghana',
      currency: 'GHS',
      currencySymbol: 'GH₵',
      phonePrefix: '+233',
      flagEmoji: '🇬🇭',
      locale: 'en_GH',
    ),
    CountryProfile(
      code: 'ZA',
      name: 'South Africa',
      currency: 'ZAR',
      currencySymbol: 'R',
      phonePrefix: '+27',
      flagEmoji: '🇿🇦',
      locale: 'en_ZA',
    ),
    CountryProfile(
      code: 'US',
      name: 'United States',
      currency: 'USD',
      currencySymbol: '\$',
      phonePrefix: '+1',
      flagEmoji: '🇺🇸',
      locale: 'en_US',
    ),
    CountryProfile(
      code: 'GB',
      name: 'United Kingdom',
      currency: 'GBP',
      currencySymbol: '£',
      phonePrefix: '+44',
      flagEmoji: '🇬🇧',
      locale: 'en_GB',
    ),
  ];

  static final Map<String, CountryProfile> _countryMap = {
    for (final c in supportedCountries) c.code.toUpperCase(): c,
  };

  /// Returns true if the country code is in the supported list.
  static bool isSupported(String? code) {
    if (code == null) return false;
    return _countryMap.containsKey(code.trim().toUpperCase());
  }

  /// Resolves a country profile by country code, falling back to Uganda default.
  static CountryProfile getCountry(String? code) {
    if (code == null || code.trim().isEmpty) return defaultCountry;
    return _countryMap[code.trim().toUpperCase()] ?? defaultCountry;
  }
}
