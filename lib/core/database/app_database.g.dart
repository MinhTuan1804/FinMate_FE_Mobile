// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalTransactionsTable extends LocalTransactions
    with TableInfo<$LocalTransactionsTable, LocalTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientRequestIdMeta = const VerificationMeta(
    'clientRequestId',
  );
  @override
  late final GeneratedColumn<String> clientRequestId = GeneratedColumn<String>(
    'client_request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<BigInt> amountCents = GeneratedColumn<BigInt>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionTypeMeta = const VerificationMeta(
    'transactionType',
  );
  @override
  late final GeneratedColumn<String> transactionType = GeneratedColumn<String>(
    'transaction_type',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _financialAccountIdMeta =
      const VerificationMeta('financialAccountId');
  @override
  late final GeneratedColumn<String> financialAccountId =
      GeneratedColumn<String>(
        'financial_account_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _counterAccountIdMeta = const VerificationMeta(
    'counterAccountId',
  );
  @override
  late final GeneratedColumn<String> counterAccountId = GeneratedColumn<String>(
    'counter_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _merchantNameMeta = const VerificationMeta(
    'merchantName',
  );
  @override
  late final GeneratedColumn<String> merchantName = GeneratedColumn<String>(
    'merchant_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _transactedAtMeta = const VerificationMeta(
    'transactedAt',
  );
  @override
  late final GeneratedColumn<DateTime> transactedAt = GeneratedColumn<DateTime>(
    'transacted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientRequestId,
    amountCents,
    transactionType,
    status,
    categoryId,
    financialAccountId,
    counterAccountId,
    merchantName,
    description,
    transactedAt,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('client_request_id')) {
      context.handle(
        _clientRequestIdMeta,
        clientRequestId.isAcceptableOrUnknown(
          data['client_request_id']!,
          _clientRequestIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientRequestIdMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('transaction_type')) {
      context.handle(
        _transactionTypeMeta,
        transactionType.isAcceptableOrUnknown(
          data['transaction_type']!,
          _transactionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionTypeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('financial_account_id')) {
      context.handle(
        _financialAccountIdMeta,
        financialAccountId.isAcceptableOrUnknown(
          data['financial_account_id']!,
          _financialAccountIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_financialAccountIdMeta);
    }
    if (data.containsKey('counter_account_id')) {
      context.handle(
        _counterAccountIdMeta,
        counterAccountId.isAcceptableOrUnknown(
          data['counter_account_id']!,
          _counterAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('merchant_name')) {
      context.handle(
        _merchantNameMeta,
        merchantName.isAcceptableOrUnknown(
          data['merchant_name']!,
          _merchantNameMeta,
        ),
      );
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
    if (data.containsKey('transacted_at')) {
      context.handle(
        _transactedAtMeta,
        transactedAt.isAcceptableOrUnknown(
          data['transacted_at']!,
          _transactedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      clientRequestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_request_id'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}amount_cents'],
      )!,
      transactionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      financialAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}financial_account_id'],
      )!,
      counterAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counter_account_id'],
      ),
      merchantName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_name'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      transactedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}transacted_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $LocalTransactionsTable createAlias(String alias) {
    return $LocalTransactionsTable(attachedDatabase, alias);
  }
}

class LocalTransaction extends DataClass
    implements Insertable<LocalTransaction> {
  final String id;
  final String clientRequestId;
  final BigInt amountCents;
  final String transactionType;
  final String status;
  final String? categoryId;
  final String financialAccountId;
  final String? counterAccountId;
  final String? merchantName;
  final String? description;
  final DateTime transactedAt;
  final String syncStatus;
  const LocalTransaction({
    required this.id,
    required this.clientRequestId,
    required this.amountCents,
    required this.transactionType,
    required this.status,
    this.categoryId,
    required this.financialAccountId,
    this.counterAccountId,
    this.merchantName,
    this.description,
    required this.transactedAt,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['client_request_id'] = Variable<String>(clientRequestId);
    map['amount_cents'] = Variable<BigInt>(amountCents);
    map['transaction_type'] = Variable<String>(transactionType);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['financial_account_id'] = Variable<String>(financialAccountId);
    if (!nullToAbsent || counterAccountId != null) {
      map['counter_account_id'] = Variable<String>(counterAccountId);
    }
    if (!nullToAbsent || merchantName != null) {
      map['merchant_name'] = Variable<String>(merchantName);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['transacted_at'] = Variable<DateTime>(transactedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  LocalTransactionsCompanion toCompanion(bool nullToAbsent) {
    return LocalTransactionsCompanion(
      id: Value(id),
      clientRequestId: Value(clientRequestId),
      amountCents: Value(amountCents),
      transactionType: Value(transactionType),
      status: Value(status),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      financialAccountId: Value(financialAccountId),
      counterAccountId: counterAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(counterAccountId),
      merchantName: merchantName == null && nullToAbsent
          ? const Value.absent()
          : Value(merchantName),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      transactedAt: Value(transactedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory LocalTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTransaction(
      id: serializer.fromJson<String>(json['id']),
      clientRequestId: serializer.fromJson<String>(json['clientRequestId']),
      amountCents: serializer.fromJson<BigInt>(json['amountCents']),
      transactionType: serializer.fromJson<String>(json['transactionType']),
      status: serializer.fromJson<String>(json['status']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      financialAccountId: serializer.fromJson<String>(
        json['financialAccountId'],
      ),
      counterAccountId: serializer.fromJson<String?>(json['counterAccountId']),
      merchantName: serializer.fromJson<String?>(json['merchantName']),
      description: serializer.fromJson<String?>(json['description']),
      transactedAt: serializer.fromJson<DateTime>(json['transactedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'clientRequestId': serializer.toJson<String>(clientRequestId),
      'amountCents': serializer.toJson<BigInt>(amountCents),
      'transactionType': serializer.toJson<String>(transactionType),
      'status': serializer.toJson<String>(status),
      'categoryId': serializer.toJson<String?>(categoryId),
      'financialAccountId': serializer.toJson<String>(financialAccountId),
      'counterAccountId': serializer.toJson<String?>(counterAccountId),
      'merchantName': serializer.toJson<String?>(merchantName),
      'description': serializer.toJson<String?>(description),
      'transactedAt': serializer.toJson<DateTime>(transactedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  LocalTransaction copyWith({
    String? id,
    String? clientRequestId,
    BigInt? amountCents,
    String? transactionType,
    String? status,
    Value<String?> categoryId = const Value.absent(),
    String? financialAccountId,
    Value<String?> counterAccountId = const Value.absent(),
    Value<String?> merchantName = const Value.absent(),
    Value<String?> description = const Value.absent(),
    DateTime? transactedAt,
    String? syncStatus,
  }) => LocalTransaction(
    id: id ?? this.id,
    clientRequestId: clientRequestId ?? this.clientRequestId,
    amountCents: amountCents ?? this.amountCents,
    transactionType: transactionType ?? this.transactionType,
    status: status ?? this.status,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    financialAccountId: financialAccountId ?? this.financialAccountId,
    counterAccountId: counterAccountId.present
        ? counterAccountId.value
        : this.counterAccountId,
    merchantName: merchantName.present ? merchantName.value : this.merchantName,
    description: description.present ? description.value : this.description,
    transactedAt: transactedAt ?? this.transactedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  LocalTransaction copyWithCompanion(LocalTransactionsCompanion data) {
    return LocalTransaction(
      id: data.id.present ? data.id.value : this.id,
      clientRequestId: data.clientRequestId.present
          ? data.clientRequestId.value
          : this.clientRequestId,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      transactionType: data.transactionType.present
          ? data.transactionType.value
          : this.transactionType,
      status: data.status.present ? data.status.value : this.status,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      financialAccountId: data.financialAccountId.present
          ? data.financialAccountId.value
          : this.financialAccountId,
      counterAccountId: data.counterAccountId.present
          ? data.counterAccountId.value
          : this.counterAccountId,
      merchantName: data.merchantName.present
          ? data.merchantName.value
          : this.merchantName,
      description: data.description.present
          ? data.description.value
          : this.description,
      transactedAt: data.transactedAt.present
          ? data.transactedAt.value
          : this.transactedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransaction(')
          ..write('id: $id, ')
          ..write('clientRequestId: $clientRequestId, ')
          ..write('amountCents: $amountCents, ')
          ..write('transactionType: $transactionType, ')
          ..write('status: $status, ')
          ..write('categoryId: $categoryId, ')
          ..write('financialAccountId: $financialAccountId, ')
          ..write('counterAccountId: $counterAccountId, ')
          ..write('merchantName: $merchantName, ')
          ..write('description: $description, ')
          ..write('transactedAt: $transactedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientRequestId,
    amountCents,
    transactionType,
    status,
    categoryId,
    financialAccountId,
    counterAccountId,
    merchantName,
    description,
    transactedAt,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTransaction &&
          other.id == this.id &&
          other.clientRequestId == this.clientRequestId &&
          other.amountCents == this.amountCents &&
          other.transactionType == this.transactionType &&
          other.status == this.status &&
          other.categoryId == this.categoryId &&
          other.financialAccountId == this.financialAccountId &&
          other.counterAccountId == this.counterAccountId &&
          other.merchantName == this.merchantName &&
          other.description == this.description &&
          other.transactedAt == this.transactedAt &&
          other.syncStatus == this.syncStatus);
}

class LocalTransactionsCompanion extends UpdateCompanion<LocalTransaction> {
  final Value<String> id;
  final Value<String> clientRequestId;
  final Value<BigInt> amountCents;
  final Value<String> transactionType;
  final Value<String> status;
  final Value<String?> categoryId;
  final Value<String> financialAccountId;
  final Value<String?> counterAccountId;
  final Value<String?> merchantName;
  final Value<String?> description;
  final Value<DateTime> transactedAt;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const LocalTransactionsCompanion({
    this.id = const Value.absent(),
    this.clientRequestId = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.transactionType = const Value.absent(),
    this.status = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.financialAccountId = const Value.absent(),
    this.counterAccountId = const Value.absent(),
    this.merchantName = const Value.absent(),
    this.description = const Value.absent(),
    this.transactedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTransactionsCompanion.insert({
    required String id,
    required String clientRequestId,
    required BigInt amountCents,
    required String transactionType,
    required String status,
    this.categoryId = const Value.absent(),
    required String financialAccountId,
    this.counterAccountId = const Value.absent(),
    this.merchantName = const Value.absent(),
    this.description = const Value.absent(),
    required DateTime transactedAt,
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientRequestId = Value(clientRequestId),
       amountCents = Value(amountCents),
       transactionType = Value(transactionType),
       status = Value(status),
       financialAccountId = Value(financialAccountId),
       transactedAt = Value(transactedAt);
  static Insertable<LocalTransaction> custom({
    Expression<String>? id,
    Expression<String>? clientRequestId,
    Expression<BigInt>? amountCents,
    Expression<String>? transactionType,
    Expression<String>? status,
    Expression<String>? categoryId,
    Expression<String>? financialAccountId,
    Expression<String>? counterAccountId,
    Expression<String>? merchantName,
    Expression<String>? description,
    Expression<DateTime>? transactedAt,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientRequestId != null) 'client_request_id': clientRequestId,
      if (amountCents != null) 'amount_cents': amountCents,
      if (transactionType != null) 'transaction_type': transactionType,
      if (status != null) 'status': status,
      if (categoryId != null) 'category_id': categoryId,
      if (financialAccountId != null)
        'financial_account_id': financialAccountId,
      if (counterAccountId != null) 'counter_account_id': counterAccountId,
      if (merchantName != null) 'merchant_name': merchantName,
      if (description != null) 'description': description,
      if (transactedAt != null) 'transacted_at': transactedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? clientRequestId,
    Value<BigInt>? amountCents,
    Value<String>? transactionType,
    Value<String>? status,
    Value<String?>? categoryId,
    Value<String>? financialAccountId,
    Value<String?>? counterAccountId,
    Value<String?>? merchantName,
    Value<String?>? description,
    Value<DateTime>? transactedAt,
    Value<String>? syncStatus,
    Value<int>? rowid,
  }) {
    return LocalTransactionsCompanion(
      id: id ?? this.id,
      clientRequestId: clientRequestId ?? this.clientRequestId,
      amountCents: amountCents ?? this.amountCents,
      transactionType: transactionType ?? this.transactionType,
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      financialAccountId: financialAccountId ?? this.financialAccountId,
      counterAccountId: counterAccountId ?? this.counterAccountId,
      merchantName: merchantName ?? this.merchantName,
      description: description ?? this.description,
      transactedAt: transactedAt ?? this.transactedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clientRequestId.present) {
      map['client_request_id'] = Variable<String>(clientRequestId.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<BigInt>(amountCents.value);
    }
    if (transactionType.present) {
      map['transaction_type'] = Variable<String>(transactionType.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (financialAccountId.present) {
      map['financial_account_id'] = Variable<String>(financialAccountId.value);
    }
    if (counterAccountId.present) {
      map['counter_account_id'] = Variable<String>(counterAccountId.value);
    }
    if (merchantName.present) {
      map['merchant_name'] = Variable<String>(merchantName.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (transactedAt.present) {
      map['transacted_at'] = Variable<DateTime>(transactedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('clientRequestId: $clientRequestId, ')
          ..write('amountCents: $amountCents, ')
          ..write('transactionType: $transactionType, ')
          ..write('status: $status, ')
          ..write('categoryId: $categoryId, ')
          ..write('financialAccountId: $financialAccountId, ')
          ..write('counterAccountId: $counterAccountId, ')
          ..write('merchantName: $merchantName, ')
          ..write('description: $description, ')
          ..write('transactedAt: $transactedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _clientRequestIdMeta = const VerificationMeta(
    'clientRequestId',
  );
  @override
  late final GeneratedColumn<String> clientRequestId = GeneratedColumn<String>(
    'client_request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _endpointMeta = const VerificationMeta(
    'endpoint',
  );
  @override
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
    'endpoint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientRequestId,
    endpoint,
    payload,
    createdAt,
    retryCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_request_id')) {
      context.handle(
        _clientRequestIdMeta,
        clientRequestId.isAcceptableOrUnknown(
          data['client_request_id']!,
          _clientRequestIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientRequestIdMeta);
    }
    if (data.containsKey('endpoint')) {
      context.handle(
        _endpointMeta,
        endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta),
      );
    } else if (isInserting) {
      context.missing(_endpointMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientRequestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_request_id'],
      )!,
      endpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}endpoint'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int id;
  final String clientRequestId;
  final String endpoint;
  final String payload;
  final DateTime createdAt;
  final int retryCount;
  const SyncQueueData({
    required this.id,
    required this.clientRequestId,
    required this.endpoint,
    required this.payload,
    required this.createdAt,
    required this.retryCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_request_id'] = Variable<String>(clientRequestId);
    map['endpoint'] = Variable<String>(endpoint);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      clientRequestId: Value(clientRequestId),
      endpoint: Value(endpoint),
      payload: Value(payload),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
    );
  }

  factory SyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      clientRequestId: serializer.fromJson<String>(json['clientRequestId']),
      endpoint: serializer.fromJson<String>(json['endpoint']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientRequestId': serializer.toJson<String>(clientRequestId),
      'endpoint': serializer.toJson<String>(endpoint),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
    };
  }

  SyncQueueData copyWith({
    int? id,
    String? clientRequestId,
    String? endpoint,
    String? payload,
    DateTime? createdAt,
    int? retryCount,
  }) => SyncQueueData(
    id: id ?? this.id,
    clientRequestId: clientRequestId ?? this.clientRequestId,
    endpoint: endpoint ?? this.endpoint,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
  );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      clientRequestId: data.clientRequestId.present
          ? data.clientRequestId.value
          : this.clientRequestId,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('clientRequestId: $clientRequestId, ')
          ..write('endpoint: $endpoint, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientRequestId,
    endpoint,
    payload,
    createdAt,
    retryCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.clientRequestId == this.clientRequestId &&
          other.endpoint == this.endpoint &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> clientRequestId;
  final Value<String> endpoint;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> retryCount;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.clientRequestId = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String clientRequestId,
    required String endpoint,
    required String payload,
    required DateTime createdAt,
    this.retryCount = const Value.absent(),
  }) : clientRequestId = Value(clientRequestId),
       endpoint = Value(endpoint),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<SyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? clientRequestId,
    Expression<String>? endpoint,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? retryCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientRequestId != null) 'client_request_id': clientRequestId,
      if (endpoint != null) 'endpoint': endpoint,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
    });
  }

  SyncQueueCompanion copyWith({
    Value<int>? id,
    Value<String>? clientRequestId,
    Value<String>? endpoint,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<int>? retryCount,
  }) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      clientRequestId: clientRequestId ?? this.clientRequestId,
      endpoint: endpoint ?? this.endpoint,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientRequestId.present) {
      map['client_request_id'] = Variable<String>(clientRequestId.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('clientRequestId: $clientRequestId, ')
          ..write('endpoint: $endpoint, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }
}

class $UserCategoryMemoryTable extends UserCategoryMemory
    with TableInfo<$UserCategoryMemoryTable, UserCategoryMemoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserCategoryMemoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _merchantKeyMeta = const VerificationMeta(
    'merchantKey',
  );
  @override
  late final GeneratedColumn<String> merchantKey = GeneratedColumn<String>(
    'merchant_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _itemKeyMeta = const VerificationMeta(
    'itemKey',
  );
  @override
  late final GeneratedColumn<String> itemKey = GeneratedColumn<String>(
    'item_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categorySlugMeta = const VerificationMeta(
    'categorySlug',
  );
  @override
  late final GeneratedColumn<String> categorySlug = GeneratedColumn<String>(
    'category_slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmCountMeta = const VerificationMeta(
    'confirmCount',
  );
  @override
  late final GeneratedColumn<int> confirmCount = GeneratedColumn<int>(
    'confirm_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    merchantKey,
    itemKey,
    categorySlug,
    confirmCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_category_memory';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserCategoryMemoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('merchant_key')) {
      context.handle(
        _merchantKeyMeta,
        merchantKey.isAcceptableOrUnknown(
          data['merchant_key']!,
          _merchantKeyMeta,
        ),
      );
    }
    if (data.containsKey('item_key')) {
      context.handle(
        _itemKeyMeta,
        itemKey.isAcceptableOrUnknown(data['item_key']!, _itemKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_itemKeyMeta);
    }
    if (data.containsKey('category_slug')) {
      context.handle(
        _categorySlugMeta,
        categorySlug.isAcceptableOrUnknown(
          data['category_slug']!,
          _categorySlugMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categorySlugMeta);
    }
    if (data.containsKey('confirm_count')) {
      context.handle(
        _confirmCountMeta,
        confirmCount.isAcceptableOrUnknown(
          data['confirm_count']!,
          _confirmCountMeta,
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
  Set<GeneratedColumn> get $primaryKey => {merchantKey, itemKey};
  @override
  UserCategoryMemoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserCategoryMemoryData(
      merchantKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_key'],
      )!,
      itemKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_key'],
      )!,
      categorySlug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_slug'],
      )!,
      confirmCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confirm_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserCategoryMemoryTable createAlias(String alias) {
    return $UserCategoryMemoryTable(attachedDatabase, alias);
  }
}

class UserCategoryMemoryData extends DataClass
    implements Insertable<UserCategoryMemoryData> {
  final String merchantKey;
  final String itemKey;
  final String categorySlug;

  /// Số lần người dùng xác nhận đúng danh mục này liên tiếp; đổi sang danh mục khác thì đếm lại từ 1
  final int confirmCount;
  final DateTime updatedAt;
  const UserCategoryMemoryData({
    required this.merchantKey,
    required this.itemKey,
    required this.categorySlug,
    required this.confirmCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['merchant_key'] = Variable<String>(merchantKey);
    map['item_key'] = Variable<String>(itemKey);
    map['category_slug'] = Variable<String>(categorySlug);
    map['confirm_count'] = Variable<int>(confirmCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserCategoryMemoryCompanion toCompanion(bool nullToAbsent) {
    return UserCategoryMemoryCompanion(
      merchantKey: Value(merchantKey),
      itemKey: Value(itemKey),
      categorySlug: Value(categorySlug),
      confirmCount: Value(confirmCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserCategoryMemoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserCategoryMemoryData(
      merchantKey: serializer.fromJson<String>(json['merchantKey']),
      itemKey: serializer.fromJson<String>(json['itemKey']),
      categorySlug: serializer.fromJson<String>(json['categorySlug']),
      confirmCount: serializer.fromJson<int>(json['confirmCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'merchantKey': serializer.toJson<String>(merchantKey),
      'itemKey': serializer.toJson<String>(itemKey),
      'categorySlug': serializer.toJson<String>(categorySlug),
      'confirmCount': serializer.toJson<int>(confirmCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserCategoryMemoryData copyWith({
    String? merchantKey,
    String? itemKey,
    String? categorySlug,
    int? confirmCount,
    DateTime? updatedAt,
  }) => UserCategoryMemoryData(
    merchantKey: merchantKey ?? this.merchantKey,
    itemKey: itemKey ?? this.itemKey,
    categorySlug: categorySlug ?? this.categorySlug,
    confirmCount: confirmCount ?? this.confirmCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserCategoryMemoryData copyWithCompanion(UserCategoryMemoryCompanion data) {
    return UserCategoryMemoryData(
      merchantKey: data.merchantKey.present
          ? data.merchantKey.value
          : this.merchantKey,
      itemKey: data.itemKey.present ? data.itemKey.value : this.itemKey,
      categorySlug: data.categorySlug.present
          ? data.categorySlug.value
          : this.categorySlug,
      confirmCount: data.confirmCount.present
          ? data.confirmCount.value
          : this.confirmCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserCategoryMemoryData(')
          ..write('merchantKey: $merchantKey, ')
          ..write('itemKey: $itemKey, ')
          ..write('categorySlug: $categorySlug, ')
          ..write('confirmCount: $confirmCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(merchantKey, itemKey, categorySlug, confirmCount, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserCategoryMemoryData &&
          other.merchantKey == this.merchantKey &&
          other.itemKey == this.itemKey &&
          other.categorySlug == this.categorySlug &&
          other.confirmCount == this.confirmCount &&
          other.updatedAt == this.updatedAt);
}

class UserCategoryMemoryCompanion
    extends UpdateCompanion<UserCategoryMemoryData> {
  final Value<String> merchantKey;
  final Value<String> itemKey;
  final Value<String> categorySlug;
  final Value<int> confirmCount;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserCategoryMemoryCompanion({
    this.merchantKey = const Value.absent(),
    this.itemKey = const Value.absent(),
    this.categorySlug = const Value.absent(),
    this.confirmCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserCategoryMemoryCompanion.insert({
    this.merchantKey = const Value.absent(),
    required String itemKey,
    required String categorySlug,
    this.confirmCount = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : itemKey = Value(itemKey),
       categorySlug = Value(categorySlug),
       updatedAt = Value(updatedAt);
  static Insertable<UserCategoryMemoryData> custom({
    Expression<String>? merchantKey,
    Expression<String>? itemKey,
    Expression<String>? categorySlug,
    Expression<int>? confirmCount,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (merchantKey != null) 'merchant_key': merchantKey,
      if (itemKey != null) 'item_key': itemKey,
      if (categorySlug != null) 'category_slug': categorySlug,
      if (confirmCount != null) 'confirm_count': confirmCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserCategoryMemoryCompanion copyWith({
    Value<String>? merchantKey,
    Value<String>? itemKey,
    Value<String>? categorySlug,
    Value<int>? confirmCount,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserCategoryMemoryCompanion(
      merchantKey: merchantKey ?? this.merchantKey,
      itemKey: itemKey ?? this.itemKey,
      categorySlug: categorySlug ?? this.categorySlug,
      confirmCount: confirmCount ?? this.confirmCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (merchantKey.present) {
      map['merchant_key'] = Variable<String>(merchantKey.value);
    }
    if (itemKey.present) {
      map['item_key'] = Variable<String>(itemKey.value);
    }
    if (categorySlug.present) {
      map['category_slug'] = Variable<String>(categorySlug.value);
    }
    if (confirmCount.present) {
      map['confirm_count'] = Variable<int>(confirmCount.value);
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
    return (StringBuffer('UserCategoryMemoryCompanion(')
          ..write('merchantKey: $merchantKey, ')
          ..write('itemKey: $itemKey, ')
          ..write('categorySlug: $categorySlug, ')
          ..write('confirmCount: $confirmCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingMessagesTable extends PendingMessages
    with TableInfo<$PendingMessagesTable, PendingMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
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
  List<GeneratedColumn> get $columns => [id, kind, content, source, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
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
  PendingMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingMessagesTable createAlias(String alias) {
    return $PendingMessagesTable(attachedDatabase, alias);
  }
}

class PendingMessage extends DataClass implements Insertable<PendingMessage> {
  /// Cũng là mã chống trùng gửi cho server, dùng lại ở mỗi lần thử nên server không ghi hai lần
  final String id;
  final String kind;
  final String content;
  final String source;
  final DateTime createdAt;
  const PendingMessage({
    required this.id,
    required this.kind,
    required this.content,
    required this.source,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['content'] = Variable<String>(content);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingMessagesCompanion toCompanion(bool nullToAbsent) {
    return PendingMessagesCompanion(
      id: Value(id),
      kind: Value(kind),
      content: Value(content),
      source: Value(source),
      createdAt: Value(createdAt),
    );
  }

  factory PendingMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingMessage(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      content: serializer.fromJson<String>(json['content']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'content': serializer.toJson<String>(content),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingMessage copyWith({
    String? id,
    String? kind,
    String? content,
    String? source,
    DateTime? createdAt,
  }) => PendingMessage(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    content: content ?? this.content,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingMessage copyWithCompanion(PendingMessagesCompanion data) {
    return PendingMessage(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      content: data.content.present ? data.content.value : this.content,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingMessage(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, content, source, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingMessage &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.content == this.content &&
          other.source == this.source &&
          other.createdAt == this.createdAt);
}

class PendingMessagesCompanion extends UpdateCompanion<PendingMessage> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> content;
  final Value<String> source;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PendingMessagesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.content = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingMessagesCompanion.insert({
    required String id,
    required String kind,
    required String content,
    required String source,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       content = Value(content),
       source = Value(source),
       createdAt = Value(createdAt);
  static Insertable<PendingMessage> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? content,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (content != null) 'content': content,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? content,
    Value<String>? source,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PendingMessagesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingMessagesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalTransactionsTable localTransactions =
      $LocalTransactionsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $UserCategoryMemoryTable userCategoryMemory =
      $UserCategoryMemoryTable(this);
  late final $PendingMessagesTable pendingMessages = $PendingMessagesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localTransactions,
    syncQueue,
    userCategoryMemory,
    pendingMessages,
  ];
}

typedef $$LocalTransactionsTableCreateCompanionBuilder =
    LocalTransactionsCompanion Function({
      required String id,
      required String clientRequestId,
      required BigInt amountCents,
      required String transactionType,
      required String status,
      Value<String?> categoryId,
      required String financialAccountId,
      Value<String?> counterAccountId,
      Value<String?> merchantName,
      Value<String?> description,
      required DateTime transactedAt,
      Value<String> syncStatus,
      Value<int> rowid,
    });
typedef $$LocalTransactionsTableUpdateCompanionBuilder =
    LocalTransactionsCompanion Function({
      Value<String> id,
      Value<String> clientRequestId,
      Value<BigInt> amountCents,
      Value<String> transactionType,
      Value<String> status,
      Value<String?> categoryId,
      Value<String> financialAccountId,
      Value<String?> counterAccountId,
      Value<String?> merchantName,
      Value<String?> description,
      Value<DateTime> transactedAt,
      Value<String> syncStatus,
      Value<int> rowid,
    });

class $$LocalTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientRequestId => $composableBuilder(
    column: $table.clientRequestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get financialAccountId => $composableBuilder(
    column: $table.financialAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterAccountId => $composableBuilder(
    column: $table.counterAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get transactedAt => $composableBuilder(
    column: $table.transactedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientRequestId => $composableBuilder(
    column: $table.clientRequestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get financialAccountId => $composableBuilder(
    column: $table.financialAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterAccountId => $composableBuilder(
    column: $table.counterAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get transactedAt => $composableBuilder(
    column: $table.transactedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientRequestId => $composableBuilder(
    column: $table.clientRequestId,
    builder: (column) => column,
  );

  GeneratedColumn<BigInt> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transactionType => $composableBuilder(
    column: $table.transactionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get financialAccountId => $composableBuilder(
    column: $table.financialAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get counterAccountId => $composableBuilder(
    column: $table.counterAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get merchantName => $composableBuilder(
    column: $table.merchantName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get transactedAt => $composableBuilder(
    column: $table.transactedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$LocalTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTransactionsTable,
          LocalTransaction,
          $$LocalTransactionsTableFilterComposer,
          $$LocalTransactionsTableOrderingComposer,
          $$LocalTransactionsTableAnnotationComposer,
          $$LocalTransactionsTableCreateCompanionBuilder,
          $$LocalTransactionsTableUpdateCompanionBuilder,
          (
            LocalTransaction,
            BaseReferences<
              _$AppDatabase,
              $LocalTransactionsTable,
              LocalTransaction
            >,
          ),
          LocalTransaction,
          PrefetchHooks Function()
        > {
  $$LocalTransactionsTableTableManager(
    _$AppDatabase db,
    $LocalTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> clientRequestId = const Value.absent(),
                Value<BigInt> amountCents = const Value.absent(),
                Value<String> transactionType = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String> financialAccountId = const Value.absent(),
                Value<String?> counterAccountId = const Value.absent(),
                Value<String?> merchantName = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> transactedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTransactionsCompanion(
                id: id,
                clientRequestId: clientRequestId,
                amountCents: amountCents,
                transactionType: transactionType,
                status: status,
                categoryId: categoryId,
                financialAccountId: financialAccountId,
                counterAccountId: counterAccountId,
                merchantName: merchantName,
                description: description,
                transactedAt: transactedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String clientRequestId,
                required BigInt amountCents,
                required String transactionType,
                required String status,
                Value<String?> categoryId = const Value.absent(),
                required String financialAccountId,
                Value<String?> counterAccountId = const Value.absent(),
                Value<String?> merchantName = const Value.absent(),
                Value<String?> description = const Value.absent(),
                required DateTime transactedAt,
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTransactionsCompanion.insert(
                id: id,
                clientRequestId: clientRequestId,
                amountCents: amountCents,
                transactionType: transactionType,
                status: status,
                categoryId: categoryId,
                financialAccountId: financialAccountId,
                counterAccountId: counterAccountId,
                merchantName: merchantName,
                description: description,
                transactedAt: transactedAt,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalTransactionsTable, LocalTransaction>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalTransactionsTable,
                    LocalTransaction
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTransactionsTable,
      LocalTransaction,
      $$LocalTransactionsTableFilterComposer,
      $$LocalTransactionsTableOrderingComposer,
      $$LocalTransactionsTableAnnotationComposer,
      $$LocalTransactionsTableCreateCompanionBuilder,
      $$LocalTransactionsTableUpdateCompanionBuilder,
      (
        LocalTransaction,
        BaseReferences<
          _$AppDatabase,
          $LocalTransactionsTable,
          LocalTransaction
        >,
      ),
      LocalTransaction,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      required String clientRequestId,
      required String endpoint,
      required String payload,
      required DateTime createdAt,
      Value<int> retryCount,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<int> id,
      Value<String> clientRequestId,
      Value<String> endpoint,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<int> retryCount,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
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

  ColumnFilters<String> get clientRequestId => $composableBuilder(
    column: $table.clientRequestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
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

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
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

  ColumnOrderings<String> get clientRequestId => $composableBuilder(
    column: $table.clientRequestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
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

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientRequestId => $composableBuilder(
    column: $table.clientRequestId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endpoint =>
      $composableBuilder(column: $table.endpoint, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueData,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientRequestId = const Value.absent(),
                Value<String> endpoint = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
              }) => SyncQueueCompanion(
                id: id,
                clientRequestId: clientRequestId,
                endpoint: endpoint,
                payload: payload,
                createdAt: createdAt,
                retryCount: retryCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientRequestId,
                required String endpoint,
                required String payload,
                required DateTime createdAt,
                Value<int> retryCount = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                id: id,
                clientRequestId: clientRequestId,
                endpoint: endpoint,
                payload: payload,
                createdAt: createdAt,
                retryCount: retryCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncQueueTable, SyncQueueData>(table),
                  BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueData,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueData,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
      ),
      SyncQueueData,
      PrefetchHooks Function()
    >;
typedef $$UserCategoryMemoryTableCreateCompanionBuilder =
    UserCategoryMemoryCompanion Function({
      Value<String> merchantKey,
      required String itemKey,
      required String categorySlug,
      Value<int> confirmCount,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$UserCategoryMemoryTableUpdateCompanionBuilder =
    UserCategoryMemoryCompanion Function({
      Value<String> merchantKey,
      Value<String> itemKey,
      Value<String> categorySlug,
      Value<int> confirmCount,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UserCategoryMemoryTableFilterComposer
    extends Composer<_$AppDatabase, $UserCategoryMemoryTable> {
  $$UserCategoryMemoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get merchantKey => $composableBuilder(
    column: $table.merchantKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categorySlug => $composableBuilder(
    column: $table.categorySlug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confirmCount => $composableBuilder(
    column: $table.confirmCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserCategoryMemoryTableOrderingComposer
    extends Composer<_$AppDatabase, $UserCategoryMemoryTable> {
  $$UserCategoryMemoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get merchantKey => $composableBuilder(
    column: $table.merchantKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categorySlug => $composableBuilder(
    column: $table.categorySlug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confirmCount => $composableBuilder(
    column: $table.confirmCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserCategoryMemoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserCategoryMemoryTable> {
  $$UserCategoryMemoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get merchantKey => $composableBuilder(
    column: $table.merchantKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemKey =>
      $composableBuilder(column: $table.itemKey, builder: (column) => column);

  GeneratedColumn<String> get categorySlug => $composableBuilder(
    column: $table.categorySlug,
    builder: (column) => column,
  );

  GeneratedColumn<int> get confirmCount => $composableBuilder(
    column: $table.confirmCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserCategoryMemoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserCategoryMemoryTable,
          UserCategoryMemoryData,
          $$UserCategoryMemoryTableFilterComposer,
          $$UserCategoryMemoryTableOrderingComposer,
          $$UserCategoryMemoryTableAnnotationComposer,
          $$UserCategoryMemoryTableCreateCompanionBuilder,
          $$UserCategoryMemoryTableUpdateCompanionBuilder,
          (
            UserCategoryMemoryData,
            BaseReferences<
              _$AppDatabase,
              $UserCategoryMemoryTable,
              UserCategoryMemoryData
            >,
          ),
          UserCategoryMemoryData,
          PrefetchHooks Function()
        > {
  $$UserCategoryMemoryTableTableManager(
    _$AppDatabase db,
    $UserCategoryMemoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserCategoryMemoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserCategoryMemoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserCategoryMemoryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> merchantKey = const Value.absent(),
                Value<String> itemKey = const Value.absent(),
                Value<String> categorySlug = const Value.absent(),
                Value<int> confirmCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserCategoryMemoryCompanion(
                merchantKey: merchantKey,
                itemKey: itemKey,
                categorySlug: categorySlug,
                confirmCount: confirmCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> merchantKey = const Value.absent(),
                required String itemKey,
                required String categorySlug,
                Value<int> confirmCount = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserCategoryMemoryCompanion.insert(
                merchantKey: merchantKey,
                itemKey: itemKey,
                categorySlug: categorySlug,
                confirmCount: confirmCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserCategoryMemoryTable, UserCategoryMemoryData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $UserCategoryMemoryTable,
                    UserCategoryMemoryData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserCategoryMemoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserCategoryMemoryTable,
      UserCategoryMemoryData,
      $$UserCategoryMemoryTableFilterComposer,
      $$UserCategoryMemoryTableOrderingComposer,
      $$UserCategoryMemoryTableAnnotationComposer,
      $$UserCategoryMemoryTableCreateCompanionBuilder,
      $$UserCategoryMemoryTableUpdateCompanionBuilder,
      (
        UserCategoryMemoryData,
        BaseReferences<
          _$AppDatabase,
          $UserCategoryMemoryTable,
          UserCategoryMemoryData
        >,
      ),
      UserCategoryMemoryData,
      PrefetchHooks Function()
    >;
typedef $$PendingMessagesTableCreateCompanionBuilder =
    PendingMessagesCompanion Function({
      required String id,
      required String kind,
      required String content,
      required String source,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PendingMessagesTableUpdateCompanionBuilder =
    PendingMessagesCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> content,
      Value<String> source,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PendingMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $PendingMessagesTable> {
  $$PendingMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingMessagesTable> {
  $$PendingMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingMessagesTable> {
  $$PendingMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingMessagesTable,
          PendingMessage,
          $$PendingMessagesTableFilterComposer,
          $$PendingMessagesTableOrderingComposer,
          $$PendingMessagesTableAnnotationComposer,
          $$PendingMessagesTableCreateCompanionBuilder,
          $$PendingMessagesTableUpdateCompanionBuilder,
          (
            PendingMessage,
            BaseReferences<
              _$AppDatabase,
              $PendingMessagesTable,
              PendingMessage
            >,
          ),
          PendingMessage,
          PrefetchHooks Function()
        > {
  $$PendingMessagesTableTableManager(
    _$AppDatabase db,
    $PendingMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingMessagesCompanion(
                id: id,
                kind: kind,
                content: content,
                source: source,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String content,
                required String source,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingMessagesCompanion.insert(
                id: id,
                kind: kind,
                content: content,
                source: source,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingMessagesTable, PendingMessage>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingMessagesTable,
                    PendingMessage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingMessagesTable,
      PendingMessage,
      $$PendingMessagesTableFilterComposer,
      $$PendingMessagesTableOrderingComposer,
      $$PendingMessagesTableAnnotationComposer,
      $$PendingMessagesTableCreateCompanionBuilder,
      $$PendingMessagesTableUpdateCompanionBuilder,
      (
        PendingMessage,
        BaseReferences<_$AppDatabase, $PendingMessagesTable, PendingMessage>,
      ),
      PendingMessage,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalTransactionsTableTableManager get localTransactions =>
      $$LocalTransactionsTableTableManager(_db, _db.localTransactions);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$UserCategoryMemoryTableTableManager get userCategoryMemory =>
      $$UserCategoryMemoryTableTableManager(_db, _db.userCategoryMemory);
  $$PendingMessagesTableTableManager get pendingMessages =>
      $$PendingMessagesTableTableManager(_db, _db.pendingMessages);
}
