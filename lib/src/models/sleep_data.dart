class SleepData {
  final DateTime date;
  final DateTime startTime;
  DateTime? endTime;
  Duration? sleepDuration;
  double? qualityRating;
  List<double>? accelerometerData;
  List<int>? lightData;

  SleepData({
    required this.date,
    required this.startTime,
    this.endTime,
    this.sleepDuration,
    this.qualityRating,
    this.accelerometerData,
    this.lightData,
  });

  void endSession({
    List<double>? accelerometerData,
    List<int>? lightData,
  }) {
    endTime = DateTime.now();
    sleepDuration = endTime!.difference(startTime);
    this.accelerometerData = accelerometerData;
    this.lightData = lightData;
    // Quality rating will be calculated in the SessionDetailScreen
  }
}