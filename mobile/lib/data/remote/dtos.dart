import '../models/models.dart';

class TombstoneModel {
  final String entityType; // cycle, assignment, etc.
  final int entityId;
  final String action; // CLOSED, ARCHIVED, DEACTIVATED
  final DateTime timestamp;

  TombstoneModel({
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.timestamp,
  });

  factory TombstoneModel.fromJson(Map<String, dynamic> json) => TombstoneModel(
        entityType: json['entity_type'] as String,
        entityId: json['entity_id'] as int,
        action: json['action'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class BootstrapPayload {
  final List<ClientModel> clients;
  final List<MeterModel> meters;
  final List<MeterAssignmentModel> assignments;
  final List<CycleModel> cycles;
  final List<ReadingModel> readings;
  final DateTime lastSync;

  BootstrapPayload({
    required this.clients,
    required this.meters,
    required this.assignments,
    required this.cycles,
    required this.readings,
    required this.lastSync,
  });
}

class UpdatesPayload {
  final List<ClientModel> clients;
  final List<MeterModel> meters;
  final List<MeterAssignmentModel> assignments;
  final List<CycleModel> cycles;
  final List<ReadingModel> readings;
  final List<TombstoneModel> tombstones;
  final DateTime lastSync;

  UpdatesPayload({
    required this.clients,
    required this.meters,
    required this.assignments,
    required this.cycles,
    required this.readings,
    required this.tombstones,
    required this.lastSync,
  });
}

class SubmitReadingResult {
  final int id;
  final String status;
  final String? message;

  SubmitReadingResult({
    required this.id,
    required this.status,
    this.message,
  });

  factory SubmitReadingResult.fromJson(Map<String, dynamic> json) =>
      SubmitReadingResult(
        id: json['id'] as int,
        status: json['status'] as String,
        message: json['message'] as String?,
      );
}
