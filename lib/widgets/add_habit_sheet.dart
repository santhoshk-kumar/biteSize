import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';

/// Shows modal bottom sheet for creating or editing a custom habit.
Future<void> showAddHabitSheet(
  BuildContext context, {
  required AppState appState,
  HabitItem? existingHabit,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddHabitSheet(
      appState: appState,
      existingHabit: existingHabit,
    ),
  );
}

class _AddHabitSheet extends StatefulWidget {
  const _AddHabitSheet({
    required this.appState,
    this.existingHabit,
  });

  final AppState appState;
  final HabitItem? existingHabit;

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late String _selectedEmoji;
  late HabitCategory _selectedCategory;
  late HabitFrequency _selectedFrequency;
  late int _targetDaysPerWeek;
  late int _targetDaysPerMonth;
  late bool _reminderEnabled;
  late TimeOfDay _reminderTime;

  static const List<String> _popularEmojis = [
    '💧', '🏃', '🥗', '🏋️', '🧘', '🥦', '💊', '📖', '⏱️', '⚡', '🔥', '🥑', '😴', '🚶', '🎯',
  ];

  static const List<Map<String, dynamic>> _quickPresets = [
    {'title': 'Drink 3L Water', 'emoji': '💧', 'cat': HabitCategory.health, 'freq': HabitFrequency.daily},
    {'title': 'Morning 5km Walk', 'emoji': '🏃', 'cat': HabitCategory.fitness, 'freq': HabitFrequency.daily},
    {'title': 'No Added Sugar', 'emoji': '🥗', 'cat': HabitCategory.nutrition, 'freq': HabitFrequency.daily},
    {'title': 'Gym Strength Workout', 'emoji': '🏋️', 'cat': HabitCategory.fitness, 'freq': HabitFrequency.weekly, 'targetW': 4},
    {'title': '15 Min Stretching', 'emoji': '🧘', 'cat': HabitCategory.fitness, 'freq': HabitFrequency.daily},
    {'title': 'Take Vitamins / Creatine', 'emoji': '💊', 'cat': HabitCategory.health, 'freq': HabitFrequency.daily},
    {'title': 'Read 15 Pages', 'emoji': '📖', 'cat': HabitCategory.mindset, 'freq': HabitFrequency.daily},
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.existingHabit;
    _titleController = TextEditingController(text: h?.title ?? '');
    _descController = TextEditingController(text: h?.description ?? '');
    _selectedEmoji = h?.emoji ?? '🔥';
    _selectedCategory = h?.category ?? HabitCategory.health;
    _selectedFrequency = h?.frequency ?? HabitFrequency.daily;
    _targetDaysPerWeek = h?.targetDaysPerWeek ?? 5;
    _targetDaysPerMonth = h?.targetDaysPerMonth ?? 20;
    _reminderEnabled = h?.reminder?.isEnabled ?? false;
    _reminderTime = h?.reminder != null
        ? TimeOfDay(hour: h!.reminder!.hour, minute: h.reminder!.minute)
        : const TimeOfDay(hour: 8, minute: 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _applyPreset(Map<String, dynamic> preset) {
    ZenHaptics.selection();
    setState(() {
      _titleController.text = preset['title'] as String;
      _selectedEmoji = preset['emoji'] as String;
      _selectedCategory = preset['cat'] as HabitCategory;
      _selectedFrequency = preset['freq'] as HabitFrequency;
      if (preset['targetW'] != null) {
        _targetDaysPerWeek = preset['targetW'] as int;
      }
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: context.zen.sage,
              surface: const Color(0xFF161922),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    ZenHaptics.success();
    final reminder = _reminderEnabled
        ? HabitReminder(
            isEnabled: true,
            hour: _reminderTime.hour,
            minute: _reminderTime.minute,
          )
        : null;

    if (widget.existingHabit != null) {
      final updated = widget.existingHabit!.copyWith(
        title: title,
        description: _descController.text.trim(),
        emoji: _selectedEmoji,
        category: _selectedCategory,
        frequency: _selectedFrequency,
        targetDaysPerWeek: _targetDaysPerWeek,
        targetDaysPerMonth: _targetDaysPerMonth,
        reminder: reminder,
      );
      await widget.appState.updateHabit(updated);
    } else {
      final newHabit = HabitItem(
        id: 'habit_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        description: _descController.text.trim(),
        emoji: _selectedEmoji,
        category: _selectedCategory,
        frequency: _selectedFrequency,
        targetDaysPerWeek: _targetDaysPerWeek,
        targetDaysPerMonth: _targetDaysPerMonth,
        reminder: reminder,
      );
      await widget.appState.addHabit(newHabit);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      decoration: BoxDecoration(
        color: const Color(0xFF12141C),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: zen.sage.withValues(alpha: 0.15)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingHabit != null ? 'Edit Habit' : 'Create New Habit',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Presets Carousel
            if (widget.existingHabit == null) ...[
              const Text(
                'QUICK PRESETS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickPresets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final p = _quickPresets[i];
                    return ActionChip(
                      backgroundColor: const Color(0xFF1B1E2B),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      avatar: Text(p['emoji'] as String),
                      label: Text(
                        p['title'] as String,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                      onPressed: () => _applyPreset(p),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Title & Emoji Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected Emoji Button
                GestureDetector(
                  onTap: () {
                    // Quick modal or cycle
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selectedCategory.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _selectedCategory.color.withValues(alpha: 0.3)),
                    ),
                    child: Text(_selectedEmoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 12),
                // Title Input
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. 5km Morning Walk',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF181B26),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Emoji Selector Bar
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _popularEmojis.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (ctx, i) {
                  final e = _popularEmojis[i];
                  final isSelected = e == _selectedEmoji;
                  return GestureDetector(
                    onTap: () {
                      ZenHaptics.selection();
                      setState(() => _selectedEmoji = e);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? zen.sage.withValues(alpha: 0.25) : const Color(0xFF161922),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? zen.sage : Colors.white10,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 18)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // Frequency Option: Daily, Weekly, Monthly
            const Text(
              'REPEAT FREQUENCY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white54,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: HabitFrequency.values.map((freq) {
                final isSelected = freq == _selectedFrequency;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        ZenHaptics.selection();
                        setState(() => _selectedFrequency = freq);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? zen.sage.withValues(alpha: 0.2) : const Color(0xFF161924),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? zen.sage : Colors.white.withValues(alpha: 0.08),
                            width: isSelected ? 1.4 : 1.0,
                          ),
                        ),
                        child: Text(
                          freq.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? zen.sage : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Frequency Details Sub-row
            if (_selectedFrequency == HabitFrequency.weekly) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Target Days: $_targetDaysPerWeek times a week',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  Row(
                    children: [3, 4, 5, 6].map((days) {
                      final sel = _targetDaysPerWeek == days;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: InkWell(
                          onTap: () => setState(() => _targetDaysPerWeek = days),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: sel ? zen.sage : const Color(0xFF1E2130),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$days',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: sel ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ] else if (_selectedFrequency == HabitFrequency.monthly) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Target Days: $_targetDaysPerMonth days a month',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  Row(
                    children: [10, 15, 20, 25].map((days) {
                      final sel = _targetDaysPerMonth == days;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: InkWell(
                          onTap: () => setState(() => _targetDaysPerMonth = days),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: sel ? zen.sage : const Color(0xFF1E2130),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$days',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: sel ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),

            // Reminder & Notification Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161922),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: zen.sage.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_active_outlined, size: 20, color: zen.sage),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Reminder Notification',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        if (_reminderEnabled)
                          Text(
                            _reminderTime.format(context),
                            style: TextStyle(fontSize: 12, color: zen.sage, fontWeight: FontWeight.w600),
                          )
                        else
                          const Text(
                            'Off',
                            style: TextStyle(fontSize: 12, color: Colors.white38),
                          ),
                      ],
                    ),
                  ),
                  if (_reminderEnabled) ...[
                    TextButton(
                      onPressed: _pickTime,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: zen.sage,
                      ),
                      child: const Text('Change Time'),
                    ),
                  ],
                  Switch(
                    value: _reminderEnabled,
                    activeColor: zen.sage,
                    onChanged: (val) {
                      setState(() => _reminderEnabled = val);
                      if (val) _pickTime();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: zen.sage,
                  foregroundColor: const Color(0xFF090A0E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: Text(
                  widget.existingHabit != null ? 'Update Habit' : 'Start Tracking Habit 🔥',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
