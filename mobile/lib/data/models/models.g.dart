// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClientModel _$ClientModelFromJson(Map<String, dynamic> json) => ClientModel(
      id: (json['id'] as num).toInt(),
      clientCode: json['clientCode'] as String?,
      firstName: json['firstName'] as String,
      otherNames: json['otherNames'] as String?,
      surname: json['surname'] as String,
      phoneNumber: json['phoneNumber'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ClientModelToJson(ClientModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'clientCode': instance.clientCode,
      'firstName': instance.firstName,
      'otherNames': instance.otherNames,
      'surname': instance.surname,
      'phoneNumber': instance.phoneNumber,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

MeterModel _$MeterModelFromJson(Map<String, dynamic> json) => MeterModel(
      id: (json['id'] as num).toInt(),
      serialNumber: json['serialNumber'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$MeterModelToJson(MeterModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'serialNumber': instance.serialNumber,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

MeterAssignmentModel _$MeterAssignmentModelFromJson(
        Map<String, dynamic> json) =>
    MeterAssignmentModel(
      id: (json['id'] as num).toInt(),
      meterId: (json['meterId'] as num).toInt(),
      clientId: (json['clientId'] as num).toInt(),
      status: json['status'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      maxMeterValue: (json['maxMeterValue'] as num?)?.toDouble(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$MeterAssignmentModelToJson(
        MeterAssignmentModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'meterId': instance.meterId,
      'clientId': instance.clientId,
      'status': instance.status,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'maxMeterValue': instance.maxMeterValue,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

CycleModel _$CycleModelFromJson(Map<String, dynamic> json) => CycleModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      targetDate: DateTime.parse(json['targetDate'] as String),
      status: json['status'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$CycleModelToJson(CycleModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'targetDate': instance.targetDate.toIso8601String(),
      'status': instance.status,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

ReadingModel _$ReadingModelFromJson(Map<String, dynamic> json) => ReadingModel(
      id: (json['id'] as num).toInt(),
      meterAssignmentId: (json['meterAssignmentId'] as num).toInt(),
      cycleId: (json['cycleId'] as num).toInt(),
      absoluteValue: (json['absoluteValue'] as num).toDouble(),
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      submittedBy: json['submittedBy'] as String,
      status: json['status'] as String,
      source: json['source'] as String,
      previousApprovedReading:
          (json['previousApprovedReading'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ReadingModelToJson(ReadingModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'meterAssignmentId': instance.meterAssignmentId,
      'cycleId': instance.cycleId,
      'absoluteValue': instance.absoluteValue,
      'submittedAt': instance.submittedAt.toIso8601String(),
      'submittedBy': instance.submittedBy,
      'status': instance.status,
      'source': instance.source,
      'previousApprovedReading': instance.previousApprovedReading,
      'notes': instance.notes,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

ConflictModel _$ConflictModelFromJson(Map<String, dynamic> json) =>
    ConflictModel(
      id: (json['id'] as num).toInt(),
      meterAssignmentId: (json['meterAssignmentId'] as num).toInt(),
      cycleId: (json['cycleId'] as num).toInt(),
      localValue: (json['localValue'] as num).toDouble(),
      serverValue: (json['serverValue'] as num).toDouble(),
      resolved: json['resolved'] as bool,
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.parse(json['resolvedAt'] as String),
      resolutionNote: json['resolutionNote'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ConflictModelToJson(ConflictModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'meterAssignmentId': instance.meterAssignmentId,
      'cycleId': instance.cycleId,
      'localValue': instance.localValue,
      'serverValue': instance.serverValue,
      'resolved': instance.resolved,
      'resolvedAt': instance.resolvedAt?.toIso8601String(),
      'resolutionNote': instance.resolutionNote,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

SyncQueueItemModel _$SyncQueueItemModelFromJson(Map<String, dynamic> json) =>
    SyncQueueItemModel(
      id: (json['id'] as num?)?.toInt(),
      entityType: json['entityType'] as String,
      entityId: (json['entityId'] as num?)?.toInt(),
      payload: json['payload'] as String,
      operation: json['operation'] as String,
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      lastAttemptAt: json['lastAttemptAt'] == null
          ? null
          : DateTime.parse(json['lastAttemptAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$SyncQueueItemModelToJson(SyncQueueItemModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'entityType': instance.entityType,
      'entityId': instance.entityId,
      'payload': instance.payload,
      'operation': instance.operation,
      'attemptCount': instance.attemptCount,
      'lastAttemptAt': instance.lastAttemptAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };
