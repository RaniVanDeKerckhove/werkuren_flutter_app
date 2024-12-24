
class WorkHoursScreen extends StatefulWidget {
  @override
  _WorkHoursScreenState createState() => _WorkHoursScreenState();
}

class _WorkHoursScreenState extends State<WorkHoursScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? startTime;
  String? endTime;
  int pauseMinutes = 30;
  double totalWeeklyHours = 0;
  final workplace = {'lat': 50.9054, 'lng': 3.9401};
  final allowedRadius = 100.0;

  @override
  void initState() {
    super.initState();
    fetchWorkHoursForCurrentWeek();
  }

  Future<bool> checkLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          workplace['lat']!,
          workplace['lng']!);

      return distance < allowedRadius;
    } catch (e) {
      print('Error getting location: $e');
      return false;
    }
  }

  Future<void> saveToFirestore(Map<String, dynamic> data) async {
    try {
      await _firestore.collection('work_hours').doc(data['date']).set(data, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Data saved successfully")),
      );
    } catch (e) {
      print("Error saving to Firestore: $e");
    }
  }

  String roundTimeToQuarter(DateTime time) {
    int totalMinutes = time.hour * 60 + time.minute;
    int roundedMinutes = ((totalMinutes / 15).round() * 15) % 1440;

    int hours = roundedMinutes ~/ 60;
    int minutes = roundedMinutes % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  Future<void> handleStartWork() async {
    bool isAtWork = await checkLocation();
    if (!isAtWork) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You are not at the workplace")),
      );
      return;
    }

    DateTime now = DateTime.now();
    String roundedStartTime = roundTimeToQuarter(now);

    setState(() {
      startTime = roundedStartTime;
    });

    Map<String, dynamic> data = {
      'date': DateFormat('yyyy-MM-dd').format(now),
      'startTime': roundedStartTime,
      'pauseMinutes': pauseMinutes,
    };

    await saveToFirestore(data);
  }

  Future<void> handleEndWork() async {
    bool isAtWork = await checkLocation();
    if (!isAtWork) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You are not at the workplace")),
      );
      return;
    }

    DateTime now = DateTime.now();
    String roundedEndTime = roundTimeToQuarter(now);

    setState(() {
      endTime = roundedEndTime;
    });

    Map<String, dynamic> data = {
      'date': DateFormat('yyyy-MM-dd').format(now),
      'endTime': roundedEndTime,
      'pauseMinutes': pauseMinutes,
    };

    await saveToFirestore(data);
  }

  void fetchWorkHoursForCurrentWeek() async {
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    DateTime endOfWeek = startOfWeek.add(Duration(days: 6));

    QuerySnapshot snapshot = await _firestore
        .collection('work_hours')
        .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startOfWeek))
        .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endOfWeek))
        .get();

    double weeklyHours = 0;

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['startTime'] != null && data['endTime'] != null) {
        List<String> startParts = data['startTime'].split(':');
        List<String> endParts = data['endTime'].split(':');

        int startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        int endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

        if (endMinutes < startMinutes) {
          endMinutes += 1440; // Account for next day
        }

        int workMinutes = endMinutes - startMinutes - data['pauseMinutes'];
        weeklyHours += workMinutes / 60.0;
      }
    }

    setState(() {
      totalWeeklyHours = weeklyHours;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Work Hours Tracker"),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: handleStartWork,
              child: Text("Start Work"),
            ),
            ElevatedButton(
              onPressed: handleEndWork,
              child: Text("End Work"),
            ),
            DropdownButton<int>(
              value: pauseMinutes,
              items: [15, 30, 45, 60]
                  .map((e) => DropdownMenuItem<int>(value: e, child: Text("$e minutes")))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  pauseMinutes = value!;
                });
              },
            ),
            SizedBox(height: 20),
            Text("Start Time: ${startTime ?? 'Not set yet'}"),
            Text("End Time: ${endTime ?? 'Not set yet'}"),
            SizedBox(height: 20),
            Text("Total Weekly Hours: ${totalWeeklyHours.toStringAsFixed(2)}"),
          ],
        ),
      ),
    );
  }
}
