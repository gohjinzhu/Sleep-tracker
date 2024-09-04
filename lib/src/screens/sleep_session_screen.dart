import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:light/light.dart';
import '../models/sleep_data.dart';
import 'session_detail_screen.dart';

class SleepSessionScreen extends StatefulWidget {
  final SleepData sleepData;
  final Function(SleepData) onSessionEnd;

  const SleepSessionScreen({
    super.key, 
    required this.sleepData, 
    required this.onSessionEnd
  });

  @override
  State<SleepSessionScreen> createState() => _SleepSessionScreenState();
}

class _SleepSessionScreenState extends State<SleepSessionScreen> {
  static const double GRAVITY = 9.81; // m/s^2
  static const Duration SAMPLE_PERIOD = Duration(milliseconds: 500); // 10 Hz

  late Timer _timer;
  late Duration _elapsed;
  List<double> accelerometerValues = [];
  List<int> lightValues = [];
  Light? _light;
  StreamSubscription? _lightSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  String _lightDescription = "Analyzing light...";
  IconData _lightIcon = Icons.lightbulb_outline;
  bool _sessionEnded = false;
  DateTime _lastSampleTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _elapsed = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
    _startDataCollection();
    _initializeLightSensor();
  }

  void _updateTimer(Timer timer) {
    if (!_sessionEnded) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.sleepData.startTime);
      });
    }
  }

  void _startDataCollection() {
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      final now = DateTime.now();
      if (now.difference(_lastSampleTime) >= SAMPLE_PERIOD) {
        double magnitude = _calculateMagnitude(event.x, event.y, event.z);
        double movement = _calculateMovement(magnitude);
        accelerometerValues.add(movement);
        print('Accelerometer movement: $movement');  // Log accelerometer data
        _lastSampleTime = now;
      }
    });
  }

  void _initializeLightSensor() async {
    _light = Light();
    try {
      _lightSubscription = _light?.lightSensorStream.listen((int luxValue) {
        lightValues.add(luxValue);
        _updateLightInfo(luxValue);
        print('Light: $luxValue');  // Log light data
      });
    } on LightException catch (e) {
      print('Light sensor error: $e');
    }
  }

  void _updateLightInfo(int luxValue) {
    setState(() {
      if (luxValue < 5) {
        _lightDescription = "Perfect darkness for deep sleep";
        _lightIcon = Icons.nightlight_round;
      } else if (luxValue < 20) {
        _lightDescription = "Good darkness for sleep";
        _lightIcon = Icons.nightlight;
      } else if (luxValue < 50) {
        _lightDescription = "Dim light, consider darkening the room";
        _lightIcon = Icons.brightness_low;
      } else {
        _lightDescription = "Too bright for optimal sleep";
        _lightIcon = Icons.brightness_high;
      }
    });
  }

  double _calculateMagnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  double _calculateMovement(double magnitude) {
    // Calculate the difference from Earth's gravity
    return (magnitude - GRAVITY).abs();
  }

  @override
  void dispose() {
    _timer.cancel();
    _lightSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _showConfirmationDialog(String action) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm $action'),
          content: Text('Are you sure you want to $action the sleep session?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _endSession() async {
    if (!_sessionEnded) {
      bool confirmed = await _showConfirmationDialog('end');
      if (confirmed) {
        setState(() {
          _sessionEnded = true;
        });
        widget.sleepData.endSession(
          accelerometerData: accelerometerValues,
          lightData: lightValues,
        );
        widget.onSessionEnd(widget.sleepData);
        
        // Log collected data
        print('Session ended. Collected data:');
        print('Accelerometer data: $accelerometerValues');
        print('Light data: $lightValues');
        
        // Use Future.delayed to ensure setState has completed
        Future.delayed(Duration.zero, () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SessionDetailScreen(sleepData: widget.sleepData),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_sessionEnded) {
          bool confirmed = await _showConfirmationDialog('exit');
          if (confirmed) {
            _endSession();
          }
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sleep Session'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (!_sessionEnded) {
                bool confirmed = await _showConfirmationDialog('exit');
                if (confirmed) {
                  _endSession();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _sessionEnded ? 'Session Ended' : 'Sleep in progress',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 20),
              Text(
                _formatDuration(_elapsed),
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              Icon(_lightIcon, size: 48),
              Text(_lightDescription),
              const SizedBox(height: 40),
              if (!_sessionEnded)
                ElevatedButton(
                  onPressed: _endSession,
                  child: const Text('End Sleep Session'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
