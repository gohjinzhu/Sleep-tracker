import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sleep_data.dart';
import 'dart:math';

class SessionDetailScreen extends StatelessWidget {
  static const int SAMPLES_PER_MINUTE = 120; // 2 Hz * 60 seconds
  final SleepData sleepData;

  const SessionDetailScreen({super.key, required this.sleepData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Session Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSummary(),
            _buildSleepStageGraph(),
            _buildSleepQualityScore(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${sleepData.date.toLocal()}'.split(' ')[0]),
            Text(
                'Duration: ${sleepData.sleepDuration?.inHours}h ${sleepData.sleepDuration?.inMinutes.remainder(60)}m ${sleepData.sleepDuration?.inSeconds.remainder(60)}s'),
            Text('Start Time: ${_formatDateTime(sleepData.startTime)}'),
            Text(
                'End Time: ${sleepData.endTime != null ? _formatDateTime(sleepData.endTime!) : 'N/A'}'),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.toLocal().toString().split(' ')[1].split('.')[0]}';
  }

  Widget _buildSleepStageGraph() {
    List<FlSpot> spots = [];
    List<String> stages = _calculateSleepStages(sleepData.accelerometerData);

    // Add initial "Awake" state at 0 minutes
    spots.add(const FlSpot(0, 3));

    for (int i = 0; i < stages.length; i++) {
      spots.add(FlSpot((i + 1).toDouble(), _stageToValue(stages[i])));
    }

    return SizedBox(
      height: 300,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    switch (value.toInt()) {
                      case 3:
                        return const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text('Awake', style: TextStyle(fontSize: 10)),
                        );
                      case 2:
                        return const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text('Light sleep',
                              style: TextStyle(fontSize: 10)),
                        );
                      case 1:
                        return const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text('REM', style: TextStyle(fontSize: 10)),
                        );
                      case 0:
                        return const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text('Deep sleep',
                              style: TextStyle(fontSize: 10)),
                        );
                      default:
                        return const Text('');
                    }
                  },
                  reservedSize: 60,
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: max(1, stages.length / 6),
                  getTitlesWidget: (value, meta) {
                    int minutes = value.toInt();
                    return Text('${minutes}m');
                  },
                ),
              ),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true),
            minX: 0,
            maxX: spots.length - 1,
            minY: 0,
            maxY: 3,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                preventCurveOverShooting: true,
                color: Colors.blue,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSleepQualityScore() {
    double qualityScore = _calculateSleepQuality();
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Sleep Quality Score',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${qualityScore.toStringAsFixed(1)} / 5.0',
                style: const TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }

  List<String> _calculateSleepStages(List<double>? accelerometerData) {
    if (accelerometerData == null || accelerometerData.isEmpty) {
      return [];
    }

    List<String> stages = [];
    for (int i = 0; i < accelerometerData.length; i += SAMPLES_PER_MINUTE) {
      int endIndex = min(i + SAMPLES_PER_MINUTE, accelerometerData.length);
      int sampleSize = endIndex - i;

      double avgMovement =
          accelerometerData.sublist(i, endIndex).reduce((a, b) => a + b) /
              sampleSize;
      if (avgMovement < 0.02) {
        stages.add('Deep sleep');
      } else if (avgMovement < 0.05) {
        stages.add('REM');
      } else if (avgMovement < 0.1) {
        stages.add('Light sleep');
      } else {
        stages.add('Awake');
      }
    }
    return stages;
  }

  double _stageToValue(String stage) {
    switch (stage) {
      case 'Deep sleep':
        return 0;
      case 'REM':
        return 1;
      case 'Light sleep':
        return 2;
      case 'Awake':
        return 3;
      default:
        return 3; // Default to Awake if unknown
    }
  }

  double _calculateSleepQuality() {
    if (sleepData.accelerometerData == null || sleepData.lightData == null) {
      return 0.0;
    }
    print('calculating accelerometer data ${sleepData.accelerometerData}');
    List<String> stages = _calculateSleepStages(sleepData.accelerometerData);
    int deepSleepMinutes =
        stages.where((stage) => stage == 'Deep sleep').length;
    int remSleepMinutes = stages.where((stage) => stage == 'REM').length;

    // Calculate scores based on ideal sleep stage percentages
    double deepSleepScore =
        min(deepSleepMinutes / 120, 1.0) * 5; // 120min ideal
    double remSleepScore = min(remSleepMinutes / 120, 1.0) * 5; // 120min ideal

    // Calculate light score
    double avgLight = sleepData.lightData!.reduce((a, b) => a + b) /
        sleepData.lightData!.length;
    double lightScore =
        max((50 - avgLight) / 10.0, 0); // 0-5 score, lower light is better

    // Combine scores (deep sleep and REM are weighted more heavily)
    double totalScore = (deepSleepScore + remSleepScore + lightScore) / 3;
    return totalScore.clamp(0.0, 5.0); // Ensure score is between 0 and 5
  }
}
