// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dailyMinutesMeta = const VerificationMeta(
    'dailyMinutes',
  );
  @override
  late final GeneratedColumn<int> dailyMinutes = GeneratedColumn<int>(
    'daily_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _streakMeta = const VerificationMeta('streak');
  @override
  late final GeneratedColumn<int> streak = GeneratedColumn<int>(
    'streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastStudyDateMeta = const VerificationMeta(
    'lastStudyDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastStudyDate =
      GeneratedColumn<DateTime>(
        'last_study_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    level,
    dailyMinutes,
    streak,
    lastStudyDate,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('daily_minutes')) {
      context.handle(
        _dailyMinutesMeta,
        dailyMinutes.isAcceptableOrUnknown(
          data['daily_minutes']!,
          _dailyMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dailyMinutesMeta);
    }
    if (data.containsKey('streak')) {
      context.handle(
        _streakMeta,
        streak.isAcceptableOrUnknown(data['streak']!, _streakMeta),
      );
    }
    if (data.containsKey('last_study_date')) {
      context.handle(
        _lastStudyDateMeta,
        lastStudyDate.isAcceptableOrUnknown(
          data['last_study_date']!,
          _lastStudyDateMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      dailyMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_minutes'],
      )!,
      streak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak'],
      )!,
      lastStudyDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_study_date'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final int id;
  final String name;

  /// DifficultyLevel.code — B1-, B1, B1+, B2-, B2, B2+
  final String level;
  final int dailyMinutes;
  final int streak;
  final DateTime? lastStudyDate;
  final DateTime createdAt;
  const UserProfile({
    required this.id,
    required this.name,
    required this.level,
    required this.dailyMinutes,
    required this.streak,
    this.lastStudyDate,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['level'] = Variable<String>(level);
    map['daily_minutes'] = Variable<int>(dailyMinutes);
    map['streak'] = Variable<int>(streak);
    if (!nullToAbsent || lastStudyDate != null) {
      map['last_study_date'] = Variable<DateTime>(lastStudyDate);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      name: Value(name),
      level: Value(level),
      dailyMinutes: Value(dailyMinutes),
      streak: Value(streak),
      lastStudyDate: lastStudyDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStudyDate),
      createdAt: Value(createdAt),
    );
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      level: serializer.fromJson<String>(json['level']),
      dailyMinutes: serializer.fromJson<int>(json['dailyMinutes']),
      streak: serializer.fromJson<int>(json['streak']),
      lastStudyDate: serializer.fromJson<DateTime?>(json['lastStudyDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'level': serializer.toJson<String>(level),
      'dailyMinutes': serializer.toJson<int>(dailyMinutes),
      'streak': serializer.toJson<int>(streak),
      'lastStudyDate': serializer.toJson<DateTime?>(lastStudyDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  UserProfile copyWith({
    int? id,
    String? name,
    String? level,
    int? dailyMinutes,
    int? streak,
    Value<DateTime?> lastStudyDate = const Value.absent(),
    DateTime? createdAt,
  }) => UserProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    level: level ?? this.level,
    dailyMinutes: dailyMinutes ?? this.dailyMinutes,
    streak: streak ?? this.streak,
    lastStudyDate: lastStudyDate.present
        ? lastStudyDate.value
        : this.lastStudyDate,
    createdAt: createdAt ?? this.createdAt,
  );
  UserProfile copyWithCompanion(UserProfilesCompanion data) {
    return UserProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      level: data.level.present ? data.level.value : this.level,
      dailyMinutes: data.dailyMinutes.present
          ? data.dailyMinutes.value
          : this.dailyMinutes,
      streak: data.streak.present ? data.streak.value : this.streak,
      lastStudyDate: data.lastStudyDate.present
          ? data.lastStudyDate.value
          : this.lastStudyDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('level: $level, ')
          ..write('dailyMinutes: $dailyMinutes, ')
          ..write('streak: $streak, ')
          ..write('lastStudyDate: $lastStudyDate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    level,
    dailyMinutes,
    streak,
    lastStudyDate,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.level == this.level &&
          other.dailyMinutes == this.dailyMinutes &&
          other.streak == this.streak &&
          other.lastStudyDate == this.lastStudyDate &&
          other.createdAt == this.createdAt);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfile> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> level;
  final Value<int> dailyMinutes;
  final Value<int> streak;
  final Value<DateTime?> lastStudyDate;
  final Value<DateTime> createdAt;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.level = const Value.absent(),
    this.dailyMinutes = const Value.absent(),
    this.streak = const Value.absent(),
    this.lastStudyDate = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String level,
    required int dailyMinutes,
    this.streak = const Value.absent(),
    this.lastStudyDate = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       level = Value(level),
       dailyMinutes = Value(dailyMinutes);
  static Insertable<UserProfile> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? level,
    Expression<int>? dailyMinutes,
    Expression<int>? streak,
    Expression<DateTime>? lastStudyDate,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (level != null) 'level': level,
      if (dailyMinutes != null) 'daily_minutes': dailyMinutes,
      if (streak != null) 'streak': streak,
      if (lastStudyDate != null) 'last_study_date': lastStudyDate,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UserProfilesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? level,
    Value<int>? dailyMinutes,
    Value<int>? streak,
    Value<DateTime?>? lastStudyDate,
    Value<DateTime>? createdAt,
  }) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      streak: streak ?? this.streak,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (dailyMinutes.present) {
      map['daily_minutes'] = Variable<int>(dailyMinutes.value);
    }
    if (streak.present) {
      map['streak'] = Variable<int>(streak.value);
    }
    if (lastStudyDate.present) {
      map['last_study_date'] = Variable<DateTime>(lastStudyDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('level: $level, ')
          ..write('dailyMinutes: $dailyMinutes, ')
          ..write('streak: $streak, ')
          ..write('lastStudyDate: $lastStudyDate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $WeeklyPlanDaysTable extends WeeklyPlanDays
    with TableInfo<$WeeklyPlanDaysTable, WeeklyPlanDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeklyPlanDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _weekStartMeta = const VerificationMeta(
    'weekStart',
  );
  @override
  late final GeneratedColumn<DateTime> weekStart = GeneratedColumn<DateTime>(
    'week_start',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayIndexMeta = const VerificationMeta(
    'dayIndex',
  );
  @override
  late final GeneratedColumn<int> dayIndex = GeneratedColumn<int>(
    'day_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _grammarTopicMeta = const VerificationMeta(
    'grammarTopic',
  );
  @override
  late final GeneratedColumn<String> grammarTopic = GeneratedColumn<String>(
    'grammar_topic',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vocabThemeMeta = const VerificationMeta(
    'vocabTheme',
  );
  @override
  late final GeneratedColumn<String> vocabTheme = GeneratedColumn<String>(
    'vocab_theme',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    weekStart,
    dayIndex,
    grammarTopic,
    vocabTheme,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_plan_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeeklyPlanDay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('week_start')) {
      context.handle(
        _weekStartMeta,
        weekStart.isAcceptableOrUnknown(data['week_start']!, _weekStartMeta),
      );
    } else if (isInserting) {
      context.missing(_weekStartMeta);
    }
    if (data.containsKey('day_index')) {
      context.handle(
        _dayIndexMeta,
        dayIndex.isAcceptableOrUnknown(data['day_index']!, _dayIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_dayIndexMeta);
    }
    if (data.containsKey('grammar_topic')) {
      context.handle(
        _grammarTopicMeta,
        grammarTopic.isAcceptableOrUnknown(
          data['grammar_topic']!,
          _grammarTopicMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_grammarTopicMeta);
    }
    if (data.containsKey('vocab_theme')) {
      context.handle(
        _vocabThemeMeta,
        vocabTheme.isAcceptableOrUnknown(data['vocab_theme']!, _vocabThemeMeta),
      );
    } else if (isInserting) {
      context.missing(_vocabThemeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WeeklyPlanDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeeklyPlanDay(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      weekStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}week_start'],
      )!,
      dayIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_index'],
      )!,
      grammarTopic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grammar_topic'],
      )!,
      vocabTheme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vocab_theme'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $WeeklyPlanDaysTable createAlias(String alias) {
    return $WeeklyPlanDaysTable(attachedDatabase, alias);
  }
}

class WeeklyPlanDay extends DataClass implements Insertable<WeeklyPlanDay> {
  final int id;

  /// Haftanın pazartesi tarihi (gün 00:00)
  final DateTime weekStart;

  /// 0 = Pazartesi ... 6 = Pazar
  final int dayIndex;

  /// Günün dilbilgisi konusu (ör. "Present Perfect vs Past Simple")
  final String grammarTopic;

  /// Günün kelime teması (ör. "Seyahat ve ulaşım")
  final String vocabTheme;

  /// pending | completed | skipped
  final String status;
  const WeeklyPlanDay({
    required this.id,
    required this.weekStart,
    required this.dayIndex,
    required this.grammarTopic,
    required this.vocabTheme,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['week_start'] = Variable<DateTime>(weekStart);
    map['day_index'] = Variable<int>(dayIndex);
    map['grammar_topic'] = Variable<String>(grammarTopic);
    map['vocab_theme'] = Variable<String>(vocabTheme);
    map['status'] = Variable<String>(status);
    return map;
  }

  WeeklyPlanDaysCompanion toCompanion(bool nullToAbsent) {
    return WeeklyPlanDaysCompanion(
      id: Value(id),
      weekStart: Value(weekStart),
      dayIndex: Value(dayIndex),
      grammarTopic: Value(grammarTopic),
      vocabTheme: Value(vocabTheme),
      status: Value(status),
    );
  }

  factory WeeklyPlanDay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeeklyPlanDay(
      id: serializer.fromJson<int>(json['id']),
      weekStart: serializer.fromJson<DateTime>(json['weekStart']),
      dayIndex: serializer.fromJson<int>(json['dayIndex']),
      grammarTopic: serializer.fromJson<String>(json['grammarTopic']),
      vocabTheme: serializer.fromJson<String>(json['vocabTheme']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'weekStart': serializer.toJson<DateTime>(weekStart),
      'dayIndex': serializer.toJson<int>(dayIndex),
      'grammarTopic': serializer.toJson<String>(grammarTopic),
      'vocabTheme': serializer.toJson<String>(vocabTheme),
      'status': serializer.toJson<String>(status),
    };
  }

  WeeklyPlanDay copyWith({
    int? id,
    DateTime? weekStart,
    int? dayIndex,
    String? grammarTopic,
    String? vocabTheme,
    String? status,
  }) => WeeklyPlanDay(
    id: id ?? this.id,
    weekStart: weekStart ?? this.weekStart,
    dayIndex: dayIndex ?? this.dayIndex,
    grammarTopic: grammarTopic ?? this.grammarTopic,
    vocabTheme: vocabTheme ?? this.vocabTheme,
    status: status ?? this.status,
  );
  WeeklyPlanDay copyWithCompanion(WeeklyPlanDaysCompanion data) {
    return WeeklyPlanDay(
      id: data.id.present ? data.id.value : this.id,
      weekStart: data.weekStart.present ? data.weekStart.value : this.weekStart,
      dayIndex: data.dayIndex.present ? data.dayIndex.value : this.dayIndex,
      grammarTopic: data.grammarTopic.present
          ? data.grammarTopic.value
          : this.grammarTopic,
      vocabTheme: data.vocabTheme.present
          ? data.vocabTheme.value
          : this.vocabTheme,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyPlanDay(')
          ..write('id: $id, ')
          ..write('weekStart: $weekStart, ')
          ..write('dayIndex: $dayIndex, ')
          ..write('grammarTopic: $grammarTopic, ')
          ..write('vocabTheme: $vocabTheme, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, weekStart, dayIndex, grammarTopic, vocabTheme, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklyPlanDay &&
          other.id == this.id &&
          other.weekStart == this.weekStart &&
          other.dayIndex == this.dayIndex &&
          other.grammarTopic == this.grammarTopic &&
          other.vocabTheme == this.vocabTheme &&
          other.status == this.status);
}

class WeeklyPlanDaysCompanion extends UpdateCompanion<WeeklyPlanDay> {
  final Value<int> id;
  final Value<DateTime> weekStart;
  final Value<int> dayIndex;
  final Value<String> grammarTopic;
  final Value<String> vocabTheme;
  final Value<String> status;
  const WeeklyPlanDaysCompanion({
    this.id = const Value.absent(),
    this.weekStart = const Value.absent(),
    this.dayIndex = const Value.absent(),
    this.grammarTopic = const Value.absent(),
    this.vocabTheme = const Value.absent(),
    this.status = const Value.absent(),
  });
  WeeklyPlanDaysCompanion.insert({
    this.id = const Value.absent(),
    required DateTime weekStart,
    required int dayIndex,
    required String grammarTopic,
    required String vocabTheme,
    this.status = const Value.absent(),
  }) : weekStart = Value(weekStart),
       dayIndex = Value(dayIndex),
       grammarTopic = Value(grammarTopic),
       vocabTheme = Value(vocabTheme);
  static Insertable<WeeklyPlanDay> custom({
    Expression<int>? id,
    Expression<DateTime>? weekStart,
    Expression<int>? dayIndex,
    Expression<String>? grammarTopic,
    Expression<String>? vocabTheme,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (weekStart != null) 'week_start': weekStart,
      if (dayIndex != null) 'day_index': dayIndex,
      if (grammarTopic != null) 'grammar_topic': grammarTopic,
      if (vocabTheme != null) 'vocab_theme': vocabTheme,
      if (status != null) 'status': status,
    });
  }

  WeeklyPlanDaysCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? weekStart,
    Value<int>? dayIndex,
    Value<String>? grammarTopic,
    Value<String>? vocabTheme,
    Value<String>? status,
  }) {
    return WeeklyPlanDaysCompanion(
      id: id ?? this.id,
      weekStart: weekStart ?? this.weekStart,
      dayIndex: dayIndex ?? this.dayIndex,
      grammarTopic: grammarTopic ?? this.grammarTopic,
      vocabTheme: vocabTheme ?? this.vocabTheme,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (weekStart.present) {
      map['week_start'] = Variable<DateTime>(weekStart.value);
    }
    if (dayIndex.present) {
      map['day_index'] = Variable<int>(dayIndex.value);
    }
    if (grammarTopic.present) {
      map['grammar_topic'] = Variable<String>(grammarTopic.value);
    }
    if (vocabTheme.present) {
      map['vocab_theme'] = Variable<String>(vocabTheme.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyPlanDaysCompanion(')
          ..write('id: $id, ')
          ..write('weekStart: $weekStart, ')
          ..write('dayIndex: $dayIndex, ')
          ..write('grammarTopic: $grammarTopic, ')
          ..write('vocabTheme: $vocabTheme, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $LessonsTable extends Lessons with TableInfo<$LessonsTable, Lesson> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _lessonDateMeta = const VerificationMeta(
    'lessonDate',
  );
  @override
  late final GeneratedColumn<DateTime> lessonDate = GeneratedColumn<DateTime>(
    'lesson_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentJsonMeta = const VerificationMeta(
    'contentJson',
  );
  @override
  late final GeneratedColumn<String> contentJson = GeneratedColumn<String>(
    'content_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lessonDate,
    contentJson,
    score,
    durationSeconds,
    completed,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lessons';
  @override
  VerificationContext validateIntegrity(
    Insertable<Lesson> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lesson_date')) {
      context.handle(
        _lessonDateMeta,
        lessonDate.isAcceptableOrUnknown(data['lesson_date']!, _lessonDateMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonDateMeta);
    }
    if (data.containsKey('content_json')) {
      context.handle(
        _contentJsonMeta,
        contentJson.isAcceptableOrUnknown(
          data['content_json']!,
          _contentJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentJsonMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Lesson map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Lesson(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lessonDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lesson_date'],
      )!,
      contentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_json'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LessonsTable createAlias(String alias) {
    return $LessonsTable(attachedDatabase, alias);
  }
}

class Lesson extends DataClass implements Insertable<Lesson> {
  final int id;

  /// Dersin ait olduğu gün (00:00)
  final DateTime lessonDate;

  /// Gemini'nin ürettiği ders içeriği (JSON) — günlük önbellek.
  final String contentJson;

  /// 0-100 arası skor; null = henüz bitmedi.
  final double? score;
  final int durationSeconds;
  final bool completed;
  final DateTime createdAt;
  const Lesson({
    required this.id,
    required this.lessonDate,
    required this.contentJson,
    this.score,
    required this.durationSeconds,
    required this.completed,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lesson_date'] = Variable<DateTime>(lessonDate);
    map['content_json'] = Variable<String>(contentJson);
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<double>(score);
    }
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['completed'] = Variable<bool>(completed);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LessonsCompanion toCompanion(bool nullToAbsent) {
    return LessonsCompanion(
      id: Value(id),
      lessonDate: Value(lessonDate),
      contentJson: Value(contentJson),
      score: score == null && nullToAbsent
          ? const Value.absent()
          : Value(score),
      durationSeconds: Value(durationSeconds),
      completed: Value(completed),
      createdAt: Value(createdAt),
    );
  }

  factory Lesson.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Lesson(
      id: serializer.fromJson<int>(json['id']),
      lessonDate: serializer.fromJson<DateTime>(json['lessonDate']),
      contentJson: serializer.fromJson<String>(json['contentJson']),
      score: serializer.fromJson<double?>(json['score']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      completed: serializer.fromJson<bool>(json['completed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lessonDate': serializer.toJson<DateTime>(lessonDate),
      'contentJson': serializer.toJson<String>(contentJson),
      'score': serializer.toJson<double?>(score),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'completed': serializer.toJson<bool>(completed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Lesson copyWith({
    int? id,
    DateTime? lessonDate,
    String? contentJson,
    Value<double?> score = const Value.absent(),
    int? durationSeconds,
    bool? completed,
    DateTime? createdAt,
  }) => Lesson(
    id: id ?? this.id,
    lessonDate: lessonDate ?? this.lessonDate,
    contentJson: contentJson ?? this.contentJson,
    score: score.present ? score.value : this.score,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    completed: completed ?? this.completed,
    createdAt: createdAt ?? this.createdAt,
  );
  Lesson copyWithCompanion(LessonsCompanion data) {
    return Lesson(
      id: data.id.present ? data.id.value : this.id,
      lessonDate: data.lessonDate.present
          ? data.lessonDate.value
          : this.lessonDate,
      contentJson: data.contentJson.present
          ? data.contentJson.value
          : this.contentJson,
      score: data.score.present ? data.score.value : this.score,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      completed: data.completed.present ? data.completed.value : this.completed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Lesson(')
          ..write('id: $id, ')
          ..write('lessonDate: $lessonDate, ')
          ..write('contentJson: $contentJson, ')
          ..write('score: $score, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('completed: $completed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lessonDate,
    contentJson,
    score,
    durationSeconds,
    completed,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Lesson &&
          other.id == this.id &&
          other.lessonDate == this.lessonDate &&
          other.contentJson == this.contentJson &&
          other.score == this.score &&
          other.durationSeconds == this.durationSeconds &&
          other.completed == this.completed &&
          other.createdAt == this.createdAt);
}

class LessonsCompanion extends UpdateCompanion<Lesson> {
  final Value<int> id;
  final Value<DateTime> lessonDate;
  final Value<String> contentJson;
  final Value<double?> score;
  final Value<int> durationSeconds;
  final Value<bool> completed;
  final Value<DateTime> createdAt;
  const LessonsCompanion({
    this.id = const Value.absent(),
    this.lessonDate = const Value.absent(),
    this.contentJson = const Value.absent(),
    this.score = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.completed = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LessonsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime lessonDate,
    required String contentJson,
    this.score = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.completed = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : lessonDate = Value(lessonDate),
       contentJson = Value(contentJson);
  static Insertable<Lesson> custom({
    Expression<int>? id,
    Expression<DateTime>? lessonDate,
    Expression<String>? contentJson,
    Expression<double>? score,
    Expression<int>? durationSeconds,
    Expression<bool>? completed,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lessonDate != null) 'lesson_date': lessonDate,
      if (contentJson != null) 'content_json': contentJson,
      if (score != null) 'score': score,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (completed != null) 'completed': completed,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LessonsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? lessonDate,
    Value<String>? contentJson,
    Value<double?>? score,
    Value<int>? durationSeconds,
    Value<bool>? completed,
    Value<DateTime>? createdAt,
  }) {
    return LessonsCompanion(
      id: id ?? this.id,
      lessonDate: lessonDate ?? this.lessonDate,
      contentJson: contentJson ?? this.contentJson,
      score: score ?? this.score,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lessonDate.present) {
      map['lesson_date'] = Variable<DateTime>(lessonDate.value);
    }
    if (contentJson.present) {
      map['content_json'] = Variable<String>(contentJson.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonsCompanion(')
          ..write('id: $id, ')
          ..write('lessonDate: $lessonDate, ')
          ..write('contentJson: $contentJson, ')
          ..write('score: $score, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('completed: $completed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MistakesTable extends Mistakes with TableInfo<$MistakesTable, Mistake> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MistakesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _itemMeta = const VerificationMeta('item');
  @override
  late final GeneratedColumn<String> item = GeneratedColumn<String>(
    'item',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contextMeta = const VerificationMeta(
    'context',
  );
  @override
  late final GeneratedColumn<String> context = GeneratedColumn<String>(
    'context',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timesWrongMeta = const VerificationMeta(
    'timesWrong',
  );
  @override
  late final GeneratedColumn<int> timesWrong = GeneratedColumn<int>(
    'times_wrong',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _timesCorrectMeta = const VerificationMeta(
    'timesCorrect',
  );
  @override
  late final GeneratedColumn<int> timesCorrect = GeneratedColumn<int>(
    'times_correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAskedAtMeta = const VerificationMeta(
    'lastAskedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAskedAt = GeneratedColumn<DateTime>(
    'last_asked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolvedMeta = const VerificationMeta(
    'resolved',
  );
  @override
  late final GeneratedColumn<bool> resolved = GeneratedColumn<bool>(
    'resolved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("resolved" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    item,
    context,
    type,
    timesWrong,
    timesCorrect,
    lastAskedAt,
    resolved,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mistakes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Mistake> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('item')) {
      context.handle(
        _itemMeta,
        item.isAcceptableOrUnknown(data['item']!, _itemMeta),
      );
    } else if (isInserting) {
      context.missing(_itemMeta);
    }
    if (data.containsKey('context')) {
      context.handle(
        _contextMeta,
        this.context.isAcceptableOrUnknown(data['context']!, _contextMeta),
      );
    } else if (isInserting) {
      context.missing(_contextMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('times_wrong')) {
      context.handle(
        _timesWrongMeta,
        timesWrong.isAcceptableOrUnknown(data['times_wrong']!, _timesWrongMeta),
      );
    }
    if (data.containsKey('times_correct')) {
      context.handle(
        _timesCorrectMeta,
        timesCorrect.isAcceptableOrUnknown(
          data['times_correct']!,
          _timesCorrectMeta,
        ),
      );
    }
    if (data.containsKey('last_asked_at')) {
      context.handle(
        _lastAskedAtMeta,
        lastAskedAt.isAcceptableOrUnknown(
          data['last_asked_at']!,
          _lastAskedAtMeta,
        ),
      );
    }
    if (data.containsKey('resolved')) {
      context.handle(
        _resolvedMeta,
        resolved.isAcceptableOrUnknown(data['resolved']!, _resolvedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Mistake map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Mistake(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      item: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item'],
      )!,
      context: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      timesWrong: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}times_wrong'],
      )!,
      timesCorrect: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}times_correct'],
      )!,
      lastAskedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_asked_at'],
      ),
      resolved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}resolved'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MistakesTable createAlias(String alias) {
    return $MistakesTable(attachedDatabase, alias);
  }
}

class Mistake extends DataClass implements Insertable<Mistake> {
  final int id;

  /// Hatalı kelime veya kalıp (ör. "make a decision")
  final String item;

  /// Hatanın geçtiği cümle/bağlam
  final String context;

  /// translation | grammar | vocabulary | chat
  final String type;
  final int timesWrong;
  final int timesCorrect;
  final DateTime? lastAskedAt;

  /// 3+ kez doğru yapılınca çözülmüş sayılır.
  final bool resolved;
  final DateTime createdAt;
  const Mistake({
    required this.id,
    required this.item,
    required this.context,
    required this.type,
    required this.timesWrong,
    required this.timesCorrect,
    this.lastAskedAt,
    required this.resolved,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['item'] = Variable<String>(item);
    map['context'] = Variable<String>(context);
    map['type'] = Variable<String>(type);
    map['times_wrong'] = Variable<int>(timesWrong);
    map['times_correct'] = Variable<int>(timesCorrect);
    if (!nullToAbsent || lastAskedAt != null) {
      map['last_asked_at'] = Variable<DateTime>(lastAskedAt);
    }
    map['resolved'] = Variable<bool>(resolved);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MistakesCompanion toCompanion(bool nullToAbsent) {
    return MistakesCompanion(
      id: Value(id),
      item: Value(item),
      context: Value(context),
      type: Value(type),
      timesWrong: Value(timesWrong),
      timesCorrect: Value(timesCorrect),
      lastAskedAt: lastAskedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAskedAt),
      resolved: Value(resolved),
      createdAt: Value(createdAt),
    );
  }

  factory Mistake.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Mistake(
      id: serializer.fromJson<int>(json['id']),
      item: serializer.fromJson<String>(json['item']),
      context: serializer.fromJson<String>(json['context']),
      type: serializer.fromJson<String>(json['type']),
      timesWrong: serializer.fromJson<int>(json['timesWrong']),
      timesCorrect: serializer.fromJson<int>(json['timesCorrect']),
      lastAskedAt: serializer.fromJson<DateTime?>(json['lastAskedAt']),
      resolved: serializer.fromJson<bool>(json['resolved']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'item': serializer.toJson<String>(item),
      'context': serializer.toJson<String>(context),
      'type': serializer.toJson<String>(type),
      'timesWrong': serializer.toJson<int>(timesWrong),
      'timesCorrect': serializer.toJson<int>(timesCorrect),
      'lastAskedAt': serializer.toJson<DateTime?>(lastAskedAt),
      'resolved': serializer.toJson<bool>(resolved),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Mistake copyWith({
    int? id,
    String? item,
    String? context,
    String? type,
    int? timesWrong,
    int? timesCorrect,
    Value<DateTime?> lastAskedAt = const Value.absent(),
    bool? resolved,
    DateTime? createdAt,
  }) => Mistake(
    id: id ?? this.id,
    item: item ?? this.item,
    context: context ?? this.context,
    type: type ?? this.type,
    timesWrong: timesWrong ?? this.timesWrong,
    timesCorrect: timesCorrect ?? this.timesCorrect,
    lastAskedAt: lastAskedAt.present ? lastAskedAt.value : this.lastAskedAt,
    resolved: resolved ?? this.resolved,
    createdAt: createdAt ?? this.createdAt,
  );
  Mistake copyWithCompanion(MistakesCompanion data) {
    return Mistake(
      id: data.id.present ? data.id.value : this.id,
      item: data.item.present ? data.item.value : this.item,
      context: data.context.present ? data.context.value : this.context,
      type: data.type.present ? data.type.value : this.type,
      timesWrong: data.timesWrong.present
          ? data.timesWrong.value
          : this.timesWrong,
      timesCorrect: data.timesCorrect.present
          ? data.timesCorrect.value
          : this.timesCorrect,
      lastAskedAt: data.lastAskedAt.present
          ? data.lastAskedAt.value
          : this.lastAskedAt,
      resolved: data.resolved.present ? data.resolved.value : this.resolved,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Mistake(')
          ..write('id: $id, ')
          ..write('item: $item, ')
          ..write('context: $context, ')
          ..write('type: $type, ')
          ..write('timesWrong: $timesWrong, ')
          ..write('timesCorrect: $timesCorrect, ')
          ..write('lastAskedAt: $lastAskedAt, ')
          ..write('resolved: $resolved, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    item,
    context,
    type,
    timesWrong,
    timesCorrect,
    lastAskedAt,
    resolved,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mistake &&
          other.id == this.id &&
          other.item == this.item &&
          other.context == this.context &&
          other.type == this.type &&
          other.timesWrong == this.timesWrong &&
          other.timesCorrect == this.timesCorrect &&
          other.lastAskedAt == this.lastAskedAt &&
          other.resolved == this.resolved &&
          other.createdAt == this.createdAt);
}

class MistakesCompanion extends UpdateCompanion<Mistake> {
  final Value<int> id;
  final Value<String> item;
  final Value<String> context;
  final Value<String> type;
  final Value<int> timesWrong;
  final Value<int> timesCorrect;
  final Value<DateTime?> lastAskedAt;
  final Value<bool> resolved;
  final Value<DateTime> createdAt;
  const MistakesCompanion({
    this.id = const Value.absent(),
    this.item = const Value.absent(),
    this.context = const Value.absent(),
    this.type = const Value.absent(),
    this.timesWrong = const Value.absent(),
    this.timesCorrect = const Value.absent(),
    this.lastAskedAt = const Value.absent(),
    this.resolved = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MistakesCompanion.insert({
    this.id = const Value.absent(),
    required String item,
    required String context,
    required String type,
    this.timesWrong = const Value.absent(),
    this.timesCorrect = const Value.absent(),
    this.lastAskedAt = const Value.absent(),
    this.resolved = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : item = Value(item),
       context = Value(context),
       type = Value(type);
  static Insertable<Mistake> custom({
    Expression<int>? id,
    Expression<String>? item,
    Expression<String>? context,
    Expression<String>? type,
    Expression<int>? timesWrong,
    Expression<int>? timesCorrect,
    Expression<DateTime>? lastAskedAt,
    Expression<bool>? resolved,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (item != null) 'item': item,
      if (context != null) 'context': context,
      if (type != null) 'type': type,
      if (timesWrong != null) 'times_wrong': timesWrong,
      if (timesCorrect != null) 'times_correct': timesCorrect,
      if (lastAskedAt != null) 'last_asked_at': lastAskedAt,
      if (resolved != null) 'resolved': resolved,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MistakesCompanion copyWith({
    Value<int>? id,
    Value<String>? item,
    Value<String>? context,
    Value<String>? type,
    Value<int>? timesWrong,
    Value<int>? timesCorrect,
    Value<DateTime?>? lastAskedAt,
    Value<bool>? resolved,
    Value<DateTime>? createdAt,
  }) {
    return MistakesCompanion(
      id: id ?? this.id,
      item: item ?? this.item,
      context: context ?? this.context,
      type: type ?? this.type,
      timesWrong: timesWrong ?? this.timesWrong,
      timesCorrect: timesCorrect ?? this.timesCorrect,
      lastAskedAt: lastAskedAt ?? this.lastAskedAt,
      resolved: resolved ?? this.resolved,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (item.present) {
      map['item'] = Variable<String>(item.value);
    }
    if (context.present) {
      map['context'] = Variable<String>(context.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (timesWrong.present) {
      map['times_wrong'] = Variable<int>(timesWrong.value);
    }
    if (timesCorrect.present) {
      map['times_correct'] = Variable<int>(timesCorrect.value);
    }
    if (lastAskedAt.present) {
      map['last_asked_at'] = Variable<DateTime>(lastAskedAt.value);
    }
    if (resolved.present) {
      map['resolved'] = Variable<bool>(resolved.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MistakesCompanion(')
          ..write('id: $id, ')
          ..write('item: $item, ')
          ..write('context: $context, ')
          ..write('type: $type, ')
          ..write('timesWrong: $timesWrong, ')
          ..write('timesCorrect: $timesCorrect, ')
          ..write('lastAskedAt: $lastAskedAt, ')
          ..write('resolved: $resolved, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $FlashcardsTable extends Flashcards
    with TableInfo<$FlashcardsTable, Flashcard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlashcardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meaningMeta = const VerificationMeta(
    'meaning',
  );
  @override
  late final GeneratedColumn<String> meaning = GeneratedColumn<String>(
    'meaning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exampleSentenceMeta = const VerificationMeta(
    'exampleSentence',
  );
  @override
  late final GeneratedColumn<String> exampleSentence = GeneratedColumn<String>(
    'example_sentence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _easeMeta = const VerificationMeta('ease');
  @override
  late final GeneratedColumn<double> ease = GeneratedColumn<double>(
    'ease',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.5),
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    word,
    meaning,
    exampleSentence,
    source,
    ease,
    intervalDays,
    reps,
    dueDate,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flashcards';
  @override
  VerificationContext validateIntegrity(
    Insertable<Flashcard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('meaning')) {
      context.handle(
        _meaningMeta,
        meaning.isAcceptableOrUnknown(data['meaning']!, _meaningMeta),
      );
    } else if (isInserting) {
      context.missing(_meaningMeta);
    }
    if (data.containsKey('example_sentence')) {
      context.handle(
        _exampleSentenceMeta,
        exampleSentence.isAcceptableOrUnknown(
          data['example_sentence']!,
          _exampleSentenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exampleSentenceMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('ease')) {
      context.handle(
        _easeMeta,
        ease.isAcceptableOrUnknown(data['ease']!, _easeMeta),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Flashcard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Flashcard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      meaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning'],
      )!,
      exampleSentence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example_sentence'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      ease: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ease'],
      )!,
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FlashcardsTable createAlias(String alias) {
    return $FlashcardsTable(attachedDatabase, alias);
  }
}

class Flashcard extends DataClass implements Insertable<Flashcard> {
  final int id;
  final String word;
  final String meaning;
  final String exampleSentence;

  /// new_word | mistake
  final String source;
  final double ease;
  final int intervalDays;
  final int reps;
  final DateTime dueDate;
  final DateTime createdAt;
  const Flashcard({
    required this.id,
    required this.word,
    required this.meaning,
    required this.exampleSentence,
    required this.source,
    required this.ease,
    required this.intervalDays,
    required this.reps,
    required this.dueDate,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['word'] = Variable<String>(word);
    map['meaning'] = Variable<String>(meaning);
    map['example_sentence'] = Variable<String>(exampleSentence);
    map['source'] = Variable<String>(source);
    map['ease'] = Variable<double>(ease);
    map['interval_days'] = Variable<int>(intervalDays);
    map['reps'] = Variable<int>(reps);
    map['due_date'] = Variable<DateTime>(dueDate);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FlashcardsCompanion toCompanion(bool nullToAbsent) {
    return FlashcardsCompanion(
      id: Value(id),
      word: Value(word),
      meaning: Value(meaning),
      exampleSentence: Value(exampleSentence),
      source: Value(source),
      ease: Value(ease),
      intervalDays: Value(intervalDays),
      reps: Value(reps),
      dueDate: Value(dueDate),
      createdAt: Value(createdAt),
    );
  }

  factory Flashcard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Flashcard(
      id: serializer.fromJson<int>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      meaning: serializer.fromJson<String>(json['meaning']),
      exampleSentence: serializer.fromJson<String>(json['exampleSentence']),
      source: serializer.fromJson<String>(json['source']),
      ease: serializer.fromJson<double>(json['ease']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      reps: serializer.fromJson<int>(json['reps']),
      dueDate: serializer.fromJson<DateTime>(json['dueDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'word': serializer.toJson<String>(word),
      'meaning': serializer.toJson<String>(meaning),
      'exampleSentence': serializer.toJson<String>(exampleSentence),
      'source': serializer.toJson<String>(source),
      'ease': serializer.toJson<double>(ease),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'reps': serializer.toJson<int>(reps),
      'dueDate': serializer.toJson<DateTime>(dueDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Flashcard copyWith({
    int? id,
    String? word,
    String? meaning,
    String? exampleSentence,
    String? source,
    double? ease,
    int? intervalDays,
    int? reps,
    DateTime? dueDate,
    DateTime? createdAt,
  }) => Flashcard(
    id: id ?? this.id,
    word: word ?? this.word,
    meaning: meaning ?? this.meaning,
    exampleSentence: exampleSentence ?? this.exampleSentence,
    source: source ?? this.source,
    ease: ease ?? this.ease,
    intervalDays: intervalDays ?? this.intervalDays,
    reps: reps ?? this.reps,
    dueDate: dueDate ?? this.dueDate,
    createdAt: createdAt ?? this.createdAt,
  );
  Flashcard copyWithCompanion(FlashcardsCompanion data) {
    return Flashcard(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      meaning: data.meaning.present ? data.meaning.value : this.meaning,
      exampleSentence: data.exampleSentence.present
          ? data.exampleSentence.value
          : this.exampleSentence,
      source: data.source.present ? data.source.value : this.source,
      ease: data.ease.present ? data.ease.value : this.ease,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      reps: data.reps.present ? data.reps.value : this.reps,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Flashcard(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('meaning: $meaning, ')
          ..write('exampleSentence: $exampleSentence, ')
          ..write('source: $source, ')
          ..write('ease: $ease, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('reps: $reps, ')
          ..write('dueDate: $dueDate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    word,
    meaning,
    exampleSentence,
    source,
    ease,
    intervalDays,
    reps,
    dueDate,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Flashcard &&
          other.id == this.id &&
          other.word == this.word &&
          other.meaning == this.meaning &&
          other.exampleSentence == this.exampleSentence &&
          other.source == this.source &&
          other.ease == this.ease &&
          other.intervalDays == this.intervalDays &&
          other.reps == this.reps &&
          other.dueDate == this.dueDate &&
          other.createdAt == this.createdAt);
}

class FlashcardsCompanion extends UpdateCompanion<Flashcard> {
  final Value<int> id;
  final Value<String> word;
  final Value<String> meaning;
  final Value<String> exampleSentence;
  final Value<String> source;
  final Value<double> ease;
  final Value<int> intervalDays;
  final Value<int> reps;
  final Value<DateTime> dueDate;
  final Value<DateTime> createdAt;
  const FlashcardsCompanion({
    this.id = const Value.absent(),
    this.word = const Value.absent(),
    this.meaning = const Value.absent(),
    this.exampleSentence = const Value.absent(),
    this.source = const Value.absent(),
    this.ease = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.reps = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FlashcardsCompanion.insert({
    this.id = const Value.absent(),
    required String word,
    required String meaning,
    required String exampleSentence,
    required String source,
    this.ease = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.reps = const Value.absent(),
    required DateTime dueDate,
    this.createdAt = const Value.absent(),
  }) : word = Value(word),
       meaning = Value(meaning),
       exampleSentence = Value(exampleSentence),
       source = Value(source),
       dueDate = Value(dueDate);
  static Insertable<Flashcard> custom({
    Expression<int>? id,
    Expression<String>? word,
    Expression<String>? meaning,
    Expression<String>? exampleSentence,
    Expression<String>? source,
    Expression<double>? ease,
    Expression<int>? intervalDays,
    Expression<int>? reps,
    Expression<DateTime>? dueDate,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (meaning != null) 'meaning': meaning,
      if (exampleSentence != null) 'example_sentence': exampleSentence,
      if (source != null) 'source': source,
      if (ease != null) 'ease': ease,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (reps != null) 'reps': reps,
      if (dueDate != null) 'due_date': dueDate,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FlashcardsCompanion copyWith({
    Value<int>? id,
    Value<String>? word,
    Value<String>? meaning,
    Value<String>? exampleSentence,
    Value<String>? source,
    Value<double>? ease,
    Value<int>? intervalDays,
    Value<int>? reps,
    Value<DateTime>? dueDate,
    Value<DateTime>? createdAt,
  }) {
    return FlashcardsCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      source: source ?? this.source,
      ease: ease ?? this.ease,
      intervalDays: intervalDays ?? this.intervalDays,
      reps: reps ?? this.reps,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (meaning.present) {
      map['meaning'] = Variable<String>(meaning.value);
    }
    if (exampleSentence.present) {
      map['example_sentence'] = Variable<String>(exampleSentence.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (ease.present) {
      map['ease'] = Variable<double>(ease.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlashcardsCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('meaning: $meaning, ')
          ..write('exampleSentence: $exampleSentence, ')
          ..write('source: $source, ')
          ..write('ease: $ease, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('reps: $reps, ')
          ..write('dueDate: $dueDate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $StoriesTable extends Stories with TableInfo<$StoriesTable, Story> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _storyDateMeta = const VerificationMeta(
    'storyDate',
  );
  @override
  late final GeneratedColumn<DateTime> storyDate = GeneratedColumn<DateTime>(
    'story_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentJsonMeta = const VerificationMeta(
    'contentJson',
  );
  @override
  late final GeneratedColumn<String> contentJson = GeneratedColumn<String>(
    'content_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quizScoreMeta = const VerificationMeta(
    'quizScore',
  );
  @override
  late final GeneratedColumn<double> quizScore = GeneratedColumn<double>(
    'quiz_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storyDate,
    title,
    contentJson,
    quizScore,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Story> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('story_date')) {
      context.handle(
        _storyDateMeta,
        storyDate.isAcceptableOrUnknown(data['story_date']!, _storyDateMeta),
      );
    } else if (isInserting) {
      context.missing(_storyDateMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content_json')) {
      context.handle(
        _contentJsonMeta,
        contentJson.isAcceptableOrUnknown(
          data['content_json']!,
          _contentJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentJsonMeta);
    }
    if (data.containsKey('quiz_score')) {
      context.handle(
        _quizScoreMeta,
        quizScore.isAcceptableOrUnknown(data['quiz_score']!, _quizScoreMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Story map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Story(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      storyDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}story_date'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      contentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_json'],
      )!,
      quizScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quiz_score'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StoriesTable createAlias(String alias) {
    return $StoriesTable(attachedDatabase, alias);
  }
}

class Story extends DataClass implements Insertable<Story> {
  final int id;
  final DateTime storyDate;
  final String title;

  /// Hikaye metni + sorular (JSON)
  final String contentJson;

  /// Test skoru 0-100; null = çözülmedi.
  final double? quizScore;
  final DateTime createdAt;
  const Story({
    required this.id,
    required this.storyDate,
    required this.title,
    required this.contentJson,
    this.quizScore,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['story_date'] = Variable<DateTime>(storyDate);
    map['title'] = Variable<String>(title);
    map['content_json'] = Variable<String>(contentJson);
    if (!nullToAbsent || quizScore != null) {
      map['quiz_score'] = Variable<double>(quizScore);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StoriesCompanion toCompanion(bool nullToAbsent) {
    return StoriesCompanion(
      id: Value(id),
      storyDate: Value(storyDate),
      title: Value(title),
      contentJson: Value(contentJson),
      quizScore: quizScore == null && nullToAbsent
          ? const Value.absent()
          : Value(quizScore),
      createdAt: Value(createdAt),
    );
  }

  factory Story.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Story(
      id: serializer.fromJson<int>(json['id']),
      storyDate: serializer.fromJson<DateTime>(json['storyDate']),
      title: serializer.fromJson<String>(json['title']),
      contentJson: serializer.fromJson<String>(json['contentJson']),
      quizScore: serializer.fromJson<double?>(json['quizScore']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'storyDate': serializer.toJson<DateTime>(storyDate),
      'title': serializer.toJson<String>(title),
      'contentJson': serializer.toJson<String>(contentJson),
      'quizScore': serializer.toJson<double?>(quizScore),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Story copyWith({
    int? id,
    DateTime? storyDate,
    String? title,
    String? contentJson,
    Value<double?> quizScore = const Value.absent(),
    DateTime? createdAt,
  }) => Story(
    id: id ?? this.id,
    storyDate: storyDate ?? this.storyDate,
    title: title ?? this.title,
    contentJson: contentJson ?? this.contentJson,
    quizScore: quizScore.present ? quizScore.value : this.quizScore,
    createdAt: createdAt ?? this.createdAt,
  );
  Story copyWithCompanion(StoriesCompanion data) {
    return Story(
      id: data.id.present ? data.id.value : this.id,
      storyDate: data.storyDate.present ? data.storyDate.value : this.storyDate,
      title: data.title.present ? data.title.value : this.title,
      contentJson: data.contentJson.present
          ? data.contentJson.value
          : this.contentJson,
      quizScore: data.quizScore.present ? data.quizScore.value : this.quizScore,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Story(')
          ..write('id: $id, ')
          ..write('storyDate: $storyDate, ')
          ..write('title: $title, ')
          ..write('contentJson: $contentJson, ')
          ..write('quizScore: $quizScore, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, storyDate, title, contentJson, quizScore, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Story &&
          other.id == this.id &&
          other.storyDate == this.storyDate &&
          other.title == this.title &&
          other.contentJson == this.contentJson &&
          other.quizScore == this.quizScore &&
          other.createdAt == this.createdAt);
}

class StoriesCompanion extends UpdateCompanion<Story> {
  final Value<int> id;
  final Value<DateTime> storyDate;
  final Value<String> title;
  final Value<String> contentJson;
  final Value<double?> quizScore;
  final Value<DateTime> createdAt;
  const StoriesCompanion({
    this.id = const Value.absent(),
    this.storyDate = const Value.absent(),
    this.title = const Value.absent(),
    this.contentJson = const Value.absent(),
    this.quizScore = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  StoriesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime storyDate,
    required String title,
    required String contentJson,
    this.quizScore = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : storyDate = Value(storyDate),
       title = Value(title),
       contentJson = Value(contentJson);
  static Insertable<Story> custom({
    Expression<int>? id,
    Expression<DateTime>? storyDate,
    Expression<String>? title,
    Expression<String>? contentJson,
    Expression<double>? quizScore,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storyDate != null) 'story_date': storyDate,
      if (title != null) 'title': title,
      if (contentJson != null) 'content_json': contentJson,
      if (quizScore != null) 'quiz_score': quizScore,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  StoriesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? storyDate,
    Value<String>? title,
    Value<String>? contentJson,
    Value<double?>? quizScore,
    Value<DateTime>? createdAt,
  }) {
    return StoriesCompanion(
      id: id ?? this.id,
      storyDate: storyDate ?? this.storyDate,
      title: title ?? this.title,
      contentJson: contentJson ?? this.contentJson,
      quizScore: quizScore ?? this.quizScore,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (storyDate.present) {
      map['story_date'] = Variable<DateTime>(storyDate.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (contentJson.present) {
      map['content_json'] = Variable<String>(contentJson.value);
    }
    if (quizScore.present) {
      map['quiz_score'] = Variable<double>(quizScore.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoriesCompanion(')
          ..write('id: $id, ')
          ..write('storyDate: $storyDate, ')
          ..write('title: $title, ')
          ..write('contentJson: $contentJson, ')
          ..write('quizScore: $quizScore, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $WeeklyReviewsTable extends WeeklyReviews
    with TableInfo<$WeeklyReviewsTable, WeeklyReview> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeklyReviewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _weekStartMeta = const VerificationMeta(
    'weekStart',
  );
  @override
  late final GeneratedColumn<DateTime> weekStart = GeneratedColumn<DateTime>(
    'week_start',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reportJsonMeta = const VerificationMeta(
    'reportJson',
  );
  @override
  late final GeneratedColumn<String> reportJson = GeneratedColumn<String>(
    'report_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, weekStart, reportJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_reviews';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeeklyReview> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('week_start')) {
      context.handle(
        _weekStartMeta,
        weekStart.isAcceptableOrUnknown(data['week_start']!, _weekStartMeta),
      );
    } else if (isInserting) {
      context.missing(_weekStartMeta);
    }
    if (data.containsKey('report_json')) {
      context.handle(
        _reportJsonMeta,
        reportJson.isAcceptableOrUnknown(data['report_json']!, _reportJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_reportJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WeeklyReview map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeeklyReview(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      weekStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}week_start'],
      )!,
      reportJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}report_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WeeklyReviewsTable createAlias(String alias) {
    return $WeeklyReviewsTable(attachedDatabase, alias);
  }
}

class WeeklyReview extends DataClass implements Insertable<WeeklyReview> {
  final int id;
  final DateTime weekStart;

  /// Gemini raporu (JSON)
  final String reportJson;
  final DateTime createdAt;
  const WeeklyReview({
    required this.id,
    required this.weekStart,
    required this.reportJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['week_start'] = Variable<DateTime>(weekStart);
    map['report_json'] = Variable<String>(reportJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WeeklyReviewsCompanion toCompanion(bool nullToAbsent) {
    return WeeklyReviewsCompanion(
      id: Value(id),
      weekStart: Value(weekStart),
      reportJson: Value(reportJson),
      createdAt: Value(createdAt),
    );
  }

  factory WeeklyReview.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeeklyReview(
      id: serializer.fromJson<int>(json['id']),
      weekStart: serializer.fromJson<DateTime>(json['weekStart']),
      reportJson: serializer.fromJson<String>(json['reportJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'weekStart': serializer.toJson<DateTime>(weekStart),
      'reportJson': serializer.toJson<String>(reportJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WeeklyReview copyWith({
    int? id,
    DateTime? weekStart,
    String? reportJson,
    DateTime? createdAt,
  }) => WeeklyReview(
    id: id ?? this.id,
    weekStart: weekStart ?? this.weekStart,
    reportJson: reportJson ?? this.reportJson,
    createdAt: createdAt ?? this.createdAt,
  );
  WeeklyReview copyWithCompanion(WeeklyReviewsCompanion data) {
    return WeeklyReview(
      id: data.id.present ? data.id.value : this.id,
      weekStart: data.weekStart.present ? data.weekStart.value : this.weekStart,
      reportJson: data.reportJson.present
          ? data.reportJson.value
          : this.reportJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyReview(')
          ..write('id: $id, ')
          ..write('weekStart: $weekStart, ')
          ..write('reportJson: $reportJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, weekStart, reportJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklyReview &&
          other.id == this.id &&
          other.weekStart == this.weekStart &&
          other.reportJson == this.reportJson &&
          other.createdAt == this.createdAt);
}

class WeeklyReviewsCompanion extends UpdateCompanion<WeeklyReview> {
  final Value<int> id;
  final Value<DateTime> weekStart;
  final Value<String> reportJson;
  final Value<DateTime> createdAt;
  const WeeklyReviewsCompanion({
    this.id = const Value.absent(),
    this.weekStart = const Value.absent(),
    this.reportJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WeeklyReviewsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime weekStart,
    required String reportJson,
    this.createdAt = const Value.absent(),
  }) : weekStart = Value(weekStart),
       reportJson = Value(reportJson);
  static Insertable<WeeklyReview> custom({
    Expression<int>? id,
    Expression<DateTime>? weekStart,
    Expression<String>? reportJson,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (weekStart != null) 'week_start': weekStart,
      if (reportJson != null) 'report_json': reportJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WeeklyReviewsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? weekStart,
    Value<String>? reportJson,
    Value<DateTime>? createdAt,
  }) {
    return WeeklyReviewsCompanion(
      id: id ?? this.id,
      weekStart: weekStart ?? this.weekStart,
      reportJson: reportJson ?? this.reportJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (weekStart.present) {
      map['week_start'] = Variable<DateTime>(weekStart.value);
    }
    if (reportJson.present) {
      map['report_json'] = Variable<String>(reportJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyReviewsCompanion(')
          ..write('id: $id, ')
          ..write('weekStart: $weekStart, ')
          ..write('reportJson: $reportJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $WeeklyPlanDaysTable weeklyPlanDays = $WeeklyPlanDaysTable(this);
  late final $LessonsTable lessons = $LessonsTable(this);
  late final $MistakesTable mistakes = $MistakesTable(this);
  late final $FlashcardsTable flashcards = $FlashcardsTable(this);
  late final $StoriesTable stories = $StoriesTable(this);
  late final $WeeklyReviewsTable weeklyReviews = $WeeklyReviewsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userProfiles,
    weeklyPlanDays,
    lessons,
    mistakes,
    flashcards,
    stories,
    weeklyReviews,
  ];
}

typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      required String name,
      required String level,
      required int dailyMinutes,
      Value<int> streak,
      Value<DateTime?> lastStudyDate,
      Value<DateTime> createdAt,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> level,
      Value<int> dailyMinutes,
      Value<int> streak,
      Value<DateTime?> lastStudyDate,
      Value<DateTime> createdAt,
    });

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyMinutes => $composableBuilder(
    column: $table.dailyMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastStudyDate => $composableBuilder(
    column: $table.lastStudyDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyMinutes => $composableBuilder(
    column: $table.dailyMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastStudyDate => $composableBuilder(
    column: $table.lastStudyDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get dailyMinutes => $composableBuilder(
    column: $table.dailyMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get streak =>
      $composableBuilder(column: $table.streak, builder: (column) => column);

  GeneratedColumn<DateTime> get lastStudyDate => $composableBuilder(
    column: $table.lastStudyDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTable,
          UserProfile,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (
            UserProfile,
            BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
          ),
          UserProfile,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<int> dailyMinutes = const Value.absent(),
                Value<int> streak = const Value.absent(),
                Value<DateTime?> lastStudyDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => UserProfilesCompanion(
                id: id,
                name: name,
                level: level,
                dailyMinutes: dailyMinutes,
                streak: streak,
                lastStudyDate: lastStudyDate,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String level,
                required int dailyMinutes,
                Value<int> streak = const Value.absent(),
                Value<DateTime?> lastStudyDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => UserProfilesCompanion.insert(
                id: id,
                name: name,
                level: level,
                dailyMinutes: dailyMinutes,
                streak: streak,
                lastStudyDate: lastStudyDate,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTable,
      UserProfile,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (
        UserProfile,
        BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
      ),
      UserProfile,
      PrefetchHooks Function()
    >;
typedef $$WeeklyPlanDaysTableCreateCompanionBuilder =
    WeeklyPlanDaysCompanion Function({
      Value<int> id,
      required DateTime weekStart,
      required int dayIndex,
      required String grammarTopic,
      required String vocabTheme,
      Value<String> status,
    });
typedef $$WeeklyPlanDaysTableUpdateCompanionBuilder =
    WeeklyPlanDaysCompanion Function({
      Value<int> id,
      Value<DateTime> weekStart,
      Value<int> dayIndex,
      Value<String> grammarTopic,
      Value<String> vocabTheme,
      Value<String> status,
    });

class $$WeeklyPlanDaysTableFilterComposer
    extends Composer<_$AppDatabase, $WeeklyPlanDaysTable> {
  $$WeeklyPlanDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayIndex => $composableBuilder(
    column: $table.dayIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grammarTopic => $composableBuilder(
    column: $table.grammarTopic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vocabTheme => $composableBuilder(
    column: $table.vocabTheme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeeklyPlanDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $WeeklyPlanDaysTable> {
  $$WeeklyPlanDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayIndex => $composableBuilder(
    column: $table.dayIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grammarTopic => $composableBuilder(
    column: $table.grammarTopic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vocabTheme => $composableBuilder(
    column: $table.vocabTheme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeeklyPlanDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeeklyPlanDaysTable> {
  $$WeeklyPlanDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get weekStart =>
      $composableBuilder(column: $table.weekStart, builder: (column) => column);

  GeneratedColumn<int> get dayIndex =>
      $composableBuilder(column: $table.dayIndex, builder: (column) => column);

  GeneratedColumn<String> get grammarTopic => $composableBuilder(
    column: $table.grammarTopic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vocabTheme => $composableBuilder(
    column: $table.vocabTheme,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$WeeklyPlanDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeeklyPlanDaysTable,
          WeeklyPlanDay,
          $$WeeklyPlanDaysTableFilterComposer,
          $$WeeklyPlanDaysTableOrderingComposer,
          $$WeeklyPlanDaysTableAnnotationComposer,
          $$WeeklyPlanDaysTableCreateCompanionBuilder,
          $$WeeklyPlanDaysTableUpdateCompanionBuilder,
          (
            WeeklyPlanDay,
            BaseReferences<_$AppDatabase, $WeeklyPlanDaysTable, WeeklyPlanDay>,
          ),
          WeeklyPlanDay,
          PrefetchHooks Function()
        > {
  $$WeeklyPlanDaysTableTableManager(
    _$AppDatabase db,
    $WeeklyPlanDaysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeeklyPlanDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeeklyPlanDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeeklyPlanDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> weekStart = const Value.absent(),
                Value<int> dayIndex = const Value.absent(),
                Value<String> grammarTopic = const Value.absent(),
                Value<String> vocabTheme = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => WeeklyPlanDaysCompanion(
                id: id,
                weekStart: weekStart,
                dayIndex: dayIndex,
                grammarTopic: grammarTopic,
                vocabTheme: vocabTheme,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime weekStart,
                required int dayIndex,
                required String grammarTopic,
                required String vocabTheme,
                Value<String> status = const Value.absent(),
              }) => WeeklyPlanDaysCompanion.insert(
                id: id,
                weekStart: weekStart,
                dayIndex: dayIndex,
                grammarTopic: grammarTopic,
                vocabTheme: vocabTheme,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeeklyPlanDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeeklyPlanDaysTable,
      WeeklyPlanDay,
      $$WeeklyPlanDaysTableFilterComposer,
      $$WeeklyPlanDaysTableOrderingComposer,
      $$WeeklyPlanDaysTableAnnotationComposer,
      $$WeeklyPlanDaysTableCreateCompanionBuilder,
      $$WeeklyPlanDaysTableUpdateCompanionBuilder,
      (
        WeeklyPlanDay,
        BaseReferences<_$AppDatabase, $WeeklyPlanDaysTable, WeeklyPlanDay>,
      ),
      WeeklyPlanDay,
      PrefetchHooks Function()
    >;
typedef $$LessonsTableCreateCompanionBuilder =
    LessonsCompanion Function({
      Value<int> id,
      required DateTime lessonDate,
      required String contentJson,
      Value<double?> score,
      Value<int> durationSeconds,
      Value<bool> completed,
      Value<DateTime> createdAt,
    });
typedef $$LessonsTableUpdateCompanionBuilder =
    LessonsCompanion Function({
      Value<int> id,
      Value<DateTime> lessonDate,
      Value<String> contentJson,
      Value<double?> score,
      Value<int> durationSeconds,
      Value<bool> completed,
      Value<DateTime> createdAt,
    });

class $$LessonsTableFilterComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lessonDate => $composableBuilder(
    column: $table.lessonDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LessonsTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lessonDate => $composableBuilder(
    column: $table.lessonDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LessonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonsTable> {
  $$LessonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get lessonDate => $composableBuilder(
    column: $table.lessonDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LessonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LessonsTable,
          Lesson,
          $$LessonsTableFilterComposer,
          $$LessonsTableOrderingComposer,
          $$LessonsTableAnnotationComposer,
          $$LessonsTableCreateCompanionBuilder,
          $$LessonsTableUpdateCompanionBuilder,
          (Lesson, BaseReferences<_$AppDatabase, $LessonsTable, Lesson>),
          Lesson,
          PrefetchHooks Function()
        > {
  $$LessonsTableTableManager(_$AppDatabase db, $LessonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LessonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LessonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LessonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> lessonDate = const Value.absent(),
                Value<String> contentJson = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LessonsCompanion(
                id: id,
                lessonDate: lessonDate,
                contentJson: contentJson,
                score: score,
                durationSeconds: durationSeconds,
                completed: completed,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime lessonDate,
                required String contentJson,
                Value<double?> score = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LessonsCompanion.insert(
                id: id,
                lessonDate: lessonDate,
                contentJson: contentJson,
                score: score,
                durationSeconds: durationSeconds,
                completed: completed,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LessonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LessonsTable,
      Lesson,
      $$LessonsTableFilterComposer,
      $$LessonsTableOrderingComposer,
      $$LessonsTableAnnotationComposer,
      $$LessonsTableCreateCompanionBuilder,
      $$LessonsTableUpdateCompanionBuilder,
      (Lesson, BaseReferences<_$AppDatabase, $LessonsTable, Lesson>),
      Lesson,
      PrefetchHooks Function()
    >;
typedef $$MistakesTableCreateCompanionBuilder =
    MistakesCompanion Function({
      Value<int> id,
      required String item,
      required String context,
      required String type,
      Value<int> timesWrong,
      Value<int> timesCorrect,
      Value<DateTime?> lastAskedAt,
      Value<bool> resolved,
      Value<DateTime> createdAt,
    });
typedef $$MistakesTableUpdateCompanionBuilder =
    MistakesCompanion Function({
      Value<int> id,
      Value<String> item,
      Value<String> context,
      Value<String> type,
      Value<int> timesWrong,
      Value<int> timesCorrect,
      Value<DateTime?> lastAskedAt,
      Value<bool> resolved,
      Value<DateTime> createdAt,
    });

class $$MistakesTableFilterComposer
    extends Composer<_$AppDatabase, $MistakesTable> {
  $$MistakesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get item => $composableBuilder(
    column: $table.item,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timesWrong => $composableBuilder(
    column: $table.timesWrong,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timesCorrect => $composableBuilder(
    column: $table.timesCorrect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAskedAt => $composableBuilder(
    column: $table.lastAskedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get resolved => $composableBuilder(
    column: $table.resolved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MistakesTableOrderingComposer
    extends Composer<_$AppDatabase, $MistakesTable> {
  $$MistakesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get item => $composableBuilder(
    column: $table.item,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timesWrong => $composableBuilder(
    column: $table.timesWrong,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timesCorrect => $composableBuilder(
    column: $table.timesCorrect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAskedAt => $composableBuilder(
    column: $table.lastAskedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get resolved => $composableBuilder(
    column: $table.resolved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MistakesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MistakesTable> {
  $$MistakesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get item =>
      $composableBuilder(column: $table.item, builder: (column) => column);

  GeneratedColumn<String> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get timesWrong => $composableBuilder(
    column: $table.timesWrong,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timesCorrect => $composableBuilder(
    column: $table.timesCorrect,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAskedAt => $composableBuilder(
    column: $table.lastAskedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get resolved =>
      $composableBuilder(column: $table.resolved, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MistakesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MistakesTable,
          Mistake,
          $$MistakesTableFilterComposer,
          $$MistakesTableOrderingComposer,
          $$MistakesTableAnnotationComposer,
          $$MistakesTableCreateCompanionBuilder,
          $$MistakesTableUpdateCompanionBuilder,
          (Mistake, BaseReferences<_$AppDatabase, $MistakesTable, Mistake>),
          Mistake,
          PrefetchHooks Function()
        > {
  $$MistakesTableTableManager(_$AppDatabase db, $MistakesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MistakesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MistakesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MistakesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> item = const Value.absent(),
                Value<String> context = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> timesWrong = const Value.absent(),
                Value<int> timesCorrect = const Value.absent(),
                Value<DateTime?> lastAskedAt = const Value.absent(),
                Value<bool> resolved = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MistakesCompanion(
                id: id,
                item: item,
                context: context,
                type: type,
                timesWrong: timesWrong,
                timesCorrect: timesCorrect,
                lastAskedAt: lastAskedAt,
                resolved: resolved,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String item,
                required String context,
                required String type,
                Value<int> timesWrong = const Value.absent(),
                Value<int> timesCorrect = const Value.absent(),
                Value<DateTime?> lastAskedAt = const Value.absent(),
                Value<bool> resolved = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MistakesCompanion.insert(
                id: id,
                item: item,
                context: context,
                type: type,
                timesWrong: timesWrong,
                timesCorrect: timesCorrect,
                lastAskedAt: lastAskedAt,
                resolved: resolved,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MistakesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MistakesTable,
      Mistake,
      $$MistakesTableFilterComposer,
      $$MistakesTableOrderingComposer,
      $$MistakesTableAnnotationComposer,
      $$MistakesTableCreateCompanionBuilder,
      $$MistakesTableUpdateCompanionBuilder,
      (Mistake, BaseReferences<_$AppDatabase, $MistakesTable, Mistake>),
      Mistake,
      PrefetchHooks Function()
    >;
typedef $$FlashcardsTableCreateCompanionBuilder =
    FlashcardsCompanion Function({
      Value<int> id,
      required String word,
      required String meaning,
      required String exampleSentence,
      required String source,
      Value<double> ease,
      Value<int> intervalDays,
      Value<int> reps,
      required DateTime dueDate,
      Value<DateTime> createdAt,
    });
typedef $$FlashcardsTableUpdateCompanionBuilder =
    FlashcardsCompanion Function({
      Value<int> id,
      Value<String> word,
      Value<String> meaning,
      Value<String> exampleSentence,
      Value<String> source,
      Value<double> ease,
      Value<int> intervalDays,
      Value<int> reps,
      Value<DateTime> dueDate,
      Value<DateTime> createdAt,
    });

class $$FlashcardsTableFilterComposer
    extends Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exampleSentence => $composableBuilder(
    column: $table.exampleSentence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ease => $composableBuilder(
    column: $table.ease,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FlashcardsTableOrderingComposer
    extends Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exampleSentence => $composableBuilder(
    column: $table.exampleSentence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ease => $composableBuilder(
    column: $table.ease,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FlashcardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => column);

  GeneratedColumn<String> get exampleSentence => $composableBuilder(
    column: $table.exampleSentence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<double> get ease =>
      $composableBuilder(column: $table.ease, builder: (column) => column);

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FlashcardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FlashcardsTable,
          Flashcard,
          $$FlashcardsTableFilterComposer,
          $$FlashcardsTableOrderingComposer,
          $$FlashcardsTableAnnotationComposer,
          $$FlashcardsTableCreateCompanionBuilder,
          $$FlashcardsTableUpdateCompanionBuilder,
          (
            Flashcard,
            BaseReferences<_$AppDatabase, $FlashcardsTable, Flashcard>,
          ),
          Flashcard,
          PrefetchHooks Function()
        > {
  $$FlashcardsTableTableManager(_$AppDatabase db, $FlashcardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlashcardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlashcardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlashcardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<String> meaning = const Value.absent(),
                Value<String> exampleSentence = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<double> ease = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<DateTime> dueDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FlashcardsCompanion(
                id: id,
                word: word,
                meaning: meaning,
                exampleSentence: exampleSentence,
                source: source,
                ease: ease,
                intervalDays: intervalDays,
                reps: reps,
                dueDate: dueDate,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String word,
                required String meaning,
                required String exampleSentence,
                required String source,
                Value<double> ease = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int> reps = const Value.absent(),
                required DateTime dueDate,
                Value<DateTime> createdAt = const Value.absent(),
              }) => FlashcardsCompanion.insert(
                id: id,
                word: word,
                meaning: meaning,
                exampleSentence: exampleSentence,
                source: source,
                ease: ease,
                intervalDays: intervalDays,
                reps: reps,
                dueDate: dueDate,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FlashcardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FlashcardsTable,
      Flashcard,
      $$FlashcardsTableFilterComposer,
      $$FlashcardsTableOrderingComposer,
      $$FlashcardsTableAnnotationComposer,
      $$FlashcardsTableCreateCompanionBuilder,
      $$FlashcardsTableUpdateCompanionBuilder,
      (Flashcard, BaseReferences<_$AppDatabase, $FlashcardsTable, Flashcard>),
      Flashcard,
      PrefetchHooks Function()
    >;
typedef $$StoriesTableCreateCompanionBuilder =
    StoriesCompanion Function({
      Value<int> id,
      required DateTime storyDate,
      required String title,
      required String contentJson,
      Value<double?> quizScore,
      Value<DateTime> createdAt,
    });
typedef $$StoriesTableUpdateCompanionBuilder =
    StoriesCompanion Function({
      Value<int> id,
      Value<DateTime> storyDate,
      Value<String> title,
      Value<String> contentJson,
      Value<double?> quizScore,
      Value<DateTime> createdAt,
    });

class $$StoriesTableFilterComposer
    extends Composer<_$AppDatabase, $StoriesTable> {
  $$StoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get storyDate => $composableBuilder(
    column: $table.storyDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quizScore => $composableBuilder(
    column: $table.quizScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $StoriesTable> {
  $$StoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get storyDate => $composableBuilder(
    column: $table.storyDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quizScore => $composableBuilder(
    column: $table.quizScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoriesTable> {
  $$StoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get storyDate =>
      $composableBuilder(column: $table.storyDate, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get quizScore =>
      $composableBuilder(column: $table.quizScore, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$StoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoriesTable,
          Story,
          $$StoriesTableFilterComposer,
          $$StoriesTableOrderingComposer,
          $$StoriesTableAnnotationComposer,
          $$StoriesTableCreateCompanionBuilder,
          $$StoriesTableUpdateCompanionBuilder,
          (Story, BaseReferences<_$AppDatabase, $StoriesTable, Story>),
          Story,
          PrefetchHooks Function()
        > {
  $$StoriesTableTableManager(_$AppDatabase db, $StoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> storyDate = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> contentJson = const Value.absent(),
                Value<double?> quizScore = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => StoriesCompanion(
                id: id,
                storyDate: storyDate,
                title: title,
                contentJson: contentJson,
                quizScore: quizScore,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime storyDate,
                required String title,
                required String contentJson,
                Value<double?> quizScore = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => StoriesCompanion.insert(
                id: id,
                storyDate: storyDate,
                title: title,
                contentJson: contentJson,
                quizScore: quizScore,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoriesTable,
      Story,
      $$StoriesTableFilterComposer,
      $$StoriesTableOrderingComposer,
      $$StoriesTableAnnotationComposer,
      $$StoriesTableCreateCompanionBuilder,
      $$StoriesTableUpdateCompanionBuilder,
      (Story, BaseReferences<_$AppDatabase, $StoriesTable, Story>),
      Story,
      PrefetchHooks Function()
    >;
typedef $$WeeklyReviewsTableCreateCompanionBuilder =
    WeeklyReviewsCompanion Function({
      Value<int> id,
      required DateTime weekStart,
      required String reportJson,
      Value<DateTime> createdAt,
    });
typedef $$WeeklyReviewsTableUpdateCompanionBuilder =
    WeeklyReviewsCompanion Function({
      Value<int> id,
      Value<DateTime> weekStart,
      Value<String> reportJson,
      Value<DateTime> createdAt,
    });

class $$WeeklyReviewsTableFilterComposer
    extends Composer<_$AppDatabase, $WeeklyReviewsTable> {
  $$WeeklyReviewsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reportJson => $composableBuilder(
    column: $table.reportJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeeklyReviewsTableOrderingComposer
    extends Composer<_$AppDatabase, $WeeklyReviewsTable> {
  $$WeeklyReviewsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get weekStart => $composableBuilder(
    column: $table.weekStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportJson => $composableBuilder(
    column: $table.reportJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeeklyReviewsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeeklyReviewsTable> {
  $$WeeklyReviewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get weekStart =>
      $composableBuilder(column: $table.weekStart, builder: (column) => column);

  GeneratedColumn<String> get reportJson => $composableBuilder(
    column: $table.reportJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WeeklyReviewsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeeklyReviewsTable,
          WeeklyReview,
          $$WeeklyReviewsTableFilterComposer,
          $$WeeklyReviewsTableOrderingComposer,
          $$WeeklyReviewsTableAnnotationComposer,
          $$WeeklyReviewsTableCreateCompanionBuilder,
          $$WeeklyReviewsTableUpdateCompanionBuilder,
          (
            WeeklyReview,
            BaseReferences<_$AppDatabase, $WeeklyReviewsTable, WeeklyReview>,
          ),
          WeeklyReview,
          PrefetchHooks Function()
        > {
  $$WeeklyReviewsTableTableManager(_$AppDatabase db, $WeeklyReviewsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeeklyReviewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeeklyReviewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeeklyReviewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> weekStart = const Value.absent(),
                Value<String> reportJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => WeeklyReviewsCompanion(
                id: id,
                weekStart: weekStart,
                reportJson: reportJson,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime weekStart,
                required String reportJson,
                Value<DateTime> createdAt = const Value.absent(),
              }) => WeeklyReviewsCompanion.insert(
                id: id,
                weekStart: weekStart,
                reportJson: reportJson,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeeklyReviewsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeeklyReviewsTable,
      WeeklyReview,
      $$WeeklyReviewsTableFilterComposer,
      $$WeeklyReviewsTableOrderingComposer,
      $$WeeklyReviewsTableAnnotationComposer,
      $$WeeklyReviewsTableCreateCompanionBuilder,
      $$WeeklyReviewsTableUpdateCompanionBuilder,
      (
        WeeklyReview,
        BaseReferences<_$AppDatabase, $WeeklyReviewsTable, WeeklyReview>,
      ),
      WeeklyReview,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$WeeklyPlanDaysTableTableManager get weeklyPlanDays =>
      $$WeeklyPlanDaysTableTableManager(_db, _db.weeklyPlanDays);
  $$LessonsTableTableManager get lessons =>
      $$LessonsTableTableManager(_db, _db.lessons);
  $$MistakesTableTableManager get mistakes =>
      $$MistakesTableTableManager(_db, _db.mistakes);
  $$FlashcardsTableTableManager get flashcards =>
      $$FlashcardsTableTableManager(_db, _db.flashcards);
  $$StoriesTableTableManager get stories =>
      $$StoriesTableTableManager(_db, _db.stories);
  $$WeeklyReviewsTableTableManager get weeklyReviews =>
      $$WeeklyReviewsTableTableManager(_db, _db.weeklyReviews);
}
