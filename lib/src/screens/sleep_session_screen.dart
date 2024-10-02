import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/sleep_tracking_service.dart';
import '../models/sleep_data.dart';
import 'session_detail_screen.dart';

class SleepSessionScreen extends StatefulWidget {
  final SleepData sleepData;
  final Function(SleepData) handleSessionEnd;

  const SleepSessionScreen(
      {super.key, required this.sleepData, required this.handleSessionEnd});

  @override
  State<SleepSessionScreen> createState() => _SleepSessionScreenState();
}

class _SleepSessionScreenState extends State<SleepSessionScreen> {
  late Timer? _timer;
  late Timer? _lightDataTimer;
  late StreamSubscription? _serviceSubscription;
  Duration _elapsed = Duration.zero;
  final FlutterBackgroundService _backgroundService =
      FlutterBackgroundService();
  String _lightDescription = "Analyzing light...";
  IconData _lightIcon = Icons.lightbulb_outline;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
    _startBackgroundService();
    _setupDataListener();
  }

  void _updateTimer(Timer timer) {
    setState(() {
      _elapsed = DateTime.now().difference(widget.sleepData.startTime);
    });
  }

  void _startBackgroundService() async {
    bool isRunning = await _backgroundService.isRunning();
    if (!isRunning) {
      await _backgroundService.startService();
    }
  }

  void _setupDataListener() {
    _serviceSubscription = _backgroundService.on('updateData').listen((event) {
      if (event != null) {
        setState(() {
          widget.sleepData.accelerometerData =
              List<double>.from(event['accelerometer'] ?? []);
          widget.sleepData.lightData = List<int>.from(event['light'] ?? []);
        });
        // print('accelerometer ${widget.sleepData.accelerometerData}');
        // print('light data ${widget.sleepData.lightData}');
        _updateLightInfo();
      }
    });

    // Set up periodic data requests
    _lightDataTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _backgroundService.invoke('getLightData');
    });
  }

  void _updateLightInfo() {
    if (widget.sleepData.lightData != null &&
        widget.sleepData.lightData!.isNotEmpty) {
      int latestLux = widget.sleepData.lightData!.last;
      setState(() {
        if (latestLux < 5) {
          _lightDescription = "Perfect darkness for deep sleep";
          _lightIcon = Icons.nightlight_round;
        } else if (latestLux < 20) {
          _lightDescription = "Good darkness for sleep";
          _lightIcon = Icons.nightlight;
        } else if (latestLux < 50) {
          _lightDescription = "Dim light, consider darkening the room";
          _lightIcon = Icons.brightness_low;
        } else {
          _lightDescription = "Too bright for optimal sleep";
          _lightIcon = Icons.brightness_high;
        }
      });
    }
  }

  Future<bool> _showConfirmationDialog(String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirm $action'),
              content:
                  Text('Are you sure you want to $action the sleep session?'),
              actions: [
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
        ) ??
        false;
  }

  void _endSession() async {
    bool confirmed = await _showConfirmationDialog('end');
    if (confirmed) {
      _timer?.cancel();
      _lightDataTimer?.cancel();

      await SleepTrackingService.stopService();

      widget.sleepData.endSession(
        accelerometerData: widget.sleepData.accelerometerData,
        lightData: widget.sleepData.lightData,
      );

      // set the state on home screen
      widget.handleSessionEnd(widget.sleepData);

      // Use pushReplacement instead of push
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SessionDetailScreen(sleepData: widget.sleepData),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    _lightDataTimer?.cancel();
    _serviceSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        _endSession();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sleep Session'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              _endSession();
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Sleep in progress',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 20),
              Text(
                _formatDuration(_elapsed),
                style:
                    const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              Icon(_lightIcon, size: 48),
              Text(_lightDescription),
              const SizedBox(height: 40),
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
