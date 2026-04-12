enum RecurrencePeriod { once, weekly, monthly, quarterly, yearly }

class BillReminder {
  final String id;
  final String name;
  final double amount;
  final DateTime dueDate;
  final RecurrencePeriod recurrence;
  final String category;
  final bool enabled;
  final int reminderDaysBefore;
  final DateTime createdAt;

  BillReminder({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.recurrence = RecurrencePeriod.monthly,
    required this.category,
    this.enabled = true,
    this.reminderDaysBefore = 3,
    required this.createdAt,
  });

  bool get isDue {
    final now = DateTime.now();
    return dueDate.isBefore(now) || dueDate.isAtSameMomentAs(now);
  }

  bool get isUpcoming {
    final now = DateTime.now();
    final daysUntil = dueDate.difference(now).inDays;
    return daysUntil > 0 && daysUntil <= reminderDaysBefore;
  }

  DateTime? getNextDueDate() {
    if (recurrence == RecurrencePeriod.once) return dueDate;

    DateTime next = dueDate;
    final now = DateTime.now();

    while (next.isBefore(now)) {
      switch (recurrence) {
        case RecurrencePeriod.once:
          return dueDate;
        case RecurrencePeriod.weekly:
          next = next.add(const Duration(days: 7));
        case RecurrencePeriod.monthly:
          next = DateTime(next.year, next.month + 1, next.day);
        case RecurrencePeriod.quarterly:
          next = DateTime(next.year, next.month + 3, next.day);
        case RecurrencePeriod.yearly:
          next = DateTime(next.year + 1, next.month, next.day);
      }
    }
    return next;
  }

  BillReminder copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? dueDate,
    RecurrencePeriod? recurrence,
    String? category,
    bool? enabled,
    int? reminderDaysBefore,
    DateTime? createdAt,
  }) {
    return BillReminder(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      recurrence: recurrence ?? this.recurrence,
      category: category ?? this.category,
      enabled: enabled ?? this.enabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'due_date': dueDate.toIso8601String(),
      'recurrence': recurrence.index,
      'category': category,
      'enabled': enabled ? 1 : 0,
      'reminder_days_before': reminderDaysBefore,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BillReminder.fromMap(Map<String, dynamic> map) {
    return BillReminder(
      id: map['id'],
      name: map['name'],
      amount: (map['amount'] as num).toDouble(),
      dueDate: DateTime.parse(map['due_date']),
      recurrence: RecurrencePeriod.values[map['recurrence'] ?? 1],
      category: map['category'],
      enabled: (map['enabled'] ?? 1) == 1,
      reminderDaysBefore: map['reminder_days_before'] ?? 3,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  String get recurrenceText {
    switch (recurrence) {
      case RecurrencePeriod.once:
        return 'One-time';
      case RecurrencePeriod.weekly:
        return 'Weekly';
      case RecurrencePeriod.monthly:
        return 'Monthly';
      case RecurrencePeriod.quarterly:
        return 'Quarterly';
      case RecurrencePeriod.yearly:
        return 'Yearly';
    }
  }
}
