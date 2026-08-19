import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' hide Column;
import '../services/app_database.dart';
import '../services/database_service.dart';
import 'workout_detail_page.dart';

class TrainingCalendarPage extends StatefulWidget {
  const TrainingCalendarPage({super.key});

  @override
  State<TrainingCalendarPage> createState() => _TrainingCalendarPageState();
}

class _TrainingCalendarPageState extends State<TrainingCalendarPage> {
  final AppDatabase _database = DatabaseService.database;

  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  bool _isLoading = true;
  List<Workout> _workouts = [];
  Set<String> _footballDays = {};
  Map<String, List<Workout>> _workoutsByWeek = {};
  Map<String, List<Workout>> _archivedWorkoutsByWeek = {};

  final Map<int, String> _weeklyPlan = {
    DateTime.monday: 'Push',
    DateTime.tuesday: 'Pull',
    DateTime.wednesday: 'Beine',
    DateTime.thursday: 'Rest Day',
    DateTime.friday: 'Oberkörper',
    DateTime.saturday: 'Unterkörper',
    DateTime.sunday: 'Rest Day',
  };

  static const List<String> _trainingTypes = [
    'Push',
    'Pull',
    'Beine',
    'Oberkörper',
    'Unterkörper',
    'Ganzkörper',
    'Fußball',
    'Rest Day',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFootballDays = prefs.getStringList('football_days') ?? [];

    _footballDays = savedFootballDays.toSet();

    for (final day in _weeklyPlan.keys) {
      final savedPlan = prefs.getString('training_plan_$day');

      if (savedPlan != null) {
        _weeklyPlan[day] = savedPlan;
      }
    }

    final workouts = await (_database.select(
      _database.workouts,
    )..where((workout) => workout.completed.equals(true))).get();

    if (!mounted) return;

    setState(() {
      _workouts = workouts;
      _isLoading = false;

      _groupWorkoutsByWeek();
    });
  }

  Future<void> _savePlan() async {
    final prefs = await SharedPreferences.getInstance();

    for (final entry in _weeklyPlan.entries) {
      await prefs.setString('training_plan_${entry.key}', entry.value);
    }
  }

  Workout? _workoutForDay(DateTime day) {
    for (final workout in _workouts) {
      if (workout.date.year == day.year &&
          workout.date.month == day.month &&
          workout.date.day == day.day) {
        return workout;
      }
    }

    return null;
  }

  void _groupWorkoutsByWeek() {
    final active = <String, List<Workout>>{};
    final archived = <String, List<Workout>>{};

    for (final workout in _workouts) {
      final date = workout.date;

      final monday = DateTime(
        date.year,
        date.month,
        date.day,
      ).subtract(Duration(days: date.weekday - 1));

      final weekKey = '${monday.year}-${monday.month}-${monday.day}';

      if (workout.archived) {
        archived.putIfAbsent(weekKey, () => []).add(workout);
      } else {
        active.putIfAbsent(weekKey, () => []).add(workout);
      }
    }

    for (final workouts in active.values) {
      workouts.sort((a, b) => b.date.compareTo(a.date));
    }

    for (final workouts in archived.values) {
      workouts.sort((a, b) => b.date.compareTo(a.date));
    }

    _workoutsByWeek = active;
    _archivedWorkoutsByWeek = archived;
  }

  String _getDayStatus(DateTime day) {
    final planned = _weeklyPlan[day.weekday];
    final workout = _workoutForDay(day);

    final today = DateTime.now();
    final dateOnly = DateTime(day.year, day.month, day.day);
    final todayOnly = DateTime(today.year, today.month, today.day);

    // Zukünftiger Tag
    if (dateOnly.isAfter(todayOnly)) {
      return 'future';
    }

    // Fußball
    if (planned == 'Fußball') {
      final footballDone = _footballDays.contains(_dateKey(day));

      if (footballDone) {
        return 'completed';
      }

      // Falls an einem Fußballtag zusätzlich ein Krafttraining
      // gemacht wurde
      if (workout != null) {
        return 'different';
      }

      return 'missed';
    }

    // Rest Day
    if (planned == 'Rest Day') {
      if (workout == null) {
        return 'rest';
      }

      return 'extra';
    }

    // Kein Training obwohl Training geplant war
    if (workout == null) {
      return 'missed';
    }

    // Training wie geplant
    if (workout.name == planned) {
      return 'completed';
    }

    // Training gemacht, aber anderer Trainingstag
    return 'different';
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  Future<void> _toggleFootball(DateTime day) async {
    final key = _dateKey(day);

    final updatedDays = Set<String>.from(_footballDays);

    if (updatedDays.contains(key)) {
      updatedDays.remove(key);
    } else {
      updatedDays.add(key);
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList('football_days', updatedDays.toList());

    if (!mounted) return;

    setState(() {
      _footballDays = updatedDays;
    });
  }

  int _daysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  int _firstWeekday(DateTime month) {
    return DateTime(month.year, month.month, 1).weekday - 1;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  String _monthName(int month) {
    const months = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];

    return months[month - 1];
  }

  String _weekdayName(int weekday) {
    const names = {
      DateTime.monday: 'Montag',
      DateTime.tuesday: 'Dienstag',
      DateTime.wednesday: 'Mittwoch',
      DateTime.thursday: 'Donnerstag',
      DateTime.friday: 'Freitag',
      DateTime.saturday: 'Samstag',
      DateTime.sunday: 'Sonntag',
    };

    return names[weekday]!;
  }

  Future<void> _editTrainingPlan() async {
    final updatedPlan = Map<int, String>.from(_weeklyPlan);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Trainingsplan bearbeiten'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final day in _weeklyPlan.keys)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _weekdayName(day),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: updatedPlan[day],
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _trainingTypes
                                      .map(
                                        (type) => DropdownMenuItem(
                                          value: type,
                                          child: Text(type),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;

                                    setDialogState(() {
                                      updatedPlan[day] = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;

    setState(() {
      _weeklyPlan
        ..clear()
        ..addAll(updatedPlan);
    });

    await _savePlan();
  }

  void _showWorkout(Workout workout) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutDetailPage(workout: workout),
      ),
    );
  }

  void _showDayDetails(DateTime day) {
    final planned = _weeklyPlan[day.weekday];
    final workout = _workoutForDay(day);
    final status = _getDayStatus(day);

    final formattedDate =
        '${day.day.toString().padLeft(2, '0')} .'
        '${day.month.toString().padLeft(2, '0')}.'
        '${day.year}';

    IconData statusIcon;
    Color statusColor;
    String statusText;

    switch (status) {
      case 'completed':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        statusText = 'Training erfüllt';
        break;

      case 'missed':
        statusIcon = Icons.cancel;
        statusColor = Colors.red;
        statusText = 'Training verpasst';
        break;

      case 'different':
        statusIcon = Icons.warning;
        statusColor = Colors.orange;
        statusText = 'Anderes Training absolviert';
        break;

      case 'rest':
        statusIcon = Icons.bedtime;
        statusColor = Colors.blueGrey;
        statusText = 'Rest Day';
        break;

      case 'extra':
        statusIcon = Icons.fitness_center;
        statusColor = Colors.blue;
        statusText = 'Extra Training';
        break;

      default:
        statusIcon = planned == 'Fußball'
            ? Icons.sports_soccer
            : Icons.circle_outlined;
        statusColor = Colors.grey;
        statusText = 'Geplant';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(formattedDate),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (planned != null) ...[
                const Text(
                  'Geplant',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      planned == 'Fußball'
                          ? Icons.sports_soccer
                          : planned == 'Rest Day'
                          ? Icons.bedtime
                          : Icons.fitness_center,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        planned,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              const Text(
                'Status',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 4),

              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              if (workout != null) ...[
                const SizedBox(height: 20),
                const Text(
                  'Absolviert',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.fitness_center, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        workout.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            if (workout != null)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _showWorkout(workout);
                },
                icon: const Icon(Icons.visibility),
                label: const Text('Training ansehen'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWorkoutHistory() {
    final activeWeeks = _workoutsByWeek.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final archivedWeeks = _archivedWorkoutsByWeek.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    if (activeWeeks.isEmpty && archivedWeeks.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Noch keine Trainingshistorie vorhanden.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📚 Trainingshistorie',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        for (final weekKey in activeWeeks)
          _buildWeekTile(weekKey, _workoutsByWeek[weekKey]!),

        if (archivedWeeks.isNotEmpty) ...[
          const SizedBox(height: 20),

          const Text(
            '📦 Archiv',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          for (final weekKey in archivedWeeks)
            _buildWeekTile(weekKey, _archivedWorkoutsByWeek[weekKey]!),
        ],
      ],
    );
  }

  Widget _buildWeekTile(String weekKey, List<Workout> workouts) {
    final mondayParts = weekKey.split('-');

    final monday = DateTime(
      int.parse(mondayParts[0]),
      int.parse(mondayParts[1]),
      int.parse(mondayParts[2]),
    );

    final weekNumber = _getWeekNumber(monday);
    final isArchived = workouts.isNotEmpty && workouts.first.archived;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(isArchived ? Icons.archive : Icons.calendar_month),

        title: Text(
          'KW $weekNumber · ${monday.year}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Text(
          '${workouts.length} '
          '${workouts.length == 1 ? 'Training' : 'Trainings'}',
        ),

        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'archive' && !isArchived) {
              await _archiveWeek(workouts);
            }

            if (value == 'delete') {
              await _deleteWeek(workouts);
            }
          },

          itemBuilder: (context) => [
            if (!isArchived)
              const PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive),
                    SizedBox(width: 8),
                    Text('Woche archivieren'),
                  ],
                ),
              ),

            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline),
                  SizedBox(width: 8),
                  Text('Woche löschen'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));

    final firstThursday = DateTime(thursday.year, 1, 4);

    final difference = thursday.difference(firstThursday).inDays;

    return 1 + (difference / 7).floor();
  }

  Future<void> _archiveWeek(List<Workout> workouts) async {
    for (final workout in workouts) {
      await (_database.update(_database.workouts)
            ..where((item) => item.id.equals(workout.id)))
          .write(const WorkoutsCompanion(archived: Value(true)));
    }

    await _loadData();
  }

  Future<void> _deleteWeek(List<Workout> workouts) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Woche löschen?'),
          content: Text(
            'Möchtest du wirklich alle ${workouts.length} '
            '${workouts.length == 1 ? 'Training' : 'Trainings'} '
            'dieser Woche löschen?\n\n'
            'Diese Aktion kann nicht rückgängig gemacht werden.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    for (final workout in workouts) {
      final workoutExercises = await (_database.select(
        _database.workoutExercises,
      )..where((item) => item.workoutId.equals(workout.id))).get();

      for (final workoutExercise in workoutExercises) {
        await (_database.delete(_database.workoutSets)..where(
              (item) => item.workoutExerciseId.equals(workoutExercise.id),
            ))
            .go();

        await (_database.delete(
          _database.workoutExercises,
        )..where((item) => item.id.equals(workoutExercise.id))).go();
      }

      await (_database.delete(
        _database.workouts,
      )..where((item) => item.id.equals(workout.id))).go();
    }

    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainingskalender'),
        actions: [
          IconButton(
            onPressed: _editTrainingPlan,
            tooltip: 'Trainingsplan bearbeiten',
            icon: const Icon(Icons.edit_calendar),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ============================================================
                // Kalender
                // ============================================================
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: _previousMonth,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text(
                              '${_monthName(_currentMonth.month)} '
                              '${_currentMonth.year}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: _nextMonth,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            for (final day in [
                              'Mo',
                              'Di',
                              'Mi',
                              'Do',
                              'Fr',
                              'Sa',
                              'So',
                            ])
                              Expanded(
                                child: Center(
                                  child: Text(
                                    day,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        _buildCalendar(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ============================================================
                // Kalender-Legende
                // ============================================================
                _buildCalendarLegend(),

                const SizedBox(height: 20),

                // ============================================================
                // Wochenstatistik
                // ============================================================
                _buildWeeklyStats(),

                const SizedBox(height: 20),

                _buildWorkoutHistory(),

                const SizedBox(height: 20),

                // ============================================================
                // Mein Trainingsplan
                // ============================================================
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Mein Trainingsplan',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: _editTrainingPlan,
                              icon: const Icon(Icons.edit),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        for (final day in _weeklyPlan.keys)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 100,
                                  child: Text(_weekdayName(day)),
                                ),
                                Icon(
                                  _weeklyPlan[day] == 'Rest Day'
                                      ? Icons.bedtime
                                      : _weeklyPlan[day] == 'Fußball'
                                      ? Icons.sports_soccer
                                      : Icons.fitness_center,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _weeklyPlan[day]!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildWeeklyStats() {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final monday = today.subtract(Duration(days: today.weekday - 1));

    int plannedTrainingDays = 0;
    int completedDays = 0;
    int missedDays = 0;
    int restDays = 0;
    int extraTraining = 0;

    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));

      // Zukünftige Tage nicht mitzählen
      if (day.isAfter(today)) {
        continue;
      }

      final planned = _weeklyPlan[day.weekday];

      if (planned == null) {
        continue;
      }

      final status = _getDayStatus(day);

      if (planned == 'Rest Day') {
        restDays++;

        if (status == 'extra') {
          extraTraining++;
        }

        continue;
      }

      plannedTrainingDays++;

      if (status == 'completed') {
        completedDays++;
      } else if (status == 'missed') {
        missedDays++;
      }
    }

    final percentage = plannedTrainingDays == 0
        ? 0
        : ((completedDays / plannedTrainingDays) * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Diese Woche',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.check_circle,
                    value: '$completedDays',
                    label: 'Erfüllt',
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.cancel,
                    value: '$missedDays',
                    label: 'Verpasst',
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.bedtime,
                    value: '$restDays',
                    label: 'Rest Days',
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.fitness_center,
                    value: '$extraTraining',
                    label: 'Extra',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              'Planerfüllung: $percentage %',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),

            const SizedBox(height: 8),

            Text(
              '$completedDays von $plannedTrainingDays '
              'geplanten Trainingstagen erfüllt',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarLegend() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Legende',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _LegendItem(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  text: 'Erfüllt',
                ),
                _LegendItem(
                  icon: Icons.cancel,
                  color: Colors.red,
                  text: 'Verpasst',
                ),
                _LegendItem(
                  icon: Icons.warning,
                  color: Colors.orange,
                  text: 'Anderes Training',
                ),
                _LegendItem(
                  icon: Icons.bedtime,
                  color: Colors.blueGrey,
                  text: 'Rest Day',
                ),
                _LegendItem(
                  icon: Icons.fitness_center,
                  color: Colors.blue,
                  text: 'Extra Training',
                ),
                _LegendItem(
                  icon: Icons.sports_soccer,
                  color: Colors.grey,
                  text: 'Geplant',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final daysInMonth = _daysInMonth(_currentMonth);
    final firstWeekday = _firstWeekday(_currentMonth);

    final totalCells = ((firstWeekday + daysInMonth) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        if (index < firstWeekday || index >= firstWeekday + daysInMonth) {
          return const SizedBox();
        }

        final dayNumber = index - firstWeekday + 1;

        final day = DateTime(
          _currentMonth.year,
          _currentMonth.month,
          dayNumber,
        );

        final workout = _workoutForDay(day);
        final planned = _weeklyPlan[day.weekday];

        final now = DateTime.now();

        final isToday =
            day.year == now.year &&
            day.month == now.month &&
            day.day == now.day;

        final status = _getDayStatus(day);

        return GestureDetector(
          onTap: () {
            if (planned == 'Fußball') {
              _toggleFootball(day);
              return;
            }

            if (workout != null) {
              _showWorkout(workout);
              return;
            }

            _showDayDetails(day);
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isToday ? Border.all(width: 2) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Icon(
                  status == 'completed'
                      ? Icons.check_circle
                      : status == 'missed'
                      ? Icons.cancel
                      : status == 'different'
                      ? Icons.warning
                      : status == 'rest'
                      ? Icons.bedtime
                      : status == 'extra'
                      ? Icons.fitness_center
                      : planned == 'Fußball'
                      ? Icons.sports_soccer
                      : Icons.circle_outlined,
                  color: status == 'completed'
                      ? Colors.green
                      : status == 'missed'
                      ? Colors.red
                      : status == 'different'
                      ? Colors.orange
                      : status == 'rest'
                      ? Colors.blueGrey
                      : status == 'extra'
                      ? Colors.blue
                      : planned == 'Fußball'
                      ? Colors.grey
                      : Colors.grey,
                  size: 14,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// Wochenstatistik
// ============================================================

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _LegendItem({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}
