/// Data models for AquaBill mobile app.
///
/// Mirrors backend models with JSON serialization support.

import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

// ============ Client ============

@JsonSerializable()
class ClientModel {
  final int id;
  final String? clientCode;
  final String firstName;
  final String? otherNames;
  final String surname;
  final String phoneNumber;
  final DateTime updatedAt;

  ClientModel({
    required this.id,
    this.clientCode,
    required this.firstName,
    this.otherNames,
    required this.surname,
    required this.phoneNumber,
    required this.updatedAt,
  });

  String get fullName => '$firstName ${otherNames ?? ''} $surname'.trim();

  factory ClientModel.fromJson(Map<String, dynamic> json) =>
      _$ClientModelFromJson(json);
  Map<String, dynamic> toJson() => _$ClientModelToJson(this);

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'client_code': clientCode,
        'first_name': firstName,
        'other_names': otherNames,
        'surname': surname,
        'phone_number': phoneNumber,
        'updated_at': updatedAt.toIso8601String(),
      };

  static ClientModel fromLocalMap(Map<String, dynamic> map) => ClientModel(
        id: map['id'] as int,
        clientCode: map['client_code'] as String?,
        firstName: map['first_name'] as String,
        otherNames: map['other_names'] as String?,
        surname: map['surname'] as String,
        phoneNumber: map['phone_number'] as String,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ============ Meter ============

@JsonSerializable()
class MeterModel {
  final int id;
  final String serialNumber;
  final DateTime updatedAt;

  MeterModel({
    required this.id,
    required this.serialNumber,
    required this.updatedAt,
  });

  factory MeterModel.fromJson(Map<String, dynamic> json) =>
      _$MeterModelFromJson(json);
  Map<String, dynamic> toJson() => _$MeterModelToJson(this);

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'serial_number': serialNumber,
        'updated_at': updatedAt.toIso8601String(),
      };

  static MeterModel fromLocalMap(Map<String, dynamic> map) => MeterModel(
        id: map['id'] as int,
        serialNumber: map['serial_number'] as String,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ============ MeterAssignment ============

@JsonSerializable()
class MeterAssignmentModel {
  final int id;
  final int meterId;
  final int clientId;
  final String status; // ACTIVE, INACTIVE
  final DateTime startDate;
  final DateTime? endDate;
  final double? maxMeterValue;
  final DateTime updatedAt;

  MeterAssignmentModel({
    required this.id,
    required this.meterId,
    required this.clientId,
    required this.status,
    required this.startDate,
    this.endDate,
    this.maxMeterValue,
    required this.updatedAt,
  });

  bool get isActive => status == 'ACTIVE';

  factory MeterAssignmentModel.fromJson(Map<String, dynamic> json) =>
      _$MeterAssignmentModelFromJson(json);
  Map<String, dynamic> toJson() => _$MeterAssignmentModelToJson(this);

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'meter_id': meterId,
        'client_id': clientId,
        'status': status,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'max_meter_value': maxMeterValue,
        'updated_at': updatedAt.toIso8601String(),
      };

  static MeterAssignmentModel fromLocalMap(Map<String, dynamic> map) =>
      MeterAssignmentModel(
        id: map['id'] as int,
        meterId: map['meter_id'] as int,
        clientId: map['client_id'] as int,
        status: map['status'] as String,
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: map['end_date'] != null
            ? DateTime.parse(map['end_date'] as String)
            : null,
        maxMeterValue: (map['max_meter_value'] as num?)?.toDouble(),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ============ Cycle ============

@JsonSerializable()
class CycleModel {
  final int id;
  final String? name;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime targetDate;
  final String status; // OPEN, PENDING_REVIEW, APPROVED, CLOSED, ARCHIVED
  final DateTime updatedAt;

  CycleModel({
    required this.id,
    this.name,
    required this.startDate,
    required this.endDate,
    required this.targetDate,
    required this.status,
    required this.updatedAt,
  });

  bool get isOpen => status == 'OPEN';
  bool get isApproved => status == 'APPROVED';
  bool get isClosed => status == 'CLOSED';

  factory CycleModel.fromJson(Map<String, dynamic> json) =>
      _$CycleModelFromJson(json);
  Map<String, dynamic> toJson() => _$CycleModelToJson(this);

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'name': name,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'target_date': targetDate.toIso8601String(),
        'status': status,
        'updated_at': updatedAt.toIso8601String(),
      };

  static CycleModel fromLocalMap(Map<String, dynamic> map) => CycleModel(
        id: map['id'] as int,
        name: map['name'] as String?,
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: DateTime.parse(map['end_date'] as String),
        targetDate: DateTime.parse(map['target_date'] as String),
        status: map['status'] as String,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ============ Reading ============

@JsonSerializable()
class ReadingModel {
  final int id;
  final int meterAssignmentId;
  final int cycleId;
  final double absoluteValue;
  final DateTime submittedAt;
  final String submittedBy;
  final String status; // LOCAL_ONLY, SUBMITTED, ACCEPTED, REJECTED, CONFLICT
  final String source; // LOCAL_CAPTURE, SERVER_SYNC
  final double? previousApprovedReading;
  final String? notes;
  final DateTime updatedAt;

  ReadingModel({
    required this.id,
    required this.meterAssignmentId,
    required this.cycleId,
    required this.absoluteValue,
    required this.submittedAt,
    required this.submittedBy,
    required this.status,
    required this.source,
    this.previousApprovedReading,
    this.notes,
    required this.updatedAt,
  });

  bool get isLocalOnly => status == 'LOCAL_ONLY';
  bool get isConflict => status == 'CONFLICT';
  bool get isAccepted => status == 'ACCEPTED';

  factory ReadingModel.fromJson(Map<String, dynamic> json) =>
      _$ReadingModelFromJson(json);
  Map<String, dynamic> toJson() => _$ReadingModelToJson(this);

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'meter_assignment_id': meterAssignmentId,
        'cycle_id': cycleId,
        'absolute_value': absoluteValue,
        'submitted_at': submittedAt.toIso8601String(),
        'submitted_by': submittedBy,
        'status': status,
        'source': source,
        'previous_approved_reading': previousApprovedReading,
        'notes': notes,
        'updated_at': updatedAt.toIso8601String(),
      };

  static ReadingModel fromLocalMap(Map<String, dynamic> map) => ReadingModel(
        id: map['id'] as int,
        meterAssignmentId: map['meter_assignment_id'] as int,
        cycleId: map['cycle_id'] as int,
        absoluteValue: (map['absolute_value'] as num).toDouble(),
        submittedAt: DateTime.parse(map['submitted_at'] as String),
        submittedBy: map['submitted_by'] as String,
        status: map['status'] as String,
        source: map['source'] as String,
        previousApprovedReading:
            (map['previous_approved_reading'] as num?)?.toDouble(),
        notes: map['notes'] as String?,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ============ Conflict ============

@JsonSerializable()
class ConflictModel {
  final int id;
  final int meterAssignmentId;
  final int cycleId;
  final double localValue;
  final double serverValue;
  final bool resolved;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final DateTime updatedAt;

  ConflictModel({
    required this.id,
    required this.meterAssignmentId,
    required this.cycleId,
    required this.localValue,
    required this.serverValue,
    required this.resolved,
    this.resolvedAt,
    this.resolutionNote,
    required this.updatedAt,
  });

  factory ConflictModel.fromJson(Map<String, dynamic> json) =>
      _$ConflictModelFromJson(json);
  Map<String, dynamic> toJson() => _$ConflictModelToJson(this);

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'meter_assignment_id': meterAssignmentId,
        'cycle_id': cycleId,
        'local_value': localValue,
        'server_value': serverValue,
        'resolved': resolved ? 1 : 0,
        'resolved_at': resolvedAt?.toIso8601String(),
        'resolution_note': resolutionNote,
        'updated_at': updatedAt.toIso8601String(),
      };

  static ConflictModel fromLocalMap(Map<String, dynamic> map) => ConflictModel(
        id: map['id'] as int,
        meterAssignmentId: map['meter_assignment_id'] as int,
        cycleId: map['cycle_id'] as int,
        localValue: (map['local_value'] as num).toDouble(),
        serverValue: (map['server_value'] as num).toDouble(),
        resolved: map['resolved'] is bool
            ? map['resolved'] as bool
            : (map['resolved'] as int) == 1,
        resolvedAt: map['resolved_at'] != null
            ? DateTime.parse(map['resolved_at'] as String)
            : null,
        resolutionNote: map['resolution_note'] as String?,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

// ============ SyncQueue ============

@JsonSerializable()
class SyncQueueItemModel {
  final int? id;
  final String entityType; // READING
  final int? entityId;
  final String payload; // JSON string
  final String operation; // CREATE
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final DateTime createdAt;

  SyncQueueItemModel({
    this.id,
    required this.entityType,
    this.entityId,
    required this.payload,
    required this.operation,
    this.attemptCount = 0,
    this.lastAttemptAt,
    required this.createdAt,
  });

  factory SyncQueueItemModel.fromJson(Map<String, dynamic> json) =>
      _$SyncQueueItemModelFromJson(json);
  Map<String, dynamic> toJson() => _$SyncQueueItemModelToJson(this);

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'payload': payload,
        'operation': operation,
        'attempt_count': attemptCount,
        'last_attempt_at': lastAttemptAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  static SyncQueueItemModel fromLocalMap(Map<String, dynamic> map) =>
      SyncQueueItemModel(
        id: map['id'] as int?,
        entityType: map['entity_type'] as String,
        entityId: map['entity_id'] as int?,
        payload: map['payload'] as String,
        operation: map['operation'] as String,
        attemptCount: (map['attempt_count'] as num?)?.toInt() ?? 0,
        lastAttemptAt: map['last_attempt_at'] != null
            ? DateTime.parse(map['last_attempt_at'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
