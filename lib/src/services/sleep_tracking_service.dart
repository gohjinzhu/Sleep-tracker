import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:light/light.dart';

class SleepTrackingService {
  static List<double> accelerometerValues = [];
  static List<int> lightValues = [];

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await _requestPermissions();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'sleep_tracking_channel',
      'Sleep Tracking Service',
      description: 'This channel is used for sleep tracking notifications',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'sleep_tracking_channel',
        initialNotificationTitle: 'Sleep Tracking Service',
        initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<void> _requestPermissions() async {
    await Permission.activityRecognition.request();
    await Permission.sensors.request();
    // Note: HIGH_SAMPLING_RATE_SENSORS doesn't have a specific permission in the plugin,
    // it's generally covered by the sensors permission
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    Light light = Light();
    List<StreamSubscription> eventSubscriptions = [];
    AccelerometerEvent? lastEvent;
    Timer? timer;
    print('service starting');
    print('accelerometer values $accelerometerValues');
    print('light values $lightValues');
    if (service is AndroidServiceInstance) {
      eventSubscriptions.add(service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      }));

      eventSubscriptions.add(service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      }));
    }

    eventSubscriptions.add(service.on('stopService').listen((event) {
      timer?.cancel();
      // ** define updateData event listener on widget that need to use the data
      service.invoke(
        'updateData',
        {
          "accelerometer": accelerometerValues,
          "light": lightValues,
        },
      );
      // Cancel all event listeners
      for (var subscription in eventSubscriptions) {
        subscription.cancel();
      }
      eventSubscriptions.clear();

      service.stopSelf(); // stop service instance
      service.invoke('serviceStopped');
    }));

    eventSubscriptions.add(service.on('getLightData').listen((event) {
      service.invoke(
        'updateData',
        {
          "accelerometer": accelerometerValues,
          "light": lightValues,
        },
      );
    }));

    // Start collecting sensor data
    eventSubscriptions
        .add(accelerometerEventStream().listen((AccelerometerEvent event) {
      lastEvent = event;
    }));

    eventSubscriptions.add(light.lightSensorStream.listen((int luxValue) {
      lightValues.add(luxValue);
    }));

    // Start the service immediately
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Sleep Tracking Active",
        content: "Monitoring your sleep...",
      );
    }

    timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (lastEvent != null) {
        double magnitude =
            _calculateMagnitude(lastEvent!.x, lastEvent!.y, lastEvent!.z);
        double movement = _calculateMovement(magnitude);
        accelerometerValues.add(movement);
      }
    });

    // This timer runs every minute to update the notification
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: "Sleep Tracking Active",
            content: "Monitoring your sleep...",
          );
        }
      }
    });
  }

  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    final stopCompleter = Completer<void>();

    // Listen for the 'serviceStopped' event
    final subscription = service.on('serviceStopped').listen((event) {
      stopCompleter.complete();
    });

    // Send the stop command to the service
    service.invoke('stopService');

    // Wait for the service to stop
    await stopCompleter.future;

    accelerometerValues.clear();
    lightValues.clear();
    print('value cleared');

    // Cancel the 'serviceStopped' listener
    subscription.cancel();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  static double _calculateMagnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  static double _calculateMovement(double magnitude) {
    const double GRAVITY = 9.781;
    return (magnitude - GRAVITY).abs();
  }
}
