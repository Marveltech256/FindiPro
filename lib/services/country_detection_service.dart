import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/country_config.dart';
import '../models/country_profile.dart';
import 'location_service.dart';

/// The origin source of a country detection signal.
enum DetectionSource {
  gps,
  ipGeo,
  systemLocale,
  cachedPreference,
  fallback,
}

/// A structured snapshot of a detected country signal.
@immutable
class DetectionSignal {
  final String countryCode;
  final String? countryName;
  final String? city;
  final String? region;
  final DetectionSource source;
  final double confidence;
  final DateTime detectedAt;

  const DetectionSignal({
    required this.countryCode,
    this.countryName,
    this.city,
    this.region,
    required this.source,
    required this.confidence,
    required this.detectedAt,
  });

  Map<String, dynamic> toMap() => {
        'country_code': countryCode,
        'country_name': countryName,
        'city': city,
        'region': region,
        'source': source.name,
        'confidence': confidence,
        'detected_at': detectedAt.toIso8601String(),
      };

  factory DetectionSignal.fromMap(Map<String, dynamic> map) {
    DetectionSource parseSource(String? s) {
      for (final src in DetectionSource.values) {
        if (src.name == s) return src;
      }
      return DetectionSource.fallback;
    }

    return DetectionSignal(
      countryCode: (map['country_code'] ?? 'UG').toString().toUpperCase(),
      countryName: map['country_name']?.toString(),
      city: map['city']?.toString(),
      region: map['region']?.toString(),
      source: parseSource(map['source']?.toString()),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
      detectedAt: DateTime.tryParse(map['detected_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'DetectionSignal($countryCode via ${source.name}, confidence: ${(confidence * 100).round()}%, city: $city)';
}

/// Automated Multi-Signal Country Detection Service for FindiPro Global (Phase 3).
///
/// Evaluates location signals hierarchically:
/// 1. GPS Coordinates + Reverse Geocoding (Highest fidelity, ~0.95 confidence)
/// 2. IP-derived Geolocation (Network fallback, ~0.80 confidence)
/// 3. Device System Locale / Region (Platform fallback, ~0.50 confidence)
/// 4. Local Cached Preference (Historical fallback)
/// 5. Global Default Baseline ('UG' / Uganda, 100% backward-compatible)
class CountryDetectionService extends ChangeNotifier {
  static final CountryDetectionService _instance = CountryDetectionService._internal();
  factory CountryDetectionService() => _instance;

  static const String _prefKeyDetectedCountry = 'findipro_detected_country_code';
  static const String _prefKeyDetectedCity = 'findipro_detected_city';
  static const String _prefKeyDetectedRegion = 'findipro_detected_region';
  static const String _prefKeyDetectedSource = 'findipro_detected_source';
  static const String _prefKeyDetectedAt = 'findipro_detected_at_timestamp';

  CountryProfile _detectedCountry = CountryConfig.defaultCountry;
  DetectionSignal? _latestSignal;
  bool _isDetecting = false;
  String? _detectedCity;
  String? _detectedRegion;

  CountryProfile get detectedCountry => _detectedCountry;
  String get detectedCountryCode => _detectedCountry.code;
  DetectionSignal? get latestSignal => _latestSignal;
  bool get isDetecting => _isDetecting;
  String? get detectedCity => _detectedCity;
  String? get detectedRegion => _detectedRegion;

  CountryDetectionService._internal() {
    _loadCachedDetection();
  }

  /// Loads cached detection data from SharedPreferences for instantaneous startup.
  Future<void> _loadCachedDetection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedCode = prefs.getString(_prefKeyDetectedCountry);
      if (cachedCode != null && cachedCode.isNotEmpty) {
        _detectedCountry = CountryConfig.getCountry(cachedCode);
        _detectedCity = prefs.getString(_prefKeyDetectedCity);
        _detectedRegion = prefs.getString(_prefKeyDetectedRegion);

        final sourceStr = prefs.getString(_prefKeyDetectedSource) ?? 'cachedPreference';
        final atStr = prefs.getString(_prefKeyDetectedAt);

        DetectionSource parsedSource = DetectionSource.cachedPreference;
        for (final s in DetectionSource.values) {
          if (s.name == sourceStr) {
            parsedSource = s;
            break;
          }
        }

        _latestSignal = DetectionSignal(
          countryCode: _detectedCountry.code,
          countryName: _detectedCountry.name,
          city: _detectedCity,
          region: _detectedRegion,
          source: parsedSource,
          confidence: 0.60,
          detectedAt: DateTime.tryParse(atStr ?? '') ?? DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('>>> [CountryDetectionService] Cache load note: $e');
    }
  }

  /// Initiates multi-signal country detection in the background.
  /// Does not block the UI thread.
  Future<DetectionSignal> detectCountry({bool forceRefresh = false}) async {
    if (_isDetecting) {
      return _latestSignal ??
          DetectionSignal(
            countryCode: _detectedCountry.code,
            source: DetectionSource.cachedPreference,
            confidence: 0.5,
            detectedAt: DateTime.now(),
          );
    }

    _isDetecting = true;
    notifyListeners();

    try {
      // 1. SIGNAL 1: GPS Coordinates + Reverse Geocoding
      final gpsSignal = await _detectViaGps();
      if (gpsSignal != null && gpsSignal.confidence >= 0.85) {
        await _applySignal(gpsSignal);
        return gpsSignal;
      }

      // 2. SIGNAL 2: IP-based Geolocation
      final ipSignal = await _detectViaIp();
      if (ipSignal != null && ipSignal.confidence >= 0.75) {
        await _applySignal(ipSignal);
        return ipSignal;
      }

      // 3. SIGNAL 3: Device System Locale
      final localeSignal = _detectViaSystemLocale();
      if (localeSignal != null && CountryConfig.isSupported(localeSignal.countryCode)) {
        await _applySignal(localeSignal);
        return localeSignal;
      }

      // 4. SIGNAL 4: Fallback to existing signal or default Uganda
      final fallbackSignal = _latestSignal ??
          DetectionSignal(
            countryCode: CountryConfig.defaultCountry.code,
            countryName: CountryConfig.defaultCountry.name,
            source: DetectionSource.fallback,
            confidence: 0.20,
            detectedAt: DateTime.now(),
          );

      await _applySignal(fallbackSignal);
      return fallbackSignal;
    } catch (e) {
      debugPrint('>>> [CountryDetectionService] Detection error: $e');
      final fallbackSignal = DetectionSignal(
        countryCode: CountryConfig.defaultCountry.code,
        countryName: CountryConfig.defaultCountry.name,
        source: DetectionSource.fallback,
        confidence: 0.10,
        detectedAt: DateTime.now(),
      );
      await _applySignal(fallbackSignal);
      return fallbackSignal;
    } finally {
      _isDetecting = false;
      notifyListeners();
    }
  }

  /// Detects country via GPS coordinates and reverse geocoding.
  Future<DetectionSignal?> _detectViaGps() async {
    try {
      final position = await LocationService().getCurrentLocation();
      if (position == null) return null;

      // Reverse geocode with a 3.5s timeout
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(milliseconds: 3500));

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final isoCode = place.isoCountryCode?.trim().toUpperCase();

        if (isoCode != null && isoCode.isNotEmpty && isoCode.length == 2) {
          debugPrint('>>> [CountryDetectionService] GPS Geocoded: $isoCode (${place.country}), City: ${place.locality}');
          return DetectionSignal(
            countryCode: isoCode,
            countryName: place.country,
            city: place.locality ?? place.subAdministrativeArea,
            region: place.administrativeArea,
            source: DetectionSource.gps,
            confidence: 0.95,
            detectedAt: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint('>>> [CountryDetectionService] GPS detection skipped/failed: $e');
    }
    return null;
  }

  /// Detects country via fast IP geolocation service with strict timeout.
  Future<DetectionSignal?> _detectViaIp() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(milliseconds: 3500));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final countryCode = (data['country_code'] ?? '').toString().toUpperCase();
        final countryName = data['country_name']?.toString();
        final city = data['city']?.toString();
        final region = data['region']?.toString();

        if (countryCode.isNotEmpty && countryCode.length == 2) {
          debugPrint('>>> [CountryDetectionService] IP Geocoded: $countryCode ($countryName), City: $city');
          return DetectionSignal(
            countryCode: countryCode,
            countryName: countryName,
            city: city,
            region: region,
            source: DetectionSource.ipGeo,
            confidence: 0.80,
            detectedAt: DateTime.now(),
          );
        }
      }
    } catch (e) {
      debugPrint('>>> [CountryDetectionService] IP detection skipped/failed: $e');
    }
    return null;
  }

  /// Detects country code from the device operating system's locale setting.
  DetectionSignal? _detectViaSystemLocale() {
    try {
      final locale = PlatformDispatcher.instance.locale;
      final countryCode = locale.countryCode?.trim().toUpperCase();

      if (countryCode != null && countryCode.length == 2) {
        debugPrint('>>> [CountryDetectionService] System Locale Detected: $countryCode');
        return DetectionSignal(
          countryCode: countryCode,
          source: DetectionSource.systemLocale,
          confidence: 0.50,
          detectedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('>>> [CountryDetectionService] System locale check note: $e');
    }
    return null;
  }

  /// Applies a resolved signal, updates state, and persists to local cache.
  Future<void> _applySignal(DetectionSignal signal) async {
    _latestSignal = signal;
    _detectedCountry = CountryConfig.getCountry(signal.countryCode);
    _detectedCity = signal.city;
    _detectedRegion = signal.region;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyDetectedCountry, _detectedCountry.code);
      if (signal.city != null) {
        await prefs.setString(_prefKeyDetectedCity, signal.city!);
      }
      if (signal.region != null) {
        await prefs.setString(_prefKeyDetectedRegion, signal.region!);
      }
      await prefs.setString(_prefKeyDetectedSource, signal.source.name);
      await prefs.setString(_prefKeyDetectedAt, signal.detectedAt.toIso8601String());
    } catch (e) {
      debugPrint('>>> [CountryDetectionService] Prefs save note: $e');
    }

    notifyListeners();
  }
}
