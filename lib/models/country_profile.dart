import 'package:flutter/foundation.dart';

/// Represents a standardized country profile within FindiPro.
@immutable
class CountryProfile {
  final String code;
  final String name;
  final String currency;
  final String currencySymbol;
  final String phonePrefix;
  final String flagEmoji;
  final String locale;

  const CountryProfile({
    required this.code,
    required this.name,
    required this.currency,
    required this.currencySymbol,
    required this.phonePrefix,
    this.flagEmoji = '',
    this.locale = 'en',
  });

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'currency': currency,
        'currency_symbol': currencySymbol,
        'phone_prefix': phonePrefix,
        'flag_emoji': flagEmoji,
        'locale': locale,
      };

  factory CountryProfile.fromMap(Map<String, dynamic> map) {
    return CountryProfile(
      code: (map['code'] ?? 'UG').toString().toUpperCase(),
      name: (map['name'] ?? 'Uganda').toString(),
      currency: (map['currency'] ?? 'UGX').toString().toUpperCase(),
      currencySymbol: (map['currency_symbol'] ?? 'USh').toString(),
      phonePrefix: (map['phone_prefix'] ?? '+256').toString(),
      flagEmoji: (map['flag_emoji'] ?? '🇺🇬').toString(),
      locale: (map['locale'] ?? 'en').toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountryProfile &&
          runtimeType == other.runtimeType &&
          code.toUpperCase() == other.code.toUpperCase();

  @override
  int get hashCode => code.toUpperCase().hashCode;

  @override
  String toString() => '$name ($code)';
}
