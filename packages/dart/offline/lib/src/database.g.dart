// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LocalUserBooksTable extends LocalUserBooks
    with TableInfo<$LocalUserBooksTable, LocalUserBook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalUserBooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currentPageMeta =
      const VerificationMeta('currentPage');
  @override
  late final GeneratedColumn<int> currentPage = GeneratedColumn<int>(
      'current_page', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _targetNightlyPagesMeta =
      const VerificationMeta('targetNightlyPages');
  @override
  late final GeneratedColumn<int> targetNightlyPages = GeneratedColumn<int>(
      'target_nightly_pages', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _bookJsonMeta =
      const VerificationMeta('bookJson');
  @override
  late final GeneratedColumn<String> bookJson = GeneratedColumn<String>(
      'book_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        bookId,
        status,
        currentPage,
        targetNightlyPages,
        bookJson,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_user_books';
  @override
  VerificationContext validateIntegrity(Insertable<LocalUserBook> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('current_page')) {
      context.handle(
          _currentPageMeta,
          currentPage.isAcceptableOrUnknown(
              data['current_page']!, _currentPageMeta));
    }
    if (data.containsKey('target_nightly_pages')) {
      context.handle(
          _targetNightlyPagesMeta,
          targetNightlyPages.isAcceptableOrUnknown(
              data['target_nightly_pages']!, _targetNightlyPagesMeta));
    }
    if (data.containsKey('book_json')) {
      context.handle(_bookJsonMeta,
          bookJson.isAcceptableOrUnknown(data['book_json']!, _bookJsonMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalUserBook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalUserBook(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      currentPage: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_page']),
      targetNightlyPages: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}target_nightly_pages']),
      bookJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_json']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalUserBooksTable createAlias(String alias) {
    return $LocalUserBooksTable(attachedDatabase, alias);
  }
}

class LocalUserBook extends DataClass implements Insertable<LocalUserBook> {
  final String id;
  final String bookId;
  final String status;
  final int? currentPage;
  final int? targetNightlyPages;
  final String? bookJson;
  final DateTime updatedAt;
  const LocalUserBook(
      {required this.id,
      required this.bookId,
      required this.status,
      this.currentPage,
      this.targetNightlyPages,
      this.bookJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || currentPage != null) {
      map['current_page'] = Variable<int>(currentPage);
    }
    if (!nullToAbsent || targetNightlyPages != null) {
      map['target_nightly_pages'] = Variable<int>(targetNightlyPages);
    }
    if (!nullToAbsent || bookJson != null) {
      map['book_json'] = Variable<String>(bookJson);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalUserBooksCompanion toCompanion(bool nullToAbsent) {
    return LocalUserBooksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      status: Value(status),
      currentPage: currentPage == null && nullToAbsent
          ? const Value.absent()
          : Value(currentPage),
      targetNightlyPages: targetNightlyPages == null && nullToAbsent
          ? const Value.absent()
          : Value(targetNightlyPages),
      bookJson: bookJson == null && nullToAbsent
          ? const Value.absent()
          : Value(bookJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalUserBook.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalUserBook(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      status: serializer.fromJson<String>(json['status']),
      currentPage: serializer.fromJson<int?>(json['currentPage']),
      targetNightlyPages: serializer.fromJson<int?>(json['targetNightlyPages']),
      bookJson: serializer.fromJson<String?>(json['bookJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'status': serializer.toJson<String>(status),
      'currentPage': serializer.toJson<int?>(currentPage),
      'targetNightlyPages': serializer.toJson<int?>(targetNightlyPages),
      'bookJson': serializer.toJson<String?>(bookJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalUserBook copyWith(
          {String? id,
          String? bookId,
          String? status,
          Value<int?> currentPage = const Value.absent(),
          Value<int?> targetNightlyPages = const Value.absent(),
          Value<String?> bookJson = const Value.absent(),
          DateTime? updatedAt}) =>
      LocalUserBook(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        status: status ?? this.status,
        currentPage: currentPage.present ? currentPage.value : this.currentPage,
        targetNightlyPages: targetNightlyPages.present
            ? targetNightlyPages.value
            : this.targetNightlyPages,
        bookJson: bookJson.present ? bookJson.value : this.bookJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalUserBook copyWithCompanion(LocalUserBooksCompanion data) {
    return LocalUserBook(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      status: data.status.present ? data.status.value : this.status,
      currentPage:
          data.currentPage.present ? data.currentPage.value : this.currentPage,
      targetNightlyPages: data.targetNightlyPages.present
          ? data.targetNightlyPages.value
          : this.targetNightlyPages,
      bookJson: data.bookJson.present ? data.bookJson.value : this.bookJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalUserBook(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('status: $status, ')
          ..write('currentPage: $currentPage, ')
          ..write('targetNightlyPages: $targetNightlyPages, ')
          ..write('bookJson: $bookJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, bookId, status, currentPage, targetNightlyPages, bookJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalUserBook &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.status == this.status &&
          other.currentPage == this.currentPage &&
          other.targetNightlyPages == this.targetNightlyPages &&
          other.bookJson == this.bookJson &&
          other.updatedAt == this.updatedAt);
}

class LocalUserBooksCompanion extends UpdateCompanion<LocalUserBook> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> status;
  final Value<int?> currentPage;
  final Value<int?> targetNightlyPages;
  final Value<String?> bookJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalUserBooksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.status = const Value.absent(),
    this.currentPage = const Value.absent(),
    this.targetNightlyPages = const Value.absent(),
    this.bookJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalUserBooksCompanion.insert({
    required String id,
    required String bookId,
    required String status,
    this.currentPage = const Value.absent(),
    this.targetNightlyPages = const Value.absent(),
    this.bookJson = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        bookId = Value(bookId),
        status = Value(status),
        updatedAt = Value(updatedAt);
  static Insertable<LocalUserBook> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? status,
    Expression<int>? currentPage,
    Expression<int>? targetNightlyPages,
    Expression<String>? bookJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (status != null) 'status': status,
      if (currentPage != null) 'current_page': currentPage,
      if (targetNightlyPages != null)
        'target_nightly_pages': targetNightlyPages,
      if (bookJson != null) 'book_json': bookJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalUserBooksCompanion copyWith(
      {Value<String>? id,
      Value<String>? bookId,
      Value<String>? status,
      Value<int?>? currentPage,
      Value<int?>? targetNightlyPages,
      Value<String?>? bookJson,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return LocalUserBooksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      status: status ?? this.status,
      currentPage: currentPage ?? this.currentPage,
      targetNightlyPages: targetNightlyPages ?? this.targetNightlyPages,
      bookJson: bookJson ?? this.bookJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (currentPage.present) {
      map['current_page'] = Variable<int>(currentPage.value);
    }
    if (targetNightlyPages.present) {
      map['target_nightly_pages'] = Variable<int>(targetNightlyPages.value);
    }
    if (bookJson.present) {
      map['book_json'] = Variable<String>(bookJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalUserBooksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('status: $status, ')
          ..write('currentPage: $currentPage, ')
          ..write('targetNightlyPages: $targetNightlyPages, ')
          ..write('bookJson: $bookJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPlanStepsTable extends LocalPlanSteps
    with TableInfo<$LocalPlanStepsTable, LocalPlanStep> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPlanStepsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _stepIdMeta = const VerificationMeta('stepId');
  @override
  late final GeneratedColumn<String> stepId = GeneratedColumn<String>(
      'step_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
      'plan_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stepIndexMeta =
      const VerificationMeta('stepIndex');
  @override
  late final GeneratedColumn<int> stepIndex = GeneratedColumn<int>(
      'step_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stepJsonMeta =
      const VerificationMeta('stepJson');
  @override
  late final GeneratedColumn<String> stepJson = GeneratedColumn<String>(
      'step_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unlocksAtMeta =
      const VerificationMeta('unlocksAt');
  @override
  late final GeneratedColumn<DateTime> unlocksAt = GeneratedColumn<DateTime>(
      'unlocks_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _ttsAssetIdMeta =
      const VerificationMeta('ttsAssetId');
  @override
  late final GeneratedColumn<String> ttsAssetId = GeneratedColumn<String>(
      'tts_asset_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        stepId,
        planId,
        stepIndex,
        status,
        stepJson,
        unlocksAt,
        ttsAssetId,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_plan_steps';
  @override
  VerificationContext validateIntegrity(Insertable<LocalPlanStep> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('step_id')) {
      context.handle(_stepIdMeta,
          stepId.isAcceptableOrUnknown(data['step_id']!, _stepIdMeta));
    } else if (isInserting) {
      context.missing(_stepIdMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('step_index')) {
      context.handle(_stepIndexMeta,
          stepIndex.isAcceptableOrUnknown(data['step_index']!, _stepIndexMeta));
    } else if (isInserting) {
      context.missing(_stepIndexMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('step_json')) {
      context.handle(_stepJsonMeta,
          stepJson.isAcceptableOrUnknown(data['step_json']!, _stepJsonMeta));
    } else if (isInserting) {
      context.missing(_stepJsonMeta);
    }
    if (data.containsKey('unlocks_at')) {
      context.handle(_unlocksAtMeta,
          unlocksAt.isAcceptableOrUnknown(data['unlocks_at']!, _unlocksAtMeta));
    }
    if (data.containsKey('tts_asset_id')) {
      context.handle(
          _ttsAssetIdMeta,
          ttsAssetId.isAcceptableOrUnknown(
              data['tts_asset_id']!, _ttsAssetIdMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {stepId};
  @override
  LocalPlanStep map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPlanStep(
      stepId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}step_id'])!,
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_id'])!,
      stepIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}step_index'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      stepJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}step_json'])!,
      unlocksAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}unlocks_at']),
      ttsAssetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tts_asset_id']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalPlanStepsTable createAlias(String alias) {
    return $LocalPlanStepsTable(attachedDatabase, alias);
  }
}

class LocalPlanStep extends DataClass implements Insertable<LocalPlanStep> {
  final String stepId;
  final String planId;
  final int stepIndex;
  final String status;
  final String stepJson;
  final DateTime? unlocksAt;
  final String? ttsAssetId;
  final DateTime updatedAt;
  const LocalPlanStep(
      {required this.stepId,
      required this.planId,
      required this.stepIndex,
      required this.status,
      required this.stepJson,
      this.unlocksAt,
      this.ttsAssetId,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['step_id'] = Variable<String>(stepId);
    map['plan_id'] = Variable<String>(planId);
    map['step_index'] = Variable<int>(stepIndex);
    map['status'] = Variable<String>(status);
    map['step_json'] = Variable<String>(stepJson);
    if (!nullToAbsent || unlocksAt != null) {
      map['unlocks_at'] = Variable<DateTime>(unlocksAt);
    }
    if (!nullToAbsent || ttsAssetId != null) {
      map['tts_asset_id'] = Variable<String>(ttsAssetId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalPlanStepsCompanion toCompanion(bool nullToAbsent) {
    return LocalPlanStepsCompanion(
      stepId: Value(stepId),
      planId: Value(planId),
      stepIndex: Value(stepIndex),
      status: Value(status),
      stepJson: Value(stepJson),
      unlocksAt: unlocksAt == null && nullToAbsent
          ? const Value.absent()
          : Value(unlocksAt),
      ttsAssetId: ttsAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(ttsAssetId),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalPlanStep.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPlanStep(
      stepId: serializer.fromJson<String>(json['stepId']),
      planId: serializer.fromJson<String>(json['planId']),
      stepIndex: serializer.fromJson<int>(json['stepIndex']),
      status: serializer.fromJson<String>(json['status']),
      stepJson: serializer.fromJson<String>(json['stepJson']),
      unlocksAt: serializer.fromJson<DateTime?>(json['unlocksAt']),
      ttsAssetId: serializer.fromJson<String?>(json['ttsAssetId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'stepId': serializer.toJson<String>(stepId),
      'planId': serializer.toJson<String>(planId),
      'stepIndex': serializer.toJson<int>(stepIndex),
      'status': serializer.toJson<String>(status),
      'stepJson': serializer.toJson<String>(stepJson),
      'unlocksAt': serializer.toJson<DateTime?>(unlocksAt),
      'ttsAssetId': serializer.toJson<String?>(ttsAssetId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalPlanStep copyWith(
          {String? stepId,
          String? planId,
          int? stepIndex,
          String? status,
          String? stepJson,
          Value<DateTime?> unlocksAt = const Value.absent(),
          Value<String?> ttsAssetId = const Value.absent(),
          DateTime? updatedAt}) =>
      LocalPlanStep(
        stepId: stepId ?? this.stepId,
        planId: planId ?? this.planId,
        stepIndex: stepIndex ?? this.stepIndex,
        status: status ?? this.status,
        stepJson: stepJson ?? this.stepJson,
        unlocksAt: unlocksAt.present ? unlocksAt.value : this.unlocksAt,
        ttsAssetId: ttsAssetId.present ? ttsAssetId.value : this.ttsAssetId,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalPlanStep copyWithCompanion(LocalPlanStepsCompanion data) {
    return LocalPlanStep(
      stepId: data.stepId.present ? data.stepId.value : this.stepId,
      planId: data.planId.present ? data.planId.value : this.planId,
      stepIndex: data.stepIndex.present ? data.stepIndex.value : this.stepIndex,
      status: data.status.present ? data.status.value : this.status,
      stepJson: data.stepJson.present ? data.stepJson.value : this.stepJson,
      unlocksAt: data.unlocksAt.present ? data.unlocksAt.value : this.unlocksAt,
      ttsAssetId:
          data.ttsAssetId.present ? data.ttsAssetId.value : this.ttsAssetId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlanStep(')
          ..write('stepId: $stepId, ')
          ..write('planId: $planId, ')
          ..write('stepIndex: $stepIndex, ')
          ..write('status: $status, ')
          ..write('stepJson: $stepJson, ')
          ..write('unlocksAt: $unlocksAt, ')
          ..write('ttsAssetId: $ttsAssetId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(stepId, planId, stepIndex, status, stepJson,
      unlocksAt, ttsAssetId, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPlanStep &&
          other.stepId == this.stepId &&
          other.planId == this.planId &&
          other.stepIndex == this.stepIndex &&
          other.status == this.status &&
          other.stepJson == this.stepJson &&
          other.unlocksAt == this.unlocksAt &&
          other.ttsAssetId == this.ttsAssetId &&
          other.updatedAt == this.updatedAt);
}

class LocalPlanStepsCompanion extends UpdateCompanion<LocalPlanStep> {
  final Value<String> stepId;
  final Value<String> planId;
  final Value<int> stepIndex;
  final Value<String> status;
  final Value<String> stepJson;
  final Value<DateTime?> unlocksAt;
  final Value<String?> ttsAssetId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalPlanStepsCompanion({
    this.stepId = const Value.absent(),
    this.planId = const Value.absent(),
    this.stepIndex = const Value.absent(),
    this.status = const Value.absent(),
    this.stepJson = const Value.absent(),
    this.unlocksAt = const Value.absent(),
    this.ttsAssetId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPlanStepsCompanion.insert({
    required String stepId,
    required String planId,
    required int stepIndex,
    required String status,
    required String stepJson,
    this.unlocksAt = const Value.absent(),
    this.ttsAssetId = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : stepId = Value(stepId),
        planId = Value(planId),
        stepIndex = Value(stepIndex),
        status = Value(status),
        stepJson = Value(stepJson),
        updatedAt = Value(updatedAt);
  static Insertable<LocalPlanStep> custom({
    Expression<String>? stepId,
    Expression<String>? planId,
    Expression<int>? stepIndex,
    Expression<String>? status,
    Expression<String>? stepJson,
    Expression<DateTime>? unlocksAt,
    Expression<String>? ttsAssetId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (stepId != null) 'step_id': stepId,
      if (planId != null) 'plan_id': planId,
      if (stepIndex != null) 'step_index': stepIndex,
      if (status != null) 'status': status,
      if (stepJson != null) 'step_json': stepJson,
      if (unlocksAt != null) 'unlocks_at': unlocksAt,
      if (ttsAssetId != null) 'tts_asset_id': ttsAssetId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPlanStepsCompanion copyWith(
      {Value<String>? stepId,
      Value<String>? planId,
      Value<int>? stepIndex,
      Value<String>? status,
      Value<String>? stepJson,
      Value<DateTime?>? unlocksAt,
      Value<String?>? ttsAssetId,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return LocalPlanStepsCompanion(
      stepId: stepId ?? this.stepId,
      planId: planId ?? this.planId,
      stepIndex: stepIndex ?? this.stepIndex,
      status: status ?? this.status,
      stepJson: stepJson ?? this.stepJson,
      unlocksAt: unlocksAt ?? this.unlocksAt,
      ttsAssetId: ttsAssetId ?? this.ttsAssetId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (stepId.present) {
      map['step_id'] = Variable<String>(stepId.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (stepIndex.present) {
      map['step_index'] = Variable<int>(stepIndex.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (stepJson.present) {
      map['step_json'] = Variable<String>(stepJson.value);
    }
    if (unlocksAt.present) {
      map['unlocks_at'] = Variable<DateTime>(unlocksAt.value);
    }
    if (ttsAssetId.present) {
      map['tts_asset_id'] = Variable<String>(ttsAssetId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlanStepsCompanion(')
          ..write('stepId: $stepId, ')
          ..write('planId: $planId, ')
          ..write('stepIndex: $stepIndex, ')
          ..write('status: $status, ')
          ..write('stepJson: $stepJson, ')
          ..write('unlocksAt: $unlocksAt, ')
          ..write('ttsAssetId: $ttsAssetId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalQuizInstancesTable extends LocalQuizInstances
    with TableInfo<$LocalQuizInstancesTable, LocalQuizInstance> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalQuizInstancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _quizIdMeta = const VerificationMeta('quizId');
  @override
  late final GeneratedColumn<String> quizId = GeneratedColumn<String>(
      'quiz_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stepIdMeta = const VerificationMeta('stepId');
  @override
  late final GeneratedColumn<String> stepId = GeneratedColumn<String>(
      'step_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quizModeMeta =
      const VerificationMeta('quizMode');
  @override
  late final GeneratedColumn<String> quizMode = GeneratedColumn<String>(
      'quiz_mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quizJsonMeta =
      const VerificationMeta('quizJson');
  @override
  late final GeneratedColumn<String> quizJson = GeneratedColumn<String>(
      'quiz_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [quizId, stepId, quizMode, quizJson, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_quiz_instances';
  @override
  VerificationContext validateIntegrity(Insertable<LocalQuizInstance> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('quiz_id')) {
      context.handle(_quizIdMeta,
          quizId.isAcceptableOrUnknown(data['quiz_id']!, _quizIdMeta));
    } else if (isInserting) {
      context.missing(_quizIdMeta);
    }
    if (data.containsKey('step_id')) {
      context.handle(_stepIdMeta,
          stepId.isAcceptableOrUnknown(data['step_id']!, _stepIdMeta));
    } else if (isInserting) {
      context.missing(_stepIdMeta);
    }
    if (data.containsKey('quiz_mode')) {
      context.handle(_quizModeMeta,
          quizMode.isAcceptableOrUnknown(data['quiz_mode']!, _quizModeMeta));
    } else if (isInserting) {
      context.missing(_quizModeMeta);
    }
    if (data.containsKey('quiz_json')) {
      context.handle(_quizJsonMeta,
          quizJson.isAcceptableOrUnknown(data['quiz_json']!, _quizJsonMeta));
    } else if (isInserting) {
      context.missing(_quizJsonMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {quizId};
  @override
  LocalQuizInstance map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalQuizInstance(
      quizId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}quiz_id'])!,
      stepId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}step_id'])!,
      quizMode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}quiz_mode'])!,
      quizJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}quiz_json'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $LocalQuizInstancesTable createAlias(String alias) {
    return $LocalQuizInstancesTable(attachedDatabase, alias);
  }
}

class LocalQuizInstance extends DataClass
    implements Insertable<LocalQuizInstance> {
  final String quizId;
  final String stepId;
  final String quizMode;
  final String quizJson;
  final DateTime fetchedAt;
  const LocalQuizInstance(
      {required this.quizId,
      required this.stepId,
      required this.quizMode,
      required this.quizJson,
      required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['quiz_id'] = Variable<String>(quizId);
    map['step_id'] = Variable<String>(stepId);
    map['quiz_mode'] = Variable<String>(quizMode);
    map['quiz_json'] = Variable<String>(quizJson);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  LocalQuizInstancesCompanion toCompanion(bool nullToAbsent) {
    return LocalQuizInstancesCompanion(
      quizId: Value(quizId),
      stepId: Value(stepId),
      quizMode: Value(quizMode),
      quizJson: Value(quizJson),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory LocalQuizInstance.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalQuizInstance(
      quizId: serializer.fromJson<String>(json['quizId']),
      stepId: serializer.fromJson<String>(json['stepId']),
      quizMode: serializer.fromJson<String>(json['quizMode']),
      quizJson: serializer.fromJson<String>(json['quizJson']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'quizId': serializer.toJson<String>(quizId),
      'stepId': serializer.toJson<String>(stepId),
      'quizMode': serializer.toJson<String>(quizMode),
      'quizJson': serializer.toJson<String>(quizJson),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  LocalQuizInstance copyWith(
          {String? quizId,
          String? stepId,
          String? quizMode,
          String? quizJson,
          DateTime? fetchedAt}) =>
      LocalQuizInstance(
        quizId: quizId ?? this.quizId,
        stepId: stepId ?? this.stepId,
        quizMode: quizMode ?? this.quizMode,
        quizJson: quizJson ?? this.quizJson,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  LocalQuizInstance copyWithCompanion(LocalQuizInstancesCompanion data) {
    return LocalQuizInstance(
      quizId: data.quizId.present ? data.quizId.value : this.quizId,
      stepId: data.stepId.present ? data.stepId.value : this.stepId,
      quizMode: data.quizMode.present ? data.quizMode.value : this.quizMode,
      quizJson: data.quizJson.present ? data.quizJson.value : this.quizJson,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalQuizInstance(')
          ..write('quizId: $quizId, ')
          ..write('stepId: $stepId, ')
          ..write('quizMode: $quizMode, ')
          ..write('quizJson: $quizJson, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(quizId, stepId, quizMode, quizJson, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalQuizInstance &&
          other.quizId == this.quizId &&
          other.stepId == this.stepId &&
          other.quizMode == this.quizMode &&
          other.quizJson == this.quizJson &&
          other.fetchedAt == this.fetchedAt);
}

class LocalQuizInstancesCompanion extends UpdateCompanion<LocalQuizInstance> {
  final Value<String> quizId;
  final Value<String> stepId;
  final Value<String> quizMode;
  final Value<String> quizJson;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const LocalQuizInstancesCompanion({
    this.quizId = const Value.absent(),
    this.stepId = const Value.absent(),
    this.quizMode = const Value.absent(),
    this.quizJson = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalQuizInstancesCompanion.insert({
    required String quizId,
    required String stepId,
    required String quizMode,
    required String quizJson,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  })  : quizId = Value(quizId),
        stepId = Value(stepId),
        quizMode = Value(quizMode),
        quizJson = Value(quizJson),
        fetchedAt = Value(fetchedAt);
  static Insertable<LocalQuizInstance> custom({
    Expression<String>? quizId,
    Expression<String>? stepId,
    Expression<String>? quizMode,
    Expression<String>? quizJson,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (quizId != null) 'quiz_id': quizId,
      if (stepId != null) 'step_id': stepId,
      if (quizMode != null) 'quiz_mode': quizMode,
      if (quizJson != null) 'quiz_json': quizJson,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalQuizInstancesCompanion copyWith(
      {Value<String>? quizId,
      Value<String>? stepId,
      Value<String>? quizMode,
      Value<String>? quizJson,
      Value<DateTime>? fetchedAt,
      Value<int>? rowid}) {
    return LocalQuizInstancesCompanion(
      quizId: quizId ?? this.quizId,
      stepId: stepId ?? this.stepId,
      quizMode: quizMode ?? this.quizMode,
      quizJson: quizJson ?? this.quizJson,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (quizId.present) {
      map['quiz_id'] = Variable<String>(quizId.value);
    }
    if (stepId.present) {
      map['step_id'] = Variable<String>(stepId.value);
    }
    if (quizMode.present) {
      map['quiz_mode'] = Variable<String>(quizMode.value);
    }
    if (quizJson.present) {
      map['quiz_json'] = Variable<String>(quizJson.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalQuizInstancesCompanion(')
          ..write('quizId: $quizId, ')
          ..write('stepId: $stepId, ')
          ..write('quizMode: $quizMode, ')
          ..write('quizJson: $quizJson, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSessionEventsTable extends LocalSessionEvents
    with TableInfo<$LocalSessionEventsTable, LocalSessionEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSessionEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _eventTypeMeta =
      const VerificationMeta('eventType');
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
      'synced', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("synced" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [id, eventType, payloadJson, occurredAt, synced];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_session_events';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSessionEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_type')) {
      context.handle(_eventTypeMeta,
          eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta));
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(_syncedMeta,
          synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSessionEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSessionEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      eventType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_type'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}occurred_at'])!,
      synced: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced'])!,
    );
  }

  @override
  $LocalSessionEventsTable createAlias(String alias) {
    return $LocalSessionEventsTable(attachedDatabase, alias);
  }
}

class LocalSessionEvent extends DataClass
    implements Insertable<LocalSessionEvent> {
  final int id;
  final String eventType;
  final String payloadJson;
  final DateTime occurredAt;
  final bool synced;
  const LocalSessionEvent(
      {required this.id,
      required this.eventType,
      required this.payloadJson,
      required this.occurredAt,
      required this.synced});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_type'] = Variable<String>(eventType);
    map['payload_json'] = Variable<String>(payloadJson);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  LocalSessionEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalSessionEventsCompanion(
      id: Value(id),
      eventType: Value(eventType),
      payloadJson: Value(payloadJson),
      occurredAt: Value(occurredAt),
      synced: Value(synced),
    );
  }

  factory LocalSessionEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSessionEvent(
      id: serializer.fromJson<int>(json['id']),
      eventType: serializer.fromJson<String>(json['eventType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventType': serializer.toJson<String>(eventType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  LocalSessionEvent copyWith(
          {int? id,
          String? eventType,
          String? payloadJson,
          DateTime? occurredAt,
          bool? synced}) =>
      LocalSessionEvent(
        id: id ?? this.id,
        eventType: eventType ?? this.eventType,
        payloadJson: payloadJson ?? this.payloadJson,
        occurredAt: occurredAt ?? this.occurredAt,
        synced: synced ?? this.synced,
      );
  LocalSessionEvent copyWithCompanion(LocalSessionEventsCompanion data) {
    return LocalSessionEvent(
      id: data.id.present ? data.id.value : this.id,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSessionEvent(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, eventType, payloadJson, occurredAt, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSessionEvent &&
          other.id == this.id &&
          other.eventType == this.eventType &&
          other.payloadJson == this.payloadJson &&
          other.occurredAt == this.occurredAt &&
          other.synced == this.synced);
}

class LocalSessionEventsCompanion extends UpdateCompanion<LocalSessionEvent> {
  final Value<int> id;
  final Value<String> eventType;
  final Value<String> payloadJson;
  final Value<DateTime> occurredAt;
  final Value<bool> synced;
  const LocalSessionEventsCompanion({
    this.id = const Value.absent(),
    this.eventType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.synced = const Value.absent(),
  });
  LocalSessionEventsCompanion.insert({
    this.id = const Value.absent(),
    required String eventType,
    required String payloadJson,
    required DateTime occurredAt,
    this.synced = const Value.absent(),
  })  : eventType = Value(eventType),
        payloadJson = Value(payloadJson),
        occurredAt = Value(occurredAt);
  static Insertable<LocalSessionEvent> custom({
    Expression<int>? id,
    Expression<String>? eventType,
    Expression<String>? payloadJson,
    Expression<DateTime>? occurredAt,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventType != null) 'event_type': eventType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (synced != null) 'synced': synced,
    });
  }

  LocalSessionEventsCompanion copyWith(
      {Value<int>? id,
      Value<String>? eventType,
      Value<String>? payloadJson,
      Value<DateTime>? occurredAt,
      Value<bool>? synced}) {
    return LocalSessionEventsCompanion(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      payloadJson: payloadJson ?? this.payloadJson,
      occurredAt: occurredAt ?? this.occurredAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSessionEventsCompanion(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

class $LocalPushInboxTable extends LocalPushInbox
    with TableInfo<$LocalPushInboxTable, LocalPushInboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPushInboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta =
      const VerificationMeta('messageId');
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
      'message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deepLinkMeta =
      const VerificationMeta('deepLink');
  @override
  late final GeneratedColumn<String> deepLink = GeneratedColumn<String>(
      'deep_link', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dataJsonMeta =
      const VerificationMeta('dataJson');
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
      'data_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
      'received_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _readMeta = const VerificationMeta('read');
  @override
  late final GeneratedColumn<bool> read = GeneratedColumn<bool>(
      'read', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("read" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns =>
      [messageId, title, body, deepLink, dataJson, receivedAt, read];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_push_inbox';
  @override
  VerificationContext validateIntegrity(Insertable<LocalPushInboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(_messageIdMeta,
          messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta));
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    }
    if (data.containsKey('deep_link')) {
      context.handle(_deepLinkMeta,
          deepLink.isAcceptableOrUnknown(data['deep_link']!, _deepLinkMeta));
    }
    if (data.containsKey('data_json')) {
      context.handle(_dataJsonMeta,
          dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta));
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('read')) {
      context.handle(
          _readMeta, read.isAcceptableOrUnknown(data['read']!, _readMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  LocalPushInboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPushInboxData(
      messageId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body']),
      deepLink: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deep_link']),
      dataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data_json']),
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}received_at'])!,
      read: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}read'])!,
    );
  }

  @override
  $LocalPushInboxTable createAlias(String alias) {
    return $LocalPushInboxTable(attachedDatabase, alias);
  }
}

class LocalPushInboxData extends DataClass
    implements Insertable<LocalPushInboxData> {
  final String messageId;
  final String? title;
  final String? body;
  final String? deepLink;
  final String? dataJson;
  final DateTime receivedAt;
  final bool read;
  const LocalPushInboxData(
      {required this.messageId,
      this.title,
      this.body,
      this.deepLink,
      this.dataJson,
      required this.receivedAt,
      required this.read});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || deepLink != null) {
      map['deep_link'] = Variable<String>(deepLink);
    }
    if (!nullToAbsent || dataJson != null) {
      map['data_json'] = Variable<String>(dataJson);
    }
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['read'] = Variable<bool>(read);
    return map;
  }

  LocalPushInboxCompanion toCompanion(bool nullToAbsent) {
    return LocalPushInboxCompanion(
      messageId: Value(messageId),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      deepLink: deepLink == null && nullToAbsent
          ? const Value.absent()
          : Value(deepLink),
      dataJson: dataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(dataJson),
      receivedAt: Value(receivedAt),
      read: Value(read),
    );
  }

  factory LocalPushInboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPushInboxData(
      messageId: serializer.fromJson<String>(json['messageId']),
      title: serializer.fromJson<String?>(json['title']),
      body: serializer.fromJson<String?>(json['body']),
      deepLink: serializer.fromJson<String?>(json['deepLink']),
      dataJson: serializer.fromJson<String?>(json['dataJson']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      read: serializer.fromJson<bool>(json['read']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'title': serializer.toJson<String?>(title),
      'body': serializer.toJson<String?>(body),
      'deepLink': serializer.toJson<String?>(deepLink),
      'dataJson': serializer.toJson<String?>(dataJson),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'read': serializer.toJson<bool>(read),
    };
  }

  LocalPushInboxData copyWith(
          {String? messageId,
          Value<String?> title = const Value.absent(),
          Value<String?> body = const Value.absent(),
          Value<String?> deepLink = const Value.absent(),
          Value<String?> dataJson = const Value.absent(),
          DateTime? receivedAt,
          bool? read}) =>
      LocalPushInboxData(
        messageId: messageId ?? this.messageId,
        title: title.present ? title.value : this.title,
        body: body.present ? body.value : this.body,
        deepLink: deepLink.present ? deepLink.value : this.deepLink,
        dataJson: dataJson.present ? dataJson.value : this.dataJson,
        receivedAt: receivedAt ?? this.receivedAt,
        read: read ?? this.read,
      );
  LocalPushInboxData copyWithCompanion(LocalPushInboxCompanion data) {
    return LocalPushInboxData(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      deepLink: data.deepLink.present ? data.deepLink.value : this.deepLink,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
      read: data.read.present ? data.read.value : this.read,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPushInboxData(')
          ..write('messageId: $messageId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('deepLink: $deepLink, ')
          ..write('dataJson: $dataJson, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('read: $read')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(messageId, title, body, deepLink, dataJson, receivedAt, read);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPushInboxData &&
          other.messageId == this.messageId &&
          other.title == this.title &&
          other.body == this.body &&
          other.deepLink == this.deepLink &&
          other.dataJson == this.dataJson &&
          other.receivedAt == this.receivedAt &&
          other.read == this.read);
}

class LocalPushInboxCompanion extends UpdateCompanion<LocalPushInboxData> {
  final Value<String> messageId;
  final Value<String?> title;
  final Value<String?> body;
  final Value<String?> deepLink;
  final Value<String?> dataJson;
  final Value<DateTime> receivedAt;
  final Value<bool> read;
  final Value<int> rowid;
  const LocalPushInboxCompanion({
    this.messageId = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.deepLink = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.read = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPushInboxCompanion.insert({
    required String messageId,
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.deepLink = const Value.absent(),
    this.dataJson = const Value.absent(),
    required DateTime receivedAt,
    this.read = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : messageId = Value(messageId),
        receivedAt = Value(receivedAt);
  static Insertable<LocalPushInboxData> custom({
    Expression<String>? messageId,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? deepLink,
    Expression<String>? dataJson,
    Expression<DateTime>? receivedAt,
    Expression<bool>? read,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (deepLink != null) 'deep_link': deepLink,
      if (dataJson != null) 'data_json': dataJson,
      if (receivedAt != null) 'received_at': receivedAt,
      if (read != null) 'read': read,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPushInboxCompanion copyWith(
      {Value<String>? messageId,
      Value<String?>? title,
      Value<String?>? body,
      Value<String?>? deepLink,
      Value<String?>? dataJson,
      Value<DateTime>? receivedAt,
      Value<bool>? read,
      Value<int>? rowid}) {
    return LocalPushInboxCompanion(
      messageId: messageId ?? this.messageId,
      title: title ?? this.title,
      body: body ?? this.body,
      deepLink: deepLink ?? this.deepLink,
      dataJson: dataJson ?? this.dataJson,
      receivedAt: receivedAt ?? this.receivedAt,
      read: read ?? this.read,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (deepLink.present) {
      map['deep_link'] = Variable<String>(deepLink.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (read.present) {
      map['read'] = Variable<bool>(read.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPushInboxCompanion(')
          ..write('messageId: $messageId, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('deepLink: $deepLink, ')
          ..write('dataJson: $dataJson, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('read: $read, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAudioCacheTable extends LocalAudioCache
    with TableInfo<$LocalAudioCacheTable, LocalAudioCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAudioCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetKeyMeta =
      const VerificationMeta('assetKey');
  @override
  late final GeneratedColumn<String> assetKey = GeneratedColumn<String>(
      'asset_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _assetIdMeta =
      const VerificationMeta('assetId');
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
      'asset_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _stepIdMeta = const VerificationMeta('stepId');
  @override
  late final GeneratedColumn<String> stepId = GeneratedColumn<String>(
      'step_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationMsMeta =
      const VerificationMeta('durationMs');
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
      'duration_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [assetKey, assetId, stepId, localPath, durationMs, sizeBytes, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_audio_cache';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalAudioCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_key')) {
      context.handle(_assetKeyMeta,
          assetKey.isAcceptableOrUnknown(data['asset_key']!, _assetKeyMeta));
    } else if (isInserting) {
      context.missing(_assetKeyMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(_assetIdMeta,
          assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta));
    }
    if (data.containsKey('step_id')) {
      context.handle(_stepIdMeta,
          stepId.isAcceptableOrUnknown(data['step_id']!, _stepIdMeta));
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetKey};
  @override
  LocalAudioCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAudioCacheData(
      assetKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}asset_key'])!,
      assetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}asset_id']),
      stepId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}step_id']),
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path'])!,
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms']),
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes']),
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $LocalAudioCacheTable createAlias(String alias) {
    return $LocalAudioCacheTable(attachedDatabase, alias);
  }
}

class LocalAudioCacheData extends DataClass
    implements Insertable<LocalAudioCacheData> {
  final String assetKey;
  final String? assetId;
  final String? stepId;
  final String localPath;
  final int? durationMs;
  final int? sizeBytes;
  final DateTime cachedAt;
  const LocalAudioCacheData(
      {required this.assetKey,
      this.assetId,
      this.stepId,
      required this.localPath,
      this.durationMs,
      this.sizeBytes,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_key'] = Variable<String>(assetKey);
    if (!nullToAbsent || assetId != null) {
      map['asset_id'] = Variable<String>(assetId);
    }
    if (!nullToAbsent || stepId != null) {
      map['step_id'] = Variable<String>(stepId);
    }
    map['local_path'] = Variable<String>(localPath);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  LocalAudioCacheCompanion toCompanion(bool nullToAbsent) {
    return LocalAudioCacheCompanion(
      assetKey: Value(assetKey),
      assetId: assetId == null && nullToAbsent
          ? const Value.absent()
          : Value(assetId),
      stepId:
          stepId == null && nullToAbsent ? const Value.absent() : Value(stepId),
      localPath: Value(localPath),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      cachedAt: Value(cachedAt),
    );
  }

  factory LocalAudioCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAudioCacheData(
      assetKey: serializer.fromJson<String>(json['assetKey']),
      assetId: serializer.fromJson<String?>(json['assetId']),
      stepId: serializer.fromJson<String?>(json['stepId']),
      localPath: serializer.fromJson<String>(json['localPath']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetKey': serializer.toJson<String>(assetKey),
      'assetId': serializer.toJson<String?>(assetId),
      'stepId': serializer.toJson<String?>(stepId),
      'localPath': serializer.toJson<String>(localPath),
      'durationMs': serializer.toJson<int?>(durationMs),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  LocalAudioCacheData copyWith(
          {String? assetKey,
          Value<String?> assetId = const Value.absent(),
          Value<String?> stepId = const Value.absent(),
          String? localPath,
          Value<int?> durationMs = const Value.absent(),
          Value<int?> sizeBytes = const Value.absent(),
          DateTime? cachedAt}) =>
      LocalAudioCacheData(
        assetKey: assetKey ?? this.assetKey,
        assetId: assetId.present ? assetId.value : this.assetId,
        stepId: stepId.present ? stepId.value : this.stepId,
        localPath: localPath ?? this.localPath,
        durationMs: durationMs.present ? durationMs.value : this.durationMs,
        sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  LocalAudioCacheData copyWithCompanion(LocalAudioCacheCompanion data) {
    return LocalAudioCacheData(
      assetKey: data.assetKey.present ? data.assetKey.value : this.assetKey,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      stepId: data.stepId.present ? data.stepId.value : this.stepId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAudioCacheData(')
          ..write('assetKey: $assetKey, ')
          ..write('assetId: $assetId, ')
          ..write('stepId: $stepId, ')
          ..write('localPath: $localPath, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      assetKey, assetId, stepId, localPath, durationMs, sizeBytes, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAudioCacheData &&
          other.assetKey == this.assetKey &&
          other.assetId == this.assetId &&
          other.stepId == this.stepId &&
          other.localPath == this.localPath &&
          other.durationMs == this.durationMs &&
          other.sizeBytes == this.sizeBytes &&
          other.cachedAt == this.cachedAt);
}

class LocalAudioCacheCompanion extends UpdateCompanion<LocalAudioCacheData> {
  final Value<String> assetKey;
  final Value<String?> assetId;
  final Value<String?> stepId;
  final Value<String> localPath;
  final Value<int?> durationMs;
  final Value<int?> sizeBytes;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const LocalAudioCacheCompanion({
    this.assetKey = const Value.absent(),
    this.assetId = const Value.absent(),
    this.stepId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAudioCacheCompanion.insert({
    required String assetKey,
    this.assetId = const Value.absent(),
    this.stepId = const Value.absent(),
    required String localPath,
    this.durationMs = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  })  : assetKey = Value(assetKey),
        localPath = Value(localPath),
        cachedAt = Value(cachedAt);
  static Insertable<LocalAudioCacheData> custom({
    Expression<String>? assetKey,
    Expression<String>? assetId,
    Expression<String>? stepId,
    Expression<String>? localPath,
    Expression<int>? durationMs,
    Expression<int>? sizeBytes,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetKey != null) 'asset_key': assetKey,
      if (assetId != null) 'asset_id': assetId,
      if (stepId != null) 'step_id': stepId,
      if (localPath != null) 'local_path': localPath,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAudioCacheCompanion copyWith(
      {Value<String>? assetKey,
      Value<String?>? assetId,
      Value<String?>? stepId,
      Value<String>? localPath,
      Value<int?>? durationMs,
      Value<int?>? sizeBytes,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return LocalAudioCacheCompanion(
      assetKey: assetKey ?? this.assetKey,
      assetId: assetId ?? this.assetId,
      stepId: stepId ?? this.stepId,
      localPath: localPath ?? this.localPath,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetKey.present) {
      map['asset_key'] = Variable<String>(assetKey.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (stepId.present) {
      map['step_id'] = Variable<String>(stepId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAudioCacheCompanion(')
          ..write('assetKey: $assetKey, ')
          ..write('assetId: $assetId, ')
          ..write('stepId: $stepId, ')
          ..write('localPath: $localPath, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSyncQueueTable extends LocalSyncQueue
    with TableInfo<$LocalSyncQueueTable, LocalSyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _idempotencyKeyMeta =
      const VerificationMeta('idempotencyKey');
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
      'idempotency_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _nextAttemptAtMeta =
      const VerificationMeta('nextAttemptAt');
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>('next_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        operation,
        payloadJson,
        idempotencyKey,
        attempts,
        lastError,
        createdAt,
        nextAttemptAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sync_queue';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSyncQueueData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
          _idempotencyKeyMeta,
          idempotencyKey.isAcceptableOrUnknown(
              data['idempotency_key']!, _idempotencyKeyMeta));
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
          _nextAttemptAtMeta,
          nextAttemptAt.isAcceptableOrUnknown(
              data['next_attempt_at']!, _nextAttemptAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSyncQueueData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      idempotencyKey: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}idempotency_key'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}next_attempt_at']),
    );
  }

  @override
  $LocalSyncQueueTable createAlias(String alias) {
    return $LocalSyncQueueTable(attachedDatabase, alias);
  }
}

class LocalSyncQueueData extends DataClass
    implements Insertable<LocalSyncQueueData> {
  final int id;

  /// Logical operation name, e.g. "submitQuiz", "addLibraryBook".
  final String operation;

  /// JSON-encoded arguments for the operation.
  final String payloadJson;

  /// Idempotency key so a retried op is not applied twice server-side.
  final String idempotencyKey;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? nextAttemptAt;
  const LocalSyncQueueData(
      {required this.id,
      required this.operation,
      required this.payloadJson,
      required this.idempotencyKey,
      required this.attempts,
      this.lastError,
      required this.createdAt,
      this.nextAttemptAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operation'] = Variable<String>(operation);
    map['payload_json'] = Variable<String>(payloadJson);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    return map;
  }

  LocalSyncQueueCompanion toCompanion(bool nullToAbsent) {
    return LocalSyncQueueCompanion(
      id: Value(id),
      operation: Value(operation),
      payloadJson: Value(payloadJson),
      idempotencyKey: Value(idempotencyKey),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
    );
  }

  factory LocalSyncQueueData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      operation: serializer.fromJson<String>(json['operation']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operation': serializer.toJson<String>(operation),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
    };
  }

  LocalSyncQueueData copyWith(
          {int? id,
          String? operation,
          String? payloadJson,
          String? idempotencyKey,
          int? attempts,
          Value<String?> lastError = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> nextAttemptAt = const Value.absent()}) =>
      LocalSyncQueueData(
        id: id ?? this.id,
        operation: operation ?? this.operation,
        payloadJson: payloadJson ?? this.payloadJson,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
        attempts: attempts ?? this.attempts,
        lastError: lastError.present ? lastError.value : this.lastError,
        createdAt: createdAt ?? this.createdAt,
        nextAttemptAt:
            nextAttemptAt.present ? nextAttemptAt.value : this.nextAttemptAt,
      );
  LocalSyncQueueData copyWithCompanion(LocalSyncQueueCompanion data) {
    return LocalSyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      operation: data.operation.present ? data.operation.value : this.operation,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSyncQueueData(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, operation, payloadJson, idempotencyKey,
      attempts, lastError, createdAt, nextAttemptAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSyncQueueData &&
          other.id == this.id &&
          other.operation == this.operation &&
          other.payloadJson == this.payloadJson &&
          other.idempotencyKey == this.idempotencyKey &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.nextAttemptAt == this.nextAttemptAt);
}

class LocalSyncQueueCompanion extends UpdateCompanion<LocalSyncQueueData> {
  final Value<int> id;
  final Value<String> operation;
  final Value<String> payloadJson;
  final Value<String> idempotencyKey;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime?> nextAttemptAt;
  const LocalSyncQueueCompanion({
    this.id = const Value.absent(),
    this.operation = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
  });
  LocalSyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String operation,
    required String payloadJson,
    required String idempotencyKey,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    this.nextAttemptAt = const Value.absent(),
  })  : operation = Value(operation),
        payloadJson = Value(payloadJson),
        idempotencyKey = Value(idempotencyKey),
        createdAt = Value(createdAt);
  static Insertable<LocalSyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? operation,
    Expression<String>? payloadJson,
    Expression<String>? idempotencyKey,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? nextAttemptAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operation != null) 'operation': operation,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
    });
  }

  LocalSyncQueueCompanion copyWith(
      {Value<int>? id,
      Value<String>? operation,
      Value<String>? payloadJson,
      Value<String>? idempotencyKey,
      Value<int>? attempts,
      Value<String?>? lastError,
      Value<DateTime>? createdAt,
      Value<DateTime?>? nextAttemptAt}) {
    return LocalSyncQueueCompanion(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$OfflineDatabase extends GeneratedDatabase {
  _$OfflineDatabase(QueryExecutor e) : super(e);
  $OfflineDatabaseManager get managers => $OfflineDatabaseManager(this);
  late final $LocalUserBooksTable localUserBooks = $LocalUserBooksTable(this);
  late final $LocalPlanStepsTable localPlanSteps = $LocalPlanStepsTable(this);
  late final $LocalQuizInstancesTable localQuizInstances =
      $LocalQuizInstancesTable(this);
  late final $LocalSessionEventsTable localSessionEvents =
      $LocalSessionEventsTable(this);
  late final $LocalPushInboxTable localPushInbox = $LocalPushInboxTable(this);
  late final $LocalAudioCacheTable localAudioCache =
      $LocalAudioCacheTable(this);
  late final $LocalSyncQueueTable localSyncQueue = $LocalSyncQueueTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        localUserBooks,
        localPlanSteps,
        localQuizInstances,
        localSessionEvents,
        localPushInbox,
        localAudioCache,
        localSyncQueue
      ];
}

typedef $$LocalUserBooksTableCreateCompanionBuilder = LocalUserBooksCompanion
    Function({
  required String id,
  required String bookId,
  required String status,
  Value<int?> currentPage,
  Value<int?> targetNightlyPages,
  Value<String?> bookJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalUserBooksTableUpdateCompanionBuilder = LocalUserBooksCompanion
    Function({
  Value<String> id,
  Value<String> bookId,
  Value<String> status,
  Value<int?> currentPage,
  Value<int?> targetNightlyPages,
  Value<String?> bookJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalUserBooksTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalUserBooksTable> {
  $$LocalUserBooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentPage => $composableBuilder(
      column: $table.currentPage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get targetNightlyPages => $composableBuilder(
      column: $table.targetNightlyPages,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookJson => $composableBuilder(
      column: $table.bookJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalUserBooksTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalUserBooksTable> {
  $$LocalUserBooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentPage => $composableBuilder(
      column: $table.currentPage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get targetNightlyPages => $composableBuilder(
      column: $table.targetNightlyPages,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookJson => $composableBuilder(
      column: $table.bookJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalUserBooksTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalUserBooksTable> {
  $$LocalUserBooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get currentPage => $composableBuilder(
      column: $table.currentPage, builder: (column) => column);

  GeneratedColumn<int> get targetNightlyPages => $composableBuilder(
      column: $table.targetNightlyPages, builder: (column) => column);

  GeneratedColumn<String> get bookJson =>
      $composableBuilder(column: $table.bookJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalUserBooksTableTableManager extends RootTableManager<
    _$OfflineDatabase,
    $LocalUserBooksTable,
    LocalUserBook,
    $$LocalUserBooksTableFilterComposer,
    $$LocalUserBooksTableOrderingComposer,
    $$LocalUserBooksTableAnnotationComposer,
    $$LocalUserBooksTableCreateCompanionBuilder,
    $$LocalUserBooksTableUpdateCompanionBuilder,
    (
      LocalUserBook,
      BaseReferences<_$OfflineDatabase, $LocalUserBooksTable, LocalUserBook>
    ),
    LocalUserBook,
    PrefetchHooks Function()> {
  $$LocalUserBooksTableTableManager(
      _$OfflineDatabase db, $LocalUserBooksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalUserBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalUserBooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalUserBooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> bookId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int?> currentPage = const Value.absent(),
            Value<int?> targetNightlyPages = const Value.absent(),
            Value<String?> bookJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalUserBooksCompanion(
            id: id,
            bookId: bookId,
            status: status,
            currentPage: currentPage,
            targetNightlyPages: targetNightlyPages,
            bookJson: bookJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String bookId,
            required String status,
            Value<int?> currentPage = const Value.absent(),
            Value<int?> targetNightlyPages = const Value.absent(),
            Value<String?> bookJson = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalUserBooksCompanion.insert(
            id: id,
            bookId: bookId,
            status: status,
            currentPage: currentPage,
            targetNightlyPages: targetNightlyPages,
            bookJson: bookJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalUserBooksTableProcessedTableManager = ProcessedTableManager<
    _$OfflineDatabase,
    $LocalUserBooksTable,
    LocalUserBook,
    $$LocalUserBooksTableFilterComposer,
    $$LocalUserBooksTableOrderingComposer,
    $$LocalUserBooksTableAnnotationComposer,
    $$LocalUserBooksTableCreateCompanionBuilder,
    $$LocalUserBooksTableUpdateCompanionBuilder,
    (
      LocalUserBook,
      BaseReferences<_$OfflineDatabase, $LocalUserBooksTable, LocalUserBook>
    ),
    LocalUserBook,
    PrefetchHooks Function()>;
typedef $$LocalPlanStepsTableCreateCompanionBuilder = LocalPlanStepsCompanion
    Function({
  required String stepId,
  required String planId,
  required int stepIndex,
  required String status,
  required String stepJson,
  Value<DateTime?> unlocksAt,
  Value<String?> ttsAssetId,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalPlanStepsTableUpdateCompanionBuilder = LocalPlanStepsCompanion
    Function({
  Value<String> stepId,
  Value<String> planId,
  Value<int> stepIndex,
  Value<String> status,
  Value<String> stepJson,
  Value<DateTime?> unlocksAt,
  Value<String?> ttsAssetId,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalPlanStepsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalPlanStepsTable> {
  $$LocalPlanStepsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get stepId => $composableBuilder(
      column: $table.stepId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get stepIndex => $composableBuilder(
      column: $table.stepIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stepJson => $composableBuilder(
      column: $table.stepJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get unlocksAt => $composableBuilder(
      column: $table.unlocksAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ttsAssetId => $composableBuilder(
      column: $table.ttsAssetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalPlanStepsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalPlanStepsTable> {
  $$LocalPlanStepsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get stepId => $composableBuilder(
      column: $table.stepId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get stepIndex => $composableBuilder(
      column: $table.stepIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stepJson => $composableBuilder(
      column: $table.stepJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get unlocksAt => $composableBuilder(
      column: $table.unlocksAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ttsAssetId => $composableBuilder(
      column: $table.ttsAssetId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalPlanStepsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalPlanStepsTable> {
  $$LocalPlanStepsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get stepId =>
      $composableBuilder(column: $table.stepId, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<int> get stepIndex =>
      $composableBuilder(column: $table.stepIndex, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get stepJson =>
      $composableBuilder(column: $table.stepJson, builder: (column) => column);

  GeneratedColumn<DateTime> get unlocksAt =>
      $composableBuilder(column: $table.unlocksAt, builder: (column) => column);

  GeneratedColumn<String> get ttsAssetId => $composableBuilder(
      column: $table.ttsAssetId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalPlanStepsTableTableManager extends RootTableManager<
    _$OfflineDatabase,
    $LocalPlanStepsTable,
    LocalPlanStep,
    $$LocalPlanStepsTableFilterComposer,
    $$LocalPlanStepsTableOrderingComposer,
    $$LocalPlanStepsTableAnnotationComposer,
    $$LocalPlanStepsTableCreateCompanionBuilder,
    $$LocalPlanStepsTableUpdateCompanionBuilder,
    (
      LocalPlanStep,
      BaseReferences<_$OfflineDatabase, $LocalPlanStepsTable, LocalPlanStep>
    ),
    LocalPlanStep,
    PrefetchHooks Function()> {
  $$LocalPlanStepsTableTableManager(
      _$OfflineDatabase db, $LocalPlanStepsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPlanStepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPlanStepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPlanStepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> stepId = const Value.absent(),
            Value<String> planId = const Value.absent(),
            Value<int> stepIndex = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> stepJson = const Value.absent(),
            Value<DateTime?> unlocksAt = const Value.absent(),
            Value<String?> ttsAssetId = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPlanStepsCompanion(
            stepId: stepId,
            planId: planId,
            stepIndex: stepIndex,
            status: status,
            stepJson: stepJson,
            unlocksAt: unlocksAt,
            ttsAssetId: ttsAssetId,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String stepId,
            required String planId,
            required int stepIndex,
            required String status,
            required String stepJson,
            Value<DateTime?> unlocksAt = const Value.absent(),
            Value<String?> ttsAssetId = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPlanStepsCompanion.insert(
            stepId: stepId,
            planId: planId,
            stepIndex: stepIndex,
            status: status,
            stepJson: stepJson,
            unlocksAt: unlocksAt,
            ttsAssetId: ttsAssetId,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalPlanStepsTableProcessedTableManager = ProcessedTableManager<
    _$OfflineDatabase,
    $LocalPlanStepsTable,
    LocalPlanStep,
    $$LocalPlanStepsTableFilterComposer,
    $$LocalPlanStepsTableOrderingComposer,
    $$LocalPlanStepsTableAnnotationComposer,
    $$LocalPlanStepsTableCreateCompanionBuilder,
    $$LocalPlanStepsTableUpdateCompanionBuilder,
    (
      LocalPlanStep,
      BaseReferences<_$OfflineDatabase, $LocalPlanStepsTable, LocalPlanStep>
    ),
    LocalPlanStep,
    PrefetchHooks Function()>;
typedef $$LocalQuizInstancesTableCreateCompanionBuilder
    = LocalQuizInstancesCompanion Function({
  required String quizId,
  required String stepId,
  required String quizMode,
  required String quizJson,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$LocalQuizInstancesTableUpdateCompanionBuilder
    = LocalQuizInstancesCompanion Function({
  Value<String> quizId,
  Value<String> stepId,
  Value<String> quizMode,
  Value<String> quizJson,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$LocalQuizInstancesTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalQuizInstancesTable> {
  $$LocalQuizInstancesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get quizId => $composableBuilder(
      column: $table.quizId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stepId => $composableBuilder(
      column: $table.stepId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get quizMode => $composableBuilder(
      column: $table.quizMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get quizJson => $composableBuilder(
      column: $table.quizJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalQuizInstancesTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalQuizInstancesTable> {
  $$LocalQuizInstancesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get quizId => $composableBuilder(
      column: $table.quizId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stepId => $composableBuilder(
      column: $table.stepId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get quizMode => $composableBuilder(
      column: $table.quizMode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get quizJson => $composableBuilder(
      column: $table.quizJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalQuizInstancesTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalQuizInstancesTable> {
  $$LocalQuizInstancesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get quizId =>
      $composableBuilder(column: $table.quizId, builder: (column) => column);

  GeneratedColumn<String> get stepId =>
      $composableBuilder(column: $table.stepId, builder: (column) => column);

  GeneratedColumn<String> get quizMode =>
      $composableBuilder(column: $table.quizMode, builder: (column) => column);

  GeneratedColumn<String> get quizJson =>
      $composableBuilder(column: $table.quizJson, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$LocalQuizInstancesTableTableManager extends RootTableManager<
    _$OfflineDatabase,
    $LocalQuizInstancesTable,
    LocalQuizInstance,
    $$LocalQuizInstancesTableFilterComposer,
    $$LocalQuizInstancesTableOrderingComposer,
    $$LocalQuizInstancesTableAnnotationComposer,
    $$LocalQuizInstancesTableCreateCompanionBuilder,
    $$LocalQuizInstancesTableUpdateCompanionBuilder,
    (
      LocalQuizInstance,
      BaseReferences<_$OfflineDatabase, $LocalQuizInstancesTable,
          LocalQuizInstance>
    ),
    LocalQuizInstance,
    PrefetchHooks Function()> {
  $$LocalQuizInstancesTableTableManager(
      _$OfflineDatabase db, $LocalQuizInstancesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalQuizInstancesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalQuizInstancesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalQuizInstancesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> quizId = const Value.absent(),
            Value<String> stepId = const Value.absent(),
            Value<String> quizMode = const Value.absent(),
            Value<String> quizJson = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalQuizInstancesCompanion(
            quizId: quizId,
            stepId: stepId,
            quizMode: quizMode,
            quizJson: quizJson,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String quizId,
            required String stepId,
            required String quizMode,
            required String quizJson,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalQuizInstancesCompanion.insert(
            quizId: quizId,
            stepId: stepId,
            quizMode: quizMode,
            quizJson: quizJson,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalQuizInstancesTableProcessedTableManager = ProcessedTableManager<
    _$OfflineDatabase,
    $LocalQuizInstancesTable,
    LocalQuizInstance,
    $$LocalQuizInstancesTableFilterComposer,
    $$LocalQuizInstancesTableOrderingComposer,
    $$LocalQuizInstancesTableAnnotationComposer,
    $$LocalQuizInstancesTableCreateCompanionBuilder,
    $$LocalQuizInstancesTableUpdateCompanionBuilder,
    (
      LocalQuizInstance,
      BaseReferences<_$OfflineDatabase, $LocalQuizInstancesTable,
          LocalQuizInstance>
    ),
    LocalQuizInstance,
    PrefetchHooks Function()>;
typedef $$LocalSessionEventsTableCreateCompanionBuilder
    = LocalSessionEventsCompanion Function({
  Value<int> id,
  required String eventType,
  required String payloadJson,
  required DateTime occurredAt,
  Value<bool> synced,
});
typedef $$LocalSessionEventsTableUpdateCompanionBuilder
    = LocalSessionEventsCompanion Function({
  Value<int> id,
  Value<String> eventType,
  Value<String> payloadJson,
  Value<DateTime> occurredAt,
  Value<bool> synced,
});

class $$LocalSessionEventsTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalSessionEventsTable> {
  $$LocalSessionEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnFilters(column));
}

class $$LocalSessionEventsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalSessionEventsTable> {
  $$LocalSessionEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get synced => $composableBuilder(
      column: $table.synced, builder: (column) => ColumnOrderings(column));
}

class $$LocalSessionEventsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalSessionEventsTable> {
  $$LocalSessionEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$LocalSessionEventsTableTableManager extends RootTableManager<
    _$OfflineDatabase,
    $LocalSessionEventsTable,
    LocalSessionEvent,
    $$LocalSessionEventsTableFilterComposer,
    $$LocalSessionEventsTableOrderingComposer,
    $$LocalSessionEventsTableAnnotationComposer,
    $$LocalSessionEventsTableCreateCompanionBuilder,
    $$LocalSessionEventsTableUpdateCompanionBuilder,
    (
      LocalSessionEvent,
      BaseReferences<_$OfflineDatabase, $LocalSessionEventsTable,
          LocalSessionEvent>
    ),
    LocalSessionEvent,
    PrefetchHooks Function()> {
  $$LocalSessionEventsTableTableManager(
      _$OfflineDatabase db, $LocalSessionEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSessionEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSessionEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSessionEventsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> eventType = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<bool> synced = const Value.absent(),
          }) =>
              LocalSessionEventsCompanion(
            id: id,
            eventType: eventType,
            payloadJson: payloadJson,
            occurredAt: occurredAt,
            synced: synced,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String eventType,
            required String payloadJson,
            required DateTime occurredAt,
            Value<bool> synced = const Value.absent(),
          }) =>
              LocalSessionEventsCompanion.insert(
            id: id,
            eventType: eventType,
            payloadJson: payloadJson,
            occurredAt: occurredAt,
            synced: synced,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalSessionEventsTableProcessedTableManager = ProcessedTableManager<
    _$OfflineDatabase,
    $LocalSessionEventsTable,
    LocalSessionEvent,
    $$LocalSessionEventsTableFilterComposer,
    $$LocalSessionEventsTableOrderingComposer,
    $$LocalSessionEventsTableAnnotationComposer,
    $$LocalSessionEventsTableCreateCompanionBuilder,
    $$LocalSessionEventsTableUpdateCompanionBuilder,
    (
      LocalSessionEvent,
      BaseReferences<_$OfflineDatabase, $LocalSessionEventsTable,
          LocalSessionEvent>
    ),
    LocalSessionEvent,
    PrefetchHooks Function()>;
typedef $$LocalPushInboxTableCreateCompanionBuilder = LocalPushInboxCompanion
    Function({
  required String messageId,
  Value<String?> title,
  Value<String?> body,
  Value<String?> deepLink,
  Value<String?> dataJson,
  required DateTime receivedAt,
  Value<bool> read,
  Value<int> rowid,
});
typedef $$LocalPushInboxTableUpdateCompanionBuilder = LocalPushInboxCompanion
    Function({
  Value<String> messageId,
  Value<String?> title,
  Value<String?> body,
  Value<String?> deepLink,
  Value<String?> dataJson,
  Value<DateTime> receivedAt,
  Value<bool> read,
  Value<int> rowid,
});

class $$LocalPushInboxTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalPushInboxTable> {
  $$LocalPushInboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deepLink => $composableBuilder(
      column: $table.deepLink, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dataJson => $composableBuilder(
      column: $table.dataJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get read => $composableBuilder(
      column: $table.read, builder: (column) => ColumnFilters(column));
}

class $$LocalPushInboxTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalPushInboxTable> {
  $$LocalPushInboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
      column: $table.messageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deepLink => $composableBuilder(
      column: $table.deepLink, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dataJson => $composableBuilder(
      column: $table.dataJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get read => $composableBuilder(
      column: $table.read, builder: (column) => ColumnOrderings(column));
}

class $$LocalPushInboxTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalPushInboxTable> {
  $$LocalPushInboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get deepLink =>
      $composableBuilder(column: $table.deepLink, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);

  GeneratedColumn<bool> get read =>
      $composableBuilder(column: $table.read, builder: (column) => column);
}

class $$LocalPushInboxTableTableManager extends RootTableManager<
    _$OfflineDatabase,
    $LocalPushInboxTable,
    LocalPushInboxData,
    $$LocalPushInboxTableFilterComposer,
    $$LocalPushInboxTableOrderingComposer,
    $$LocalPushInboxTableAnnotationComposer,
    $$LocalPushInboxTableCreateCompanionBuilder,
    $$LocalPushInboxTableUpdateCompanionBuilder,
    (
      LocalPushInboxData,
      BaseReferences<_$OfflineDatabase, $LocalPushInboxTable,
          LocalPushInboxData>
    ),
    LocalPushInboxData,
    PrefetchHooks Function()> {
  $$LocalPushInboxTableTableManager(
      _$OfflineDatabase db, $LocalPushInboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPushInboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPushInboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPushInboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> messageId = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<String?> body = const Value.absent(),
            Value<String?> deepLink = const Value.absent(),
            Value<String?> dataJson = const Value.absent(),
            Value<DateTime> receivedAt = const Value.absent(),
            Value<bool> read = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPushInboxCompanion(
            messageId: messageId,
            title: title,
            body: body,
            deepLink: deepLink,
            dataJson: dataJson,
            receivedAt: receivedAt,
            read: read,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String messageId,
            Value<String?> title = const Value.absent(),
            Value<String?> body = const Value.absent(),
            Value<String?> deepLink = const Value.absent(),
            Value<String?> dataJson = const Value.absent(),
            required DateTime receivedAt,
            Value<bool> read = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPushInboxCompanion.insert(
            messageId: messageId,
            title: title,
            body: body,
            deepLink: deepLink,
            dataJson: dataJson,
            receivedAt: receivedAt,
            read: read,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalPushInboxTableProcessedTableManager = ProcessedTableManager<
    _$OfflineDatabase,
    $LocalPushInboxTable,
    LocalPushInboxData,
    $$LocalPushInboxTableFilterComposer,
    $$LocalPushInboxTableOrderingComposer,
    $$LocalPushInboxTableAnnotationComposer,
    $$LocalPushInboxTableCreateCompanionBuilder,
    $$LocalPushInboxTableUpdateCompanionBuilder,
    (
      LocalPushInboxData,
      BaseReferences<_$OfflineDatabase, $LocalPushInboxTable,
          LocalPushInboxData>
    ),
    LocalPushInboxData,
    PrefetchHooks Function()>;
typedef $$LocalAudioCacheTableCreateCompanionBuilder = LocalAudioCacheCompanion
    Function({
  required String assetKey,
  Value<String?> assetId,
  Value<String?> stepId,
  required String localPath,
  Value<int?> durationMs,
  Value<int?> sizeBytes,
  required DateTime cachedAt,
  Value<int> rowid,
});
typedef $$LocalAudioCacheTableUpdateCompanionBuilder = LocalAudioCacheCompanion
    Function({
  Value<String> assetKey,
  Value<String?> assetId,
  Value<String?> stepId,
  Value<String> localPath,
  Value<int?> durationMs,
  Value<int?> sizeBytes,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

class $$LocalAudioCacheTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalAudioCacheTable> {
  $$LocalAudioCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assetKey => $composableBuilder(
      column: $table.assetKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get assetId => $composableBuilder(
      column: $table.assetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stepId => $composableBuilder(
      column: $table.stepId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalAudioCacheTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalAudioCacheTable> {
  $$LocalAudioCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assetKey => $composableBuilder(
      column: $table.assetKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assetId => $composableBuilder(
      column: $table.assetId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stepId => $composableBuilder(
      column: $table.stepId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalAudioCacheTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalAudioCacheTable> {
  $$LocalAudioCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetKey =>
      $composableBuilder(column: $table.assetKey, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get stepId =>
      $composableBuilder(column: $table.stepId, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$LocalAudioCacheTableTableManager extends RootTableManager<
    _$OfflineDatabase,
    $LocalAudioCacheTable,
    LocalAudioCacheData,
    $$LocalAudioCacheTableFilterComposer,
    $$LocalAudioCacheTableOrderingComposer,
    $$LocalAudioCacheTableAnnotationComposer,
    $$LocalAudioCacheTableCreateCompanionBuilder,
    $$LocalAudioCacheTableUpdateCompanionBuilder,
    (
      LocalAudioCacheData,
      BaseReferences<_$OfflineDatabase, $LocalAudioCacheTable,
          LocalAudioCacheData>
    ),
    LocalAudioCacheData,
    PrefetchHooks Function()> {
  $$LocalAudioCacheTableTableManager(
      _$OfflineDatabase db, $LocalAudioCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAudioCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAudioCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAudioCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> assetKey = const Value.absent(),
            Value<String?> assetId = const Value.absent(),
            Value<String?> stepId = const Value.absent(),
            Value<String> localPath = const Value.absent(),
            Value<int?> durationMs = const Value.absent(),
            Value<int?> sizeBytes = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAudioCacheCompanion(
            assetKey: assetKey,
            assetId: assetId,
            stepId: stepId,
            localPath: localPath,
            durationMs: durationMs,
            sizeBytes: sizeBytes,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String assetKey,
            Value<String?> assetId = const Value.absent(),
            Value<String?> stepId = const Value.absent(),
            required String localPath,
            Value<int?> durationMs = const Value.absent(),
            Value<int?> sizeBytes = const Value.absent(),
            required DateTime cachedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAudioCacheCompanion.insert(
            assetKey: assetKey,
            assetId: assetId,
            stepId: stepId,
            localPath: localPath,
            durationMs: durationMs,
            sizeBytes: sizeBytes,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalAudioCacheTableProcessedTableManager = ProcessedTableManager<
    _$OfflineDatabase,
    $LocalAudioCacheTable,
    LocalAudioCacheData,
    $$LocalAudioCacheTableFilterComposer,
    $$LocalAudioCacheTableOrderingComposer,
    $$LocalAudioCacheTableAnnotationComposer,
    $$LocalAudioCacheTableCreateCompanionBuilder,
    $$LocalAudioCacheTableUpdateCompanionBuilder,
    (
      LocalAudioCacheData,
      BaseReferences<_$OfflineDatabase, $LocalAudioCacheTable,
          LocalAudioCacheData>
    ),
    LocalAudioCacheData,
    PrefetchHooks Function()>;
typedef $$LocalSyncQueueTableCreateCompanionBuilder = LocalSyncQueueCompanion
    Function({
  Value<int> id,
  required String operation,
  required String payloadJson,
  required String idempotencyKey,
  Value<int> attempts,
  Value<String?> lastError,
  required DateTime createdAt,
  Value<DateTime?> nextAttemptAt,
});
typedef $$LocalSyncQueueTableUpdateCompanionBuilder = LocalSyncQueueCompanion
    Function({
  Value<int> id,
  Value<String> operation,
  Value<String> payloadJson,
  Value<String> idempotencyKey,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<DateTime?> nextAttemptAt,
});

class $$LocalSyncQueueTableFilterComposer
    extends Composer<_$OfflineDatabase, $LocalSyncQueueTable> {
  $$LocalSyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => ColumnFilters(column));
}

class $$LocalSyncQueueTableOrderingComposer
    extends Composer<_$OfflineDatabase, $LocalSyncQueueTable> {
  $$LocalSyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt,
      builder: (column) => ColumnOrderings(column));
}

class $$LocalSyncQueueTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $LocalSyncQueueTable> {
  $$LocalSyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
      column: $table.idempotencyKey, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => column);
}

class $$LocalSyncQueueTableTableManager extends RootTableManager<
    _$OfflineDatabase,
    $LocalSyncQueueTable,
    LocalSyncQueueData,
    $$LocalSyncQueueTableFilterComposer,
    $$LocalSyncQueueTableOrderingComposer,
    $$LocalSyncQueueTableAnnotationComposer,
    $$LocalSyncQueueTableCreateCompanionBuilder,
    $$LocalSyncQueueTableUpdateCompanionBuilder,
    (
      LocalSyncQueueData,
      BaseReferences<_$OfflineDatabase, $LocalSyncQueueTable,
          LocalSyncQueueData>
    ),
    LocalSyncQueueData,
    PrefetchHooks Function()> {
  $$LocalSyncQueueTableTableManager(
      _$OfflineDatabase db, $LocalSyncQueueTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<String> idempotencyKey = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> nextAttemptAt = const Value.absent(),
          }) =>
              LocalSyncQueueCompanion(
            id: id,
            operation: operation,
            payloadJson: payloadJson,
            idempotencyKey: idempotencyKey,
            attempts: attempts,
            lastError: lastError,
            createdAt: createdAt,
            nextAttemptAt: nextAttemptAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String operation,
            required String payloadJson,
            required String idempotencyKey,
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            required DateTime createdAt,
            Value<DateTime?> nextAttemptAt = const Value.absent(),
          }) =>
              LocalSyncQueueCompanion.insert(
            id: id,
            operation: operation,
            payloadJson: payloadJson,
            idempotencyKey: idempotencyKey,
            attempts: attempts,
            lastError: lastError,
            createdAt: createdAt,
            nextAttemptAt: nextAttemptAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalSyncQueueTableProcessedTableManager = ProcessedTableManager<
    _$OfflineDatabase,
    $LocalSyncQueueTable,
    LocalSyncQueueData,
    $$LocalSyncQueueTableFilterComposer,
    $$LocalSyncQueueTableOrderingComposer,
    $$LocalSyncQueueTableAnnotationComposer,
    $$LocalSyncQueueTableCreateCompanionBuilder,
    $$LocalSyncQueueTableUpdateCompanionBuilder,
    (
      LocalSyncQueueData,
      BaseReferences<_$OfflineDatabase, $LocalSyncQueueTable,
          LocalSyncQueueData>
    ),
    LocalSyncQueueData,
    PrefetchHooks Function()>;

class $OfflineDatabaseManager {
  final _$OfflineDatabase _db;
  $OfflineDatabaseManager(this._db);
  $$LocalUserBooksTableTableManager get localUserBooks =>
      $$LocalUserBooksTableTableManager(_db, _db.localUserBooks);
  $$LocalPlanStepsTableTableManager get localPlanSteps =>
      $$LocalPlanStepsTableTableManager(_db, _db.localPlanSteps);
  $$LocalQuizInstancesTableTableManager get localQuizInstances =>
      $$LocalQuizInstancesTableTableManager(_db, _db.localQuizInstances);
  $$LocalSessionEventsTableTableManager get localSessionEvents =>
      $$LocalSessionEventsTableTableManager(_db, _db.localSessionEvents);
  $$LocalPushInboxTableTableManager get localPushInbox =>
      $$LocalPushInboxTableTableManager(_db, _db.localPushInbox);
  $$LocalAudioCacheTableTableManager get localAudioCache =>
      $$LocalAudioCacheTableTableManager(_db, _db.localAudioCache);
  $$LocalSyncQueueTableTableManager get localSyncQueue =>
      $$LocalSyncQueueTableTableManager(_db, _db.localSyncQueue);
}
