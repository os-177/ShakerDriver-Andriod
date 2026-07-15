import 'dart:async';
import 'package:geolocator/geolocator.dart';

import '../config.dart';
import 'api_service.dart';

enum LocationTrackingState { active, denied, error }

/// نفس منطق startLocationTracking / sendCurrentLocation في rep.js:
/// يرسل موقع المندوب كل 10 ثوانٍ لتتبعه من لوحة المالك.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Timer? _timer;
  final _stateController = StreamController<LocationTrackingState>.broadcast();

  /// استمع لهذا الـ Stream لعرض مؤشر حالة الموقع في الواجهة (زي 🧊 القديم)
  Stream<LocationTrackingState> get stateStream => _stateController.stream;

  void start() {
    _timer?.cancel();
    _sendOnce();
    _timer = Timer.periodic(
      Duration(seconds: ApiConfig.locationIntervalSeconds),
      (_) => _sendOnce(),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sendOnce() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _stateController.add(LocationTrackingState.denied);
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _stateController.add(LocationTrackingState.error);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _stateController.add(LocationTrackingState.active);
      await ApiService.instance.sendCurrentLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      _stateController.add(LocationTrackingState.error);
    }
  }

  void dispose() {
    _timer?.cancel();
    _stateController.close();
  }
}
