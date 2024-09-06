import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../models/sleep_data.dart';
import '../screens/sleep_session_screen.dart';
import '../screens/session_detail_screen.dart';
import '../settings/settings_view.dart';
import '../routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  static const routeName = AppRoutes.home;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SleepData> sleepEntries = [];
  SleepData? ongoingSession;

  @override
  void initState() {
    super.initState();
    _checkOngoingSession();
  }

  void _checkOngoingSession() async {
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    if (isRunning) {
      // If the service is running, we assume there's an ongoing session
      setState(() {
        ongoingSession = SleepData(
          date: DateTime.now(),
          startTime: DateTime
              .now(), // This should ideally be retrieved from the service
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, SettingsView.routeName);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (ongoingSession != null)
            ListTile(
              title: const Text('Ongoing Sleep Session'),
              subtitle:
                  Text('Started at: ${ongoingSession!.startTime.toString()}'),
              trailing: ElevatedButton(
                onPressed: _navigateToSleepSession,
                child: const Text('View Session'),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: sleepEntries.length,
              itemBuilder: (context, index) {
                final entry = sleepEntries[index];
                return ListTile(
                  title: Text('${entry.date.toLocal()}'.split(' ')[0]),
                  subtitle: Text(
                      'Duration: ${entry.sleepDuration?.inHours}h ${entry.sleepDuration?.inMinutes.remainder(60)}m'),
                  trailing: Text(
                      'Quality: ${entry.qualityRating?.toStringAsFixed(1) ?? 'N/A'}'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SessionDetailScreen(sleepData: entry),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: ongoingSession == null
            ? _startSleepSession
            : _navigateToSleepSession,
        child: Icon(ongoingSession == null ? Icons.bed : Icons.visibility),
      ),
    );
  }

  void _startSleepSession() async {
    setState(() {
      ongoingSession = SleepData(
        date: DateTime.now(),
        startTime: DateTime.now(),
      );
    });
    _navigateToSleepSession();
  }

  void _navigateToSleepSession() {
    if (ongoingSession != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SleepSessionScreen(
            sleepData: ongoingSession!,
            handleSessionEnd: _handleSessionEnd,
          ),
        ),
      );
    }
  }

  void _handleSessionEnd(SleepData completedSession) async {
    setState(() {
      sleepEntries.add(completedSession);
      ongoingSession = null;
    });
  }
}
