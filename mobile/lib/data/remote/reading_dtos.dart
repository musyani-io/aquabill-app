/// Data transfer objects for Reading API
class ReadingResponse {
  final int id;
  final int meterAssignmentId;
  final int cycleId;
  final double absoluteValue;
  final String type; // 'BASELINE' or 'NORMAL'
  final double? consumption;
  final bool hasRollover;
  final bool approved;
  final String submittedBy;
  final String? submissionNotes;
  final DateTime submittedAt;
  final String? approvedBy;
  final String? approvalNotes;
  final DateTime? approvedAt;

  ReadingResponse({
    required this.id,
    required this.meterAssignmentId,
    required this.cycleId,
    required this.absoluteValue,
    required this.type,
    this.consumption,
    required this.hasRollover,
    required this.approved,
    required this.submittedBy,
    this.submissionNotes,
    required this.submittedAt,
    this.approvedBy,
    this.approvalNotes,
    this.approvedAt,
  });

  factory ReadingResponse.fromJson(Map<String, dynamic> json) {
    return ReadingResponse(
      id: json['id'],
      meterAssignmentId: json['meter_assignment_id'],
      cycleId: json['cycle_id'],
      absoluteValue: (json['absolute_value'] as num).toDouble(),
      type: json['type'],
      consumption: json['consumption'] != null
          ? (json['consumption'] as num).toDouble()
          : null,
      hasRollover: json['has_rollover'] ?? false,
      approved: json['approved'] ?? false,
      submittedBy: json['submitted_by'],
      submissionNotes: json['submission_notes'],
      submittedAt: DateTime.parse(json['submitted_at']),
      approvedBy: json['approved_by'],
      approvalNotes: json['approval_notes'],
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'])
          : null,
    );
  }
}

class ApproveReadingRequest {
  final String approvedBy;
  final String? approvalNotes;
  final double? adminConsumptionOverride;

  ApproveReadingRequest({
    required this.approvedBy,
    this.approvalNotes,
    this.adminConsumptionOverride,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, String>{'approved_by': approvedBy};

    if (approvalNotes != null && approvalNotes!.isNotEmpty) {
      params['approval_notes'] = approvalNotes!;
    }

    if (adminConsumptionOverride != null) {
      params['admin_consumption_override'] = adminConsumptionOverride
          .toString();
    }

    return params;
  }
}

class RejectReadingRequest {
  final String rejectedBy;
  final String rejectionReason;

  RejectReadingRequest({
    required this.rejectedBy,
    required this.rejectionReason,
  });

  Map<String, String> toQueryParams() {
    return {'rejected_by': rejectedBy, 'rejection_reason': rejectionReason};
  }
}

class VerifyRolloverRequest {
  final String verifiedBy;
  final bool isGenuineRollover;
  final String? notes;

  VerifyRolloverRequest({
    required this.verifiedBy,
    required this.isGenuineRollover,
    this.notes,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'verified_by': verifiedBy,
      'is_genuine_rollover': isGenuineRollover.toString(),
    };

    if (notes != null && notes!.isNotEmpty) {
      params['notes'] = notes!;
    }

    return params;
  }
}

class RejectRolloverRequest {
  final String rejectedBy;
  final String reason;
  final String? notes;

  RejectRolloverRequest({
    required this.rejectedBy,
    required this.reason,
    this.notes,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'rejected_by': rejectedBy,
      'reason': reason,
    };

    if (notes != null && notes!.isNotEmpty) {
      params['notes'] = notes!;
    }

    return params;
  }
}
