import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeatherSnapshot {
  final double tempC;
  final int humidity;
  final String condition;
  final double? pm25;
  final int? usAqi;
  final String aqiCategory;

  WeatherSnapshot({
    required this.tempC,
    required this.humidity,
    required this.condition,
    this.pm25,
    this.usAqi,
    required this.aqiCategory,
  });

  Map<String, dynamic> toJson() => {
        'tempC': tempC,
        'humidity': humidity,
        'condition': condition,
        'pm25': pm25,
        'usAqi': usAqi,
        'aqiCategory': aqiCategory,
      };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> j) => WeatherSnapshot(
        tempC: (j['tempC'] as num).toDouble(),
        humidity: j['humidity'] as int,
        condition: j['condition'] as String,
        pm25: (j['pm25'] as num?)?.toDouble(),
        usAqi: j['usAqi'] as int?,
        aqiCategory: j['aqiCategory'] as String? ?? 'Unknown',
      );

  String get summary {
    final parts = <String>['${tempC.round()}°C', condition, '$humidity% humidity'];
    if (usAqi != null) parts.add('AQI $usAqi ($aqiCategory)');
    return parts.join(', ');
  }
}

class WeatherService {
  WeatherService._();
  static final instance = WeatherService._();

  final snapshot = ValueNotifier<WeatherSnapshot?>(null);
  static const _dataKey = 'weather_snapshot';
  static const _timeKey = 'weather_fetched_at';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dataKey);
    final fetchedAtMs = prefs.getInt(_timeKey);
    if (raw != null && fetchedAtMs != null) {
      snapshot.value = WeatherSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(fetchedAtMs));
      if (age < const Duration(hours: 1)) return; // still fresh enough
    }
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final pos = await _getPosition();
      if (pos == null) return; // permission denied / location off — leave snapshot as-is

      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current=temperature_2m,relative_humidity_2m,weather_code',
      );
      final aqiUri = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${pos.latitude}&longitude=${pos.longitude}&current=pm2_5,us_aqi',
      );

      final results = await Future.wait([http.get(weatherUri), http.get(aqiUri)]);
      final weatherRes = results[0];
      final aqiRes = results[1];
      if (weatherRes.statusCode != 200) return;

      final weatherJson = jsonDecode(weatherRes.body) as Map<String, dynamic>;
      final current = weatherJson['current'] as Map<String, dynamic>;
      final tempC = (current['temperature_2m'] as num).toDouble();
      final humidity = (current['relative_humidity_2m'] as num).toInt();
      final code = (current['weather_code'] as num).toInt();

      double? pm25;
      int? usAqi;
      if (aqiRes.statusCode == 200) {
        final aqiJson = jsonDecode(aqiRes.body) as Map<String, dynamic>;
        final aqiCurrent = aqiJson['current'] as Map<String, dynamic>?;
        pm25 = (aqiCurrent?['pm2_5'] as num?)?.toDouble();
        usAqi = (aqiCurrent?['us_aqi'] as num?)?.toInt();
      }

      final snap = WeatherSnapshot(
        tempC: tempC,
        humidity: humidity,
        condition: _describeCode(code),
        pm25: pm25,
        usAqi: usAqi,
        aqiCategory: _aqiCategory(usAqi),
      );
      snapshot.value = snap;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dataKey, jsonEncode(snap.toJson()));
      await prefs.setInt(_timeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Weather refresh failed: $e');
    }
  }

  Future<Position?> _getPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
    } catch (e) {
      debugPrint('Could not get location: $e');
      return null;
    }
  }

  String _describeCode(int code) {
    if (code == 0) return 'clear sky';
    if (code <= 2) return 'partly cloudy';
    if (code == 3) return 'overcast';
    if (code == 45 || code == 48) return 'foggy/hazy';
    if (code >= 51 && code <= 57) return 'drizzle';
    if (code >= 61 && code <= 67) return 'rain';
    if (code >= 71 && code <= 77) return 'snow';
    if (code >= 80 && code <= 82) return 'rain showers';
    if (code >= 95) return 'thunderstorm';
    return 'variable conditions';
  }

  String _aqiCategory(int? aqi) {
    if (aqi == null) return 'Unknown';
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive Groups';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }
}