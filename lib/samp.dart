import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import 'main.dart';

class MediScanPage extends StatefulWidget {
  const MediScanPage({super.key});

  @override
  State<MediScanPage> createState() => _MediScanPageState();
}

class _MediScanPageState extends State<MediScanPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  // Map of medications per date
  Map<String, List<Map<String, dynamic>>> medicationsByDate = {};

  // List of daily medications (repeat every day)
  List<Map<String, dynamic>> dailyMedications = [];

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    notify_permission();
    cleanupOldTimers();
    _loadMedications();
  }

  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> notify_permission() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  void cleanupOldTimers() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final keys = prefs.getKeys();

    for (var key in keys) {
      if (key.startsWith("timer_")) {
        final dateString = prefs.getString(key);
        if (dateString != null) {
          final timerDate = DateTime.parse(dateString);
          // If timer date is before today, delete it
          if (timerDate.isBefore(DateTime(now.year, now.month, now.day))) {
            prefs.remove(key);
          }
        }
      }
    }
  }

  // Convert DateTime to string key
  String _dateKey(DateTime date) => date.toIso8601String().split("T").first;

  // Load medications from SharedPreferences
  Future<void> _loadMedications() async {
    final prefs = await SharedPreferences.getInstance();

    final String? savedData = prefs.getString('medicationsByDate');
    if (savedData != null) {
      medicationsByDate = Map<String, List<Map<String, dynamic>>>.from(
        json.decode(savedData),
      );
    }

    final String? savedDaily = prefs.getString('dailyMedications');
    if (savedDaily != null) {
      dailyMedications = List<Map<String, dynamic>>.from(
        json.decode(savedDaily),
      );
    }
  }

  // Save medications to SharedPreferences
  Future<void> _saveMedications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('medicationsByDate', json.encode(medicationsByDate));
    await prefs.setString('dailyMedications', json.encode(dailyMedications));
  }

  // Delete medication for selected day or daily
  void _deleteMedication(int index, {bool isDaily = false}) async {
    if (isDaily) {
      setState(() {
        dailyMedications.removeAt(index);
      });
    } else {
      final key = _dateKey(_selectedDay ?? DateTime.now());
      setState(() {
        medicationsByDate[key]?.removeAt(index);
      });
    }
    await _saveMedications();
  }

  // Add medication via dialog
  void _showAddMedicationDialog() {
    final TextEditingController nameController = TextEditingController();
    bool isDaily = false;
    List<TimeOfDay> timeSlots = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add Medication"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Medication Name"),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text("Repeat every day"),
                value: isDaily,
                onChanged: (val) {
                  setDialogState(() => isDaily = val ?? false);
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      timeSlots.add(picked);
                    });
                  }
                },
                child: const Text("Add Time Slot"),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: timeSlots
                    .map((t) => Chip(label: Text("${t.format(context)}")))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && timeSlots.isNotEmpty) {
                  final medData = {
                    "name": nameController.text,
                    "times": timeSlots.map((t) => t.format(context)).toList(),
                  };

                  if (isDaily) {
                    setState(() {
                      dailyMedications.add(medData);
                    });
                  } else {
                    final key = _dateKey(_selectedDay ?? DateTime.now());
                    setState(() {
                      medicationsByDate.putIfAbsent(key, () => []);
                      medicationsByDate[key]!.add(medData);
                    });
                  }
                  Navigator.pop(context);
                  await _saveMedications();
                }
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = _dateKey(_selectedDay ?? DateTime.now());
    final medsForDay = [...dailyMedications, ...(medicationsByDate[key] ?? [])];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "MediScan Schedule",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back, color: Colors.lightBlue, size: 30),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Calendar
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.5), blurRadius: 5),
                ],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2023, 10, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (!selectedDay.isBefore(DateTime.now())) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  }
                },
                enabledDayPredicate: (day) {
                  // Disable past days
                  return !day.isBefore(DateTime.now());
                },
                calendarStyle: CalendarStyle(
                  defaultTextStyle: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                  weekendTextStyle: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),

                  todayDecoration: BoxDecoration(
                    color: Colors.lightBlue.shade100,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                  disabledTextStyle: TextStyle(
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.lightBlue,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                headerStyle: HeaderStyle(
                  titleTextStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold, // ✅ makes month text bold
                    color: Colors.black,
                  ),
                  formatButtonVisible:
                      false, // optional: hides format toggle button
                  titleCentered: true, // optional: centers the month text
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    fontWeight: FontWeight.bold, // ✅ makes weekdays bold
                    color: Colors.black,
                  ),
                  weekendStyle: TextStyle(
                    fontWeight: FontWeight.bold, // ✅ makes weekends bold
                    color: Colors.red, // optional: highlight weekends
                  ),
                ),
              ),
            ),
          ),

          // Medication list for selected day
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: medsForDay.length,
              itemBuilder: (context, index) {
                final med = medsForDay[index];
                final isDaily = index < dailyMedications.length;

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.medication,
                      color: Colors.blueAccent,
                    ),
                    title: Text(
                      med["name"]!,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDaily
                              ? "Daily • Times: ${med["times"].join(", ")}"
                              : "Times: ${med["times"].join(", ")}",
                        ),
                        const SizedBox(height: 4),
                        CountdownTimerWidget(
                          times: List<String>.from(med["times"]),
                          isDaily: isDaily,
                          medicationName: med["name"]!,
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _deleteMedication(index, isDaily: isDaily),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMedicationDialog,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class CountdownTimerWidget extends StatefulWidget {
  final List<String> times;
  final bool isDaily;
  final String medicationName;

  const CountdownTimerWidget({
    super.key,
    required this.times,
    required this.isDaily,
    required this.medicationName,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  late Timer _timer;
  String _timeLeft = "";

  Future<void> _showNotification(String medName) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'med_channel',
          'Medication Reminders',
          channelDescription: 'Notify when medication timer ends',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Medication Reminder',
      '$medName timer has ended!',
      platformDetails,
    );
  }

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    final now = DateTime.now();
    DateTime? nextTime;

    for (var t in widget.times) {
      final parsed = _parseTime(t, now);
      if (parsed.isAfter(now)) {
        nextTime = parsed;
        break;
      }
    }

    // If no future time today, and it's daily, pick tomorrow’s first slot
    if (nextTime == null && widget.isDaily) {
      nextTime = _parseTime(
        widget.times.first,
        now.add(const Duration(days: 1)),
      );
    }

    if (nextTime != null) {
      final diff = nextTime.difference(now);

      if (diff.inSeconds <= 0) {
        _showNotification(
          widget.medicationName,
        ); // pass actual med name if available
      }

      setState(() {
        _timeLeft =
            "${diff.inHours}h ${diff.inMinutes % 60}m ${diff.inSeconds % 60}s left";
      });
    } else {
      setState(() {
        _timeLeft = "No upcoming time today";
      });
    }
  }

  DateTime _parseTime(String formatted, DateTime baseDay) {
    final parts = formatted.split(":");
    final hourPart = parts[0].trim();
    final minutePart = parts[1].split(" ")[0];
    final suffix = formatted.contains("PM") ? "PM" : "AM";

    int hour = int.parse(hourPart);
    int minute = int.parse(minutePart);

    if (suffix == "PM" && hour != 12) {
      hour += 12;
    }
    if (suffix == "AM" && hour == 12) {
      hour = 0;
    }

    return DateTime(baseDay.year, baseDay.month, baseDay.day, hour, minute);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _timeLeft,
      style: const TextStyle(color: Colors.blueGrey, fontSize: 14),
    );
  }
}
