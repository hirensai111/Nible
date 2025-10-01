// Create this file: lib/services/delivery_service.dart
import 'dart:async';
import 'package:flutter/material.dart';

class DeliveryService extends ChangeNotifier {
  static final DeliveryService _instance = DeliveryService._internal();
  factory DeliveryService() => _instance;
  DeliveryService._internal();

  bool _isDelivering = false;
  DateTime? _startTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  bool get isDelivering => _isDelivering;
  Duration get elapsed => _elapsed;
  DateTime? get startTime => _startTime;

  void startDelivering() {
    _isDelivering = true;
    _startTime = DateTime.now();
    _elapsed = Duration.zero;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startTime != null) {
        _elapsed = DateTime.now().difference(_startTime!);
        notifyListeners();
      }
    });

    notifyListeners();
  }

  void stopDelivering() {
    _isDelivering = false;
    _timer?.cancel();
    _startTime = null;
    _elapsed = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
