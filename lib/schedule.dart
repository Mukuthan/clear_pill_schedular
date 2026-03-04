import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class MediScanPage extends StatefulWidget {
  const MediScanPage({super.key});

  @override
  State<MediScanPage> createState() => _MediScanPageState();
}

class _MediScanPageState extends State<MediScanPage> {
  // Use state to track the selected calendar day
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MediScan Schedule")),
      body: Column(
        children: [
          // 1. The Calendar Section
          TableCalendar(
            firstDay: DateTime.utc(2023, 10, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.week, // Matches your design
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
          ),

          // 2. The Regimen List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 3, // Your data length
              itemBuilder: (context, index) {
                return _buildMedicationCard(); // Extract this to a helper
              },
            ),
          ),
        ],
      ),
      // 3. Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      // 4. Bottom Nav
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  // Helper for the Medication Card
  Widget _buildMedicationCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.medication),
        title: const Text("Amoxicillin"),
        subtitle: const Text("500mg • 1 capsule"),
        trailing: ElevatedButton(onPressed: () {}, child: const Text("Take")),
      ),
    );
  }
}
