// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $HistoryRecordsTable extends HistoryRecords
    with TableInfo<$HistoryRecordsTable, HistoryRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryRecordsTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<HistoryActionType, String>
  actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<HistoryActionType>($HistoryRecordsTable.$converteractionType);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetRouteMeta = const VerificationMeta(
    'targetRoute',
  );
  @override
  late final GeneratedColumn<String> targetRoute = GeneratedColumn<String>(
    'target_route',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    actionType,
    title,
    description,
    targetRoute,
    payload,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('target_route')) {
      context.handle(
        _targetRouteMeta,
        targetRoute.isAcceptableOrUnknown(
          data['target_route']!,
          _targetRouteMeta,
        ),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      actionType: $HistoryRecordsTable.$converteractionType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}action_type'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      targetRoute: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_route'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HistoryRecordsTable createAlias(String alias) {
    return $HistoryRecordsTable(attachedDatabase, alias);
  }

  static TypeConverter<HistoryActionType, String> $converteractionType =
      const HistoryActionTypeConverter();
}

class HistoryRecord extends DataClass implements Insertable<HistoryRecord> {
  final int id;
  final HistoryActionType actionType;
  final String title;
  final String? description;
  final String? targetRoute;
  final String? payload;
  final DateTime createdAt;
  const HistoryRecord({
    required this.id,
    required this.actionType,
    required this.title,
    this.description,
    this.targetRoute,
    this.payload,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['action_type'] = Variable<String>(
        $HistoryRecordsTable.$converteractionType.toSql(actionType),
      );
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || targetRoute != null) {
      map['target_route'] = Variable<String>(targetRoute);
    }
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HistoryRecordsCompanion toCompanion(bool nullToAbsent) {
    return HistoryRecordsCompanion(
      id: Value(id),
      actionType: Value(actionType),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      targetRoute: targetRoute == null && nullToAbsent
          ? const Value.absent()
          : Value(targetRoute),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory HistoryRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryRecord(
      id: serializer.fromJson<int>(json['id']),
      actionType: serializer.fromJson<HistoryActionType>(json['actionType']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      targetRoute: serializer.fromJson<String?>(json['targetRoute']),
      payload: serializer.fromJson<String?>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'actionType': serializer.toJson<HistoryActionType>(actionType),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'targetRoute': serializer.toJson<String?>(targetRoute),
      'payload': serializer.toJson<String?>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HistoryRecord copyWith({
    int? id,
    HistoryActionType? actionType,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> targetRoute = const Value.absent(),
    Value<String?> payload = const Value.absent(),
    DateTime? createdAt,
  }) => HistoryRecord(
    id: id ?? this.id,
    actionType: actionType ?? this.actionType,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    targetRoute: targetRoute.present ? targetRoute.value : this.targetRoute,
    payload: payload.present ? payload.value : this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
  HistoryRecord copyWithCompanion(HistoryRecordsCompanion data) {
    return HistoryRecord(
      id: data.id.present ? data.id.value : this.id,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      targetRoute: data.targetRoute.present
          ? data.targetRoute.value
          : this.targetRoute,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRecord(')
          ..write('id: $id, ')
          ..write('actionType: $actionType, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('targetRoute: $targetRoute, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    actionType,
    title,
    description,
    targetRoute,
    payload,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryRecord &&
          other.id == this.id &&
          other.actionType == this.actionType &&
          other.title == this.title &&
          other.description == this.description &&
          other.targetRoute == this.targetRoute &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class HistoryRecordsCompanion extends UpdateCompanion<HistoryRecord> {
  final Value<int> id;
  final Value<HistoryActionType> actionType;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> targetRoute;
  final Value<String?> payload;
  final Value<DateTime> createdAt;
  const HistoryRecordsCompanion({
    this.id = const Value.absent(),
    this.actionType = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.targetRoute = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  HistoryRecordsCompanion.insert({
    this.id = const Value.absent(),
    required HistoryActionType actionType,
    required String title,
    this.description = const Value.absent(),
    this.targetRoute = const Value.absent(),
    this.payload = const Value.absent(),
    required DateTime createdAt,
  }) : actionType = Value(actionType),
       title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<HistoryRecord> custom({
    Expression<int>? id,
    Expression<String>? actionType,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? targetRoute,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (actionType != null) 'action_type': actionType,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (targetRoute != null) 'target_route': targetRoute,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  HistoryRecordsCompanion copyWith({
    Value<int>? id,
    Value<HistoryActionType>? actionType,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? targetRoute,
    Value<String?>? payload,
    Value<DateTime>? createdAt,
  }) {
    return HistoryRecordsCompanion(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      title: title ?? this.title,
      description: description ?? this.description,
      targetRoute: targetRoute ?? this.targetRoute,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(
        $HistoryRecordsTable.$converteractionType.toSql(actionType.value),
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (targetRoute.present) {
      map['target_route'] = Variable<String>(targetRoute.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRecordsCompanion(')
          ..write('id: $id, ')
          ..write('actionType: $actionType, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('targetRoute: $targetRoute, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RunLogRecordsTable extends RunLogRecords
    with TableInfo<$RunLogRecordsTable, RunLogRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunLogRecordsTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<RunLogLevel, String> level =
      GeneratedColumn<String>(
        'level',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RunLogLevel>($RunLogRecordsTable.$converterlevel);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    level,
    source,
    message,
    details,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_log_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunLogRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RunLogRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunLogRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      level: $RunLogRecordsTable.$converterlevel.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}level'],
        )!,
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RunLogRecordsTable createAlias(String alias) {
    return $RunLogRecordsTable(attachedDatabase, alias);
  }

  static TypeConverter<RunLogLevel, String> $converterlevel =
      const RunLogLevelConverter();
}

class RunLogRecord extends DataClass implements Insertable<RunLogRecord> {
  final int id;
  final RunLogLevel level;
  final String source;
  final String message;
  final String? details;
  final DateTime createdAt;
  const RunLogRecord({
    required this.id,
    required this.level,
    required this.source,
    required this.message,
    this.details,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['level'] = Variable<String>(
        $RunLogRecordsTable.$converterlevel.toSql(level),
      );
    }
    map['source'] = Variable<String>(source);
    map['message'] = Variable<String>(message);
    if (!nullToAbsent || details != null) {
      map['details'] = Variable<String>(details);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RunLogRecordsCompanion toCompanion(bool nullToAbsent) {
    return RunLogRecordsCompanion(
      id: Value(id),
      level: Value(level),
      source: Value(source),
      message: Value(message),
      details: details == null && nullToAbsent
          ? const Value.absent()
          : Value(details),
      createdAt: Value(createdAt),
    );
  }

  factory RunLogRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunLogRecord(
      id: serializer.fromJson<int>(json['id']),
      level: serializer.fromJson<RunLogLevel>(json['level']),
      source: serializer.fromJson<String>(json['source']),
      message: serializer.fromJson<String>(json['message']),
      details: serializer.fromJson<String?>(json['details']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'level': serializer.toJson<RunLogLevel>(level),
      'source': serializer.toJson<String>(source),
      'message': serializer.toJson<String>(message),
      'details': serializer.toJson<String?>(details),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RunLogRecord copyWith({
    int? id,
    RunLogLevel? level,
    String? source,
    String? message,
    Value<String?> details = const Value.absent(),
    DateTime? createdAt,
  }) => RunLogRecord(
    id: id ?? this.id,
    level: level ?? this.level,
    source: source ?? this.source,
    message: message ?? this.message,
    details: details.present ? details.value : this.details,
    createdAt: createdAt ?? this.createdAt,
  );
  RunLogRecord copyWithCompanion(RunLogRecordsCompanion data) {
    return RunLogRecord(
      id: data.id.present ? data.id.value : this.id,
      level: data.level.present ? data.level.value : this.level,
      source: data.source.present ? data.source.value : this.source,
      message: data.message.present ? data.message.value : this.message,
      details: data.details.present ? data.details.value : this.details,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunLogRecord(')
          ..write('id: $id, ')
          ..write('level: $level, ')
          ..write('source: $source, ')
          ..write('message: $message, ')
          ..write('details: $details, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, level, source, message, details, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunLogRecord &&
          other.id == this.id &&
          other.level == this.level &&
          other.source == this.source &&
          other.message == this.message &&
          other.details == this.details &&
          other.createdAt == this.createdAt);
}

class RunLogRecordsCompanion extends UpdateCompanion<RunLogRecord> {
  final Value<int> id;
  final Value<RunLogLevel> level;
  final Value<String> source;
  final Value<String> message;
  final Value<String?> details;
  final Value<DateTime> createdAt;
  const RunLogRecordsCompanion({
    this.id = const Value.absent(),
    this.level = const Value.absent(),
    this.source = const Value.absent(),
    this.message = const Value.absent(),
    this.details = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RunLogRecordsCompanion.insert({
    this.id = const Value.absent(),
    required RunLogLevel level,
    required String source,
    required String message,
    this.details = const Value.absent(),
    required DateTime createdAt,
  }) : level = Value(level),
       source = Value(source),
       message = Value(message),
       createdAt = Value(createdAt);
  static Insertable<RunLogRecord> custom({
    Expression<int>? id,
    Expression<String>? level,
    Expression<String>? source,
    Expression<String>? message,
    Expression<String>? details,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (level != null) 'level': level,
      if (source != null) 'source': source,
      if (message != null) 'message': message,
      if (details != null) 'details': details,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RunLogRecordsCompanion copyWith({
    Value<int>? id,
    Value<RunLogLevel>? level,
    Value<String>? source,
    Value<String>? message,
    Value<String?>? details,
    Value<DateTime>? createdAt,
  }) {
    return RunLogRecordsCompanion(
      id: id ?? this.id,
      level: level ?? this.level,
      source: source ?? this.source,
      message: message ?? this.message,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(
        $RunLogRecordsTable.$converterlevel.toSql(level.value),
      );
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunLogRecordsCompanion(')
          ..write('id: $id, ')
          ..write('level: $level, ')
          ..write('source: $source, ')
          ..write('message: $message, ')
          ..write('details: $details, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ImageIndexRecordsTable extends ImageIndexRecords
    with TableInfo<$ImageIndexRecordsTable, ImageIndexRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImageIndexRecordsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _datasetRootMeta = const VerificationMeta(
    'datasetRoot',
  );
  @override
  late final GeneratedColumn<String> datasetRoot = GeneratedColumn<String>(
    'dataset_root',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scanModeMeta = const VerificationMeta(
    'scanMode',
  );
  @override
  late final GeneratedColumn<String> scanMode = GeneratedColumn<String>(
    'scan_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelPathMeta = const VerificationMeta(
    'labelPath',
  );
  @override
  late final GeneratedColumn<String> labelPath = GeneratedColumn<String>(
    'label_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedAtMillisMeta = const VerificationMeta(
    'modifiedAtMillis',
  );
  @override
  late final GeneratedColumn<int> modifiedAtMillis = GeneratedColumn<int>(
    'modified_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _annotationStatusMeta = const VerificationMeta(
    'annotationStatus',
  );
  @override
  late final GeneratedColumn<String> annotationStatus = GeneratedColumn<String>(
    'annotation_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    datasetRoot,
    scanMode,
    imagePath,
    relativePath,
    labelPath,
    fileSize,
    modifiedAtMillis,
    width,
    height,
    annotationStatus,
    errorMessage,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'image_index_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImageIndexRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('dataset_root')) {
      context.handle(
        _datasetRootMeta,
        datasetRoot.isAcceptableOrUnknown(
          data['dataset_root']!,
          _datasetRootMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_datasetRootMeta);
    }
    if (data.containsKey('scan_mode')) {
      context.handle(
        _scanModeMeta,
        scanMode.isAcceptableOrUnknown(data['scan_mode']!, _scanModeMeta),
      );
    } else if (isInserting) {
      context.missing(_scanModeMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('label_path')) {
      context.handle(
        _labelPathMeta,
        labelPath.isAcceptableOrUnknown(data['label_path']!, _labelPathMeta),
      );
    } else if (isInserting) {
      context.missing(_labelPathMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('modified_at_millis')) {
      context.handle(
        _modifiedAtMillisMeta,
        modifiedAtMillis.isAcceptableOrUnknown(
          data['modified_at_millis']!,
          _modifiedAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modifiedAtMillisMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('annotation_status')) {
      context.handle(
        _annotationStatusMeta,
        annotationStatus.isAcceptableOrUnknown(
          data['annotation_status']!,
          _annotationStatusMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {datasetRoot, scanMode, relativePath},
  ];
  @override
  ImageIndexRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImageIndexRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      datasetRoot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dataset_root'],
      )!,
      scanMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_mode'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      labelPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label_path'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      modifiedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_at_millis'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      annotationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}annotation_status'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ImageIndexRecordsTable createAlias(String alias) {
    return $ImageIndexRecordsTable(attachedDatabase, alias);
  }
}

class ImageIndexRecord extends DataClass
    implements Insertable<ImageIndexRecord> {
  final int id;
  final String datasetRoot;
  final String scanMode;
  final String imagePath;
  final String relativePath;
  final String labelPath;
  final int fileSize;
  final int modifiedAtMillis;
  final int? width;
  final int? height;
  final String? annotationStatus;
  final String? errorMessage;
  final DateTime updatedAt;
  const ImageIndexRecord({
    required this.id,
    required this.datasetRoot,
    required this.scanMode,
    required this.imagePath,
    required this.relativePath,
    required this.labelPath,
    required this.fileSize,
    required this.modifiedAtMillis,
    this.width,
    this.height,
    this.annotationStatus,
    this.errorMessage,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['dataset_root'] = Variable<String>(datasetRoot);
    map['scan_mode'] = Variable<String>(scanMode);
    map['image_path'] = Variable<String>(imagePath);
    map['relative_path'] = Variable<String>(relativePath);
    map['label_path'] = Variable<String>(labelPath);
    map['file_size'] = Variable<int>(fileSize);
    map['modified_at_millis'] = Variable<int>(modifiedAtMillis);
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || annotationStatus != null) {
      map['annotation_status'] = Variable<String>(annotationStatus);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ImageIndexRecordsCompanion toCompanion(bool nullToAbsent) {
    return ImageIndexRecordsCompanion(
      id: Value(id),
      datasetRoot: Value(datasetRoot),
      scanMode: Value(scanMode),
      imagePath: Value(imagePath),
      relativePath: Value(relativePath),
      labelPath: Value(labelPath),
      fileSize: Value(fileSize),
      modifiedAtMillis: Value(modifiedAtMillis),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      annotationStatus: annotationStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(annotationStatus),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      updatedAt: Value(updatedAt),
    );
  }

  factory ImageIndexRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImageIndexRecord(
      id: serializer.fromJson<int>(json['id']),
      datasetRoot: serializer.fromJson<String>(json['datasetRoot']),
      scanMode: serializer.fromJson<String>(json['scanMode']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      labelPath: serializer.fromJson<String>(json['labelPath']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      modifiedAtMillis: serializer.fromJson<int>(json['modifiedAtMillis']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      annotationStatus: serializer.fromJson<String?>(json['annotationStatus']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'datasetRoot': serializer.toJson<String>(datasetRoot),
      'scanMode': serializer.toJson<String>(scanMode),
      'imagePath': serializer.toJson<String>(imagePath),
      'relativePath': serializer.toJson<String>(relativePath),
      'labelPath': serializer.toJson<String>(labelPath),
      'fileSize': serializer.toJson<int>(fileSize),
      'modifiedAtMillis': serializer.toJson<int>(modifiedAtMillis),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'annotationStatus': serializer.toJson<String?>(annotationStatus),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ImageIndexRecord copyWith({
    int? id,
    String? datasetRoot,
    String? scanMode,
    String? imagePath,
    String? relativePath,
    String? labelPath,
    int? fileSize,
    int? modifiedAtMillis,
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<String?> annotationStatus = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    DateTime? updatedAt,
  }) => ImageIndexRecord(
    id: id ?? this.id,
    datasetRoot: datasetRoot ?? this.datasetRoot,
    scanMode: scanMode ?? this.scanMode,
    imagePath: imagePath ?? this.imagePath,
    relativePath: relativePath ?? this.relativePath,
    labelPath: labelPath ?? this.labelPath,
    fileSize: fileSize ?? this.fileSize,
    modifiedAtMillis: modifiedAtMillis ?? this.modifiedAtMillis,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    annotationStatus: annotationStatus.present
        ? annotationStatus.value
        : this.annotationStatus,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ImageIndexRecord copyWithCompanion(ImageIndexRecordsCompanion data) {
    return ImageIndexRecord(
      id: data.id.present ? data.id.value : this.id,
      datasetRoot: data.datasetRoot.present
          ? data.datasetRoot.value
          : this.datasetRoot,
      scanMode: data.scanMode.present ? data.scanMode.value : this.scanMode,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      labelPath: data.labelPath.present ? data.labelPath.value : this.labelPath,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      modifiedAtMillis: data.modifiedAtMillis.present
          ? data.modifiedAtMillis.value
          : this.modifiedAtMillis,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      annotationStatus: data.annotationStatus.present
          ? data.annotationStatus.value
          : this.annotationStatus,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImageIndexRecord(')
          ..write('id: $id, ')
          ..write('datasetRoot: $datasetRoot, ')
          ..write('scanMode: $scanMode, ')
          ..write('imagePath: $imagePath, ')
          ..write('relativePath: $relativePath, ')
          ..write('labelPath: $labelPath, ')
          ..write('fileSize: $fileSize, ')
          ..write('modifiedAtMillis: $modifiedAtMillis, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('annotationStatus: $annotationStatus, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    datasetRoot,
    scanMode,
    imagePath,
    relativePath,
    labelPath,
    fileSize,
    modifiedAtMillis,
    width,
    height,
    annotationStatus,
    errorMessage,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageIndexRecord &&
          other.id == this.id &&
          other.datasetRoot == this.datasetRoot &&
          other.scanMode == this.scanMode &&
          other.imagePath == this.imagePath &&
          other.relativePath == this.relativePath &&
          other.labelPath == this.labelPath &&
          other.fileSize == this.fileSize &&
          other.modifiedAtMillis == this.modifiedAtMillis &&
          other.width == this.width &&
          other.height == this.height &&
          other.annotationStatus == this.annotationStatus &&
          other.errorMessage == this.errorMessage &&
          other.updatedAt == this.updatedAt);
}

class ImageIndexRecordsCompanion extends UpdateCompanion<ImageIndexRecord> {
  final Value<int> id;
  final Value<String> datasetRoot;
  final Value<String> scanMode;
  final Value<String> imagePath;
  final Value<String> relativePath;
  final Value<String> labelPath;
  final Value<int> fileSize;
  final Value<int> modifiedAtMillis;
  final Value<int?> width;
  final Value<int?> height;
  final Value<String?> annotationStatus;
  final Value<String?> errorMessage;
  final Value<DateTime> updatedAt;
  const ImageIndexRecordsCompanion({
    this.id = const Value.absent(),
    this.datasetRoot = const Value.absent(),
    this.scanMode = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.labelPath = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.modifiedAtMillis = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.annotationStatus = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ImageIndexRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String datasetRoot,
    required String scanMode,
    required String imagePath,
    required String relativePath,
    required String labelPath,
    required int fileSize,
    required int modifiedAtMillis,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.annotationStatus = const Value.absent(),
    this.errorMessage = const Value.absent(),
    required DateTime updatedAt,
  }) : datasetRoot = Value(datasetRoot),
       scanMode = Value(scanMode),
       imagePath = Value(imagePath),
       relativePath = Value(relativePath),
       labelPath = Value(labelPath),
       fileSize = Value(fileSize),
       modifiedAtMillis = Value(modifiedAtMillis),
       updatedAt = Value(updatedAt);
  static Insertable<ImageIndexRecord> custom({
    Expression<int>? id,
    Expression<String>? datasetRoot,
    Expression<String>? scanMode,
    Expression<String>? imagePath,
    Expression<String>? relativePath,
    Expression<String>? labelPath,
    Expression<int>? fileSize,
    Expression<int>? modifiedAtMillis,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? annotationStatus,
    Expression<String>? errorMessage,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (datasetRoot != null) 'dataset_root': datasetRoot,
      if (scanMode != null) 'scan_mode': scanMode,
      if (imagePath != null) 'image_path': imagePath,
      if (relativePath != null) 'relative_path': relativePath,
      if (labelPath != null) 'label_path': labelPath,
      if (fileSize != null) 'file_size': fileSize,
      if (modifiedAtMillis != null) 'modified_at_millis': modifiedAtMillis,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (annotationStatus != null) 'annotation_status': annotationStatus,
      if (errorMessage != null) 'error_message': errorMessage,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ImageIndexRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? datasetRoot,
    Value<String>? scanMode,
    Value<String>? imagePath,
    Value<String>? relativePath,
    Value<String>? labelPath,
    Value<int>? fileSize,
    Value<int>? modifiedAtMillis,
    Value<int?>? width,
    Value<int?>? height,
    Value<String?>? annotationStatus,
    Value<String?>? errorMessage,
    Value<DateTime>? updatedAt,
  }) {
    return ImageIndexRecordsCompanion(
      id: id ?? this.id,
      datasetRoot: datasetRoot ?? this.datasetRoot,
      scanMode: scanMode ?? this.scanMode,
      imagePath: imagePath ?? this.imagePath,
      relativePath: relativePath ?? this.relativePath,
      labelPath: labelPath ?? this.labelPath,
      fileSize: fileSize ?? this.fileSize,
      modifiedAtMillis: modifiedAtMillis ?? this.modifiedAtMillis,
      width: width ?? this.width,
      height: height ?? this.height,
      annotationStatus: annotationStatus ?? this.annotationStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (datasetRoot.present) {
      map['dataset_root'] = Variable<String>(datasetRoot.value);
    }
    if (scanMode.present) {
      map['scan_mode'] = Variable<String>(scanMode.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (labelPath.present) {
      map['label_path'] = Variable<String>(labelPath.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (modifiedAtMillis.present) {
      map['modified_at_millis'] = Variable<int>(modifiedAtMillis.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (annotationStatus.present) {
      map['annotation_status'] = Variable<String>(annotationStatus.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImageIndexRecordsCompanion(')
          ..write('id: $id, ')
          ..write('datasetRoot: $datasetRoot, ')
          ..write('scanMode: $scanMode, ')
          ..write('imagePath: $imagePath, ')
          ..write('relativePath: $relativePath, ')
          ..write('labelPath: $labelPath, ')
          ..write('fileSize: $fileSize, ')
          ..write('modifiedAtMillis: $modifiedAtMillis, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('annotationStatus: $annotationStatus, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $HistoryRecordsTable historyRecords = $HistoryRecordsTable(this);
  late final $RunLogRecordsTable runLogRecords = $RunLogRecordsTable(this);
  late final $ImageIndexRecordsTable imageIndexRecords =
      $ImageIndexRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    historyRecords,
    runLogRecords,
    imageIndexRecords,
  ];
}

typedef $$HistoryRecordsTableCreateCompanionBuilder =
    HistoryRecordsCompanion Function({
      Value<int> id,
      required HistoryActionType actionType,
      required String title,
      Value<String?> description,
      Value<String?> targetRoute,
      Value<String?> payload,
      required DateTime createdAt,
    });
typedef $$HistoryRecordsTableUpdateCompanionBuilder =
    HistoryRecordsCompanion Function({
      Value<int> id,
      Value<HistoryActionType> actionType,
      Value<String> title,
      Value<String?> description,
      Value<String?> targetRoute,
      Value<String?> payload,
      Value<DateTime> createdAt,
    });

class $$HistoryRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $HistoryRecordsTable> {
  $$HistoryRecordsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<HistoryActionType, HistoryActionType, String>
  get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetRoute => $composableBuilder(
    column: $table.targetRoute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoryRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $HistoryRecordsTable> {
  $$HistoryRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetRoute => $composableBuilder(
    column: $table.targetRoute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoryRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistoryRecordsTable> {
  $$HistoryRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<HistoryActionType, String> get actionType =>
      $composableBuilder(
        column: $table.actionType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetRoute => $composableBuilder(
    column: $table.targetRoute,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$HistoryRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HistoryRecordsTable,
          HistoryRecord,
          $$HistoryRecordsTableFilterComposer,
          $$HistoryRecordsTableOrderingComposer,
          $$HistoryRecordsTableAnnotationComposer,
          $$HistoryRecordsTableCreateCompanionBuilder,
          $$HistoryRecordsTableUpdateCompanionBuilder,
          (
            HistoryRecord,
            BaseReferences<_$AppDatabase, $HistoryRecordsTable, HistoryRecord>,
          ),
          HistoryRecord,
          PrefetchHooks Function()
        > {
  $$HistoryRecordsTableTableManager(
    _$AppDatabase db,
    $HistoryRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<HistoryActionType> actionType = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> targetRoute = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => HistoryRecordsCompanion(
                id: id,
                actionType: actionType,
                title: title,
                description: description,
                targetRoute: targetRoute,
                payload: payload,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required HistoryActionType actionType,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> targetRoute = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                required DateTime createdAt,
              }) => HistoryRecordsCompanion.insert(
                id: id,
                actionType: actionType,
                title: title,
                description: description,
                targetRoute: targetRoute,
                payload: payload,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoryRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HistoryRecordsTable,
      HistoryRecord,
      $$HistoryRecordsTableFilterComposer,
      $$HistoryRecordsTableOrderingComposer,
      $$HistoryRecordsTableAnnotationComposer,
      $$HistoryRecordsTableCreateCompanionBuilder,
      $$HistoryRecordsTableUpdateCompanionBuilder,
      (
        HistoryRecord,
        BaseReferences<_$AppDatabase, $HistoryRecordsTable, HistoryRecord>,
      ),
      HistoryRecord,
      PrefetchHooks Function()
    >;
typedef $$RunLogRecordsTableCreateCompanionBuilder =
    RunLogRecordsCompanion Function({
      Value<int> id,
      required RunLogLevel level,
      required String source,
      required String message,
      Value<String?> details,
      required DateTime createdAt,
    });
typedef $$RunLogRecordsTableUpdateCompanionBuilder =
    RunLogRecordsCompanion Function({
      Value<int> id,
      Value<RunLogLevel> level,
      Value<String> source,
      Value<String> message,
      Value<String?> details,
      Value<DateTime> createdAt,
    });

class $$RunLogRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $RunLogRecordsTable> {
  $$RunLogRecordsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<RunLogLevel, RunLogLevel, String> get level =>
      $composableBuilder(
        column: $table.level,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RunLogRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $RunLogRecordsTable> {
  $$RunLogRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RunLogRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RunLogRecordsTable> {
  $$RunLogRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RunLogLevel, String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RunLogRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RunLogRecordsTable,
          RunLogRecord,
          $$RunLogRecordsTableFilterComposer,
          $$RunLogRecordsTableOrderingComposer,
          $$RunLogRecordsTableAnnotationComposer,
          $$RunLogRecordsTableCreateCompanionBuilder,
          $$RunLogRecordsTableUpdateCompanionBuilder,
          (
            RunLogRecord,
            BaseReferences<_$AppDatabase, $RunLogRecordsTable, RunLogRecord>,
          ),
          RunLogRecord,
          PrefetchHooks Function()
        > {
  $$RunLogRecordsTableTableManager(_$AppDatabase db, $RunLogRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunLogRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunLogRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunLogRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<RunLogLevel> level = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RunLogRecordsCompanion(
                id: id,
                level: level,
                source: source,
                message: message,
                details: details,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required RunLogLevel level,
                required String source,
                required String message,
                Value<String?> details = const Value.absent(),
                required DateTime createdAt,
              }) => RunLogRecordsCompanion.insert(
                id: id,
                level: level,
                source: source,
                message: message,
                details: details,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RunLogRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RunLogRecordsTable,
      RunLogRecord,
      $$RunLogRecordsTableFilterComposer,
      $$RunLogRecordsTableOrderingComposer,
      $$RunLogRecordsTableAnnotationComposer,
      $$RunLogRecordsTableCreateCompanionBuilder,
      $$RunLogRecordsTableUpdateCompanionBuilder,
      (
        RunLogRecord,
        BaseReferences<_$AppDatabase, $RunLogRecordsTable, RunLogRecord>,
      ),
      RunLogRecord,
      PrefetchHooks Function()
    >;
typedef $$ImageIndexRecordsTableCreateCompanionBuilder =
    ImageIndexRecordsCompanion Function({
      Value<int> id,
      required String datasetRoot,
      required String scanMode,
      required String imagePath,
      required String relativePath,
      required String labelPath,
      required int fileSize,
      required int modifiedAtMillis,
      Value<int?> width,
      Value<int?> height,
      Value<String?> annotationStatus,
      Value<String?> errorMessage,
      required DateTime updatedAt,
    });
typedef $$ImageIndexRecordsTableUpdateCompanionBuilder =
    ImageIndexRecordsCompanion Function({
      Value<int> id,
      Value<String> datasetRoot,
      Value<String> scanMode,
      Value<String> imagePath,
      Value<String> relativePath,
      Value<String> labelPath,
      Value<int> fileSize,
      Value<int> modifiedAtMillis,
      Value<int?> width,
      Value<int?> height,
      Value<String?> annotationStatus,
      Value<String?> errorMessage,
      Value<DateTime> updatedAt,
    });

class $$ImageIndexRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ImageIndexRecordsTable> {
  $$ImageIndexRecordsTableFilterComposer({
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

  ColumnFilters<String> get datasetRoot => $composableBuilder(
    column: $table.datasetRoot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanMode => $composableBuilder(
    column: $table.scanMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labelPath => $composableBuilder(
    column: $table.labelPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifiedAtMillis => $composableBuilder(
    column: $table.modifiedAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get annotationStatus => $composableBuilder(
    column: $table.annotationStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImageIndexRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImageIndexRecordsTable> {
  $$ImageIndexRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get datasetRoot => $composableBuilder(
    column: $table.datasetRoot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanMode => $composableBuilder(
    column: $table.scanMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labelPath => $composableBuilder(
    column: $table.labelPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifiedAtMillis => $composableBuilder(
    column: $table.modifiedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get annotationStatus => $composableBuilder(
    column: $table.annotationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImageIndexRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImageIndexRecordsTable> {
  $$ImageIndexRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get datasetRoot => $composableBuilder(
    column: $table.datasetRoot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scanMode =>
      $composableBuilder(column: $table.scanMode, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get labelPath =>
      $composableBuilder(column: $table.labelPath, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<int> get modifiedAtMillis => $composableBuilder(
    column: $table.modifiedAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get annotationStatus => $composableBuilder(
    column: $table.annotationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ImageIndexRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImageIndexRecordsTable,
          ImageIndexRecord,
          $$ImageIndexRecordsTableFilterComposer,
          $$ImageIndexRecordsTableOrderingComposer,
          $$ImageIndexRecordsTableAnnotationComposer,
          $$ImageIndexRecordsTableCreateCompanionBuilder,
          $$ImageIndexRecordsTableUpdateCompanionBuilder,
          (
            ImageIndexRecord,
            BaseReferences<
              _$AppDatabase,
              $ImageIndexRecordsTable,
              ImageIndexRecord
            >,
          ),
          ImageIndexRecord,
          PrefetchHooks Function()
        > {
  $$ImageIndexRecordsTableTableManager(
    _$AppDatabase db,
    $ImageIndexRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImageIndexRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImageIndexRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImageIndexRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> datasetRoot = const Value.absent(),
                Value<String> scanMode = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> labelPath = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<int> modifiedAtMillis = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> annotationStatus = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ImageIndexRecordsCompanion(
                id: id,
                datasetRoot: datasetRoot,
                scanMode: scanMode,
                imagePath: imagePath,
                relativePath: relativePath,
                labelPath: labelPath,
                fileSize: fileSize,
                modifiedAtMillis: modifiedAtMillis,
                width: width,
                height: height,
                annotationStatus: annotationStatus,
                errorMessage: errorMessage,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String datasetRoot,
                required String scanMode,
                required String imagePath,
                required String relativePath,
                required String labelPath,
                required int fileSize,
                required int modifiedAtMillis,
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> annotationStatus = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                required DateTime updatedAt,
              }) => ImageIndexRecordsCompanion.insert(
                id: id,
                datasetRoot: datasetRoot,
                scanMode: scanMode,
                imagePath: imagePath,
                relativePath: relativePath,
                labelPath: labelPath,
                fileSize: fileSize,
                modifiedAtMillis: modifiedAtMillis,
                width: width,
                height: height,
                annotationStatus: annotationStatus,
                errorMessage: errorMessage,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImageIndexRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImageIndexRecordsTable,
      ImageIndexRecord,
      $$ImageIndexRecordsTableFilterComposer,
      $$ImageIndexRecordsTableOrderingComposer,
      $$ImageIndexRecordsTableAnnotationComposer,
      $$ImageIndexRecordsTableCreateCompanionBuilder,
      $$ImageIndexRecordsTableUpdateCompanionBuilder,
      (
        ImageIndexRecord,
        BaseReferences<
          _$AppDatabase,
          $ImageIndexRecordsTable,
          ImageIndexRecord
        >,
      ),
      ImageIndexRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HistoryRecordsTableTableManager get historyRecords =>
      $$HistoryRecordsTableTableManager(_db, _db.historyRecords);
  $$RunLogRecordsTableTableManager get runLogRecords =>
      $$RunLogRecordsTableTableManager(_db, _db.runLogRecords);
  $$ImageIndexRecordsTableTableManager get imageIndexRecords =>
      $$ImageIndexRecordsTableTableManager(_db, _db.imageIndexRecords);
}
