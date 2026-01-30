import 'package:dio/dio.dart';
import 'api_exception.dart';

/// Data transfer objects for Ledger API

class LedgerEntryResponse {
  final int id;
  final int meterAssignmentId;
  final int cycleId;
  final String entryType; // CHARGE, ADJUSTMENT, PAYMENT, PENALTY
  final double amount;
  final bool isCredit;
  final String description;
  final String createdBy;
  final DateTime createdAt;

  LedgerEntryResponse({
    required this.id,
    required this.meterAssignmentId,
    required this.cycleId,
    required this.entryType,
    required this.amount,
    required this.isCredit,
    required this.description,
    required this.createdBy,
    required this.createdAt,
  });

  factory LedgerEntryResponse.fromJson(Map<String, dynamic> json) {
    return LedgerEntryResponse(
      id: json['id'] as int,
      meterAssignmentId: json['meter_assignment_id'] as int,
      cycleId: json['cycle_id'] as int,
      entryType: json['entry_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      isCredit: json['is_credit'] as bool,
      description: json['description'] as String,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isCharge => entryType == 'CHARGE';
  bool get isPayment => entryType == 'PAYMENT';
  bool get isPenalty => entryType == 'PENALTY';
  bool get isAdjustment => entryType == 'ADJUSTMENT';

  String get entryTypeDisplayName {
    switch (entryType) {
      case 'CHARGE':
        return 'Charge';
      case 'PAYMENT':
        return 'Payment';
      case 'PENALTY':
        return 'Penalty';
      case 'ADJUSTMENT':
        return 'Adjustment';
      default:
        return entryType;
    }
  }
}

class BalanceResponse {
  final int meterAssignmentId;
  final double totalDebits;
  final double totalCredits;
  final double netBalance;
  final BalanceBreakdown breakdown;

  BalanceResponse({
    required this.meterAssignmentId,
    required this.totalDebits,
    required this.totalCredits,
    required this.netBalance,
    required this.breakdown,
  });

  factory BalanceResponse.fromJson(Map<String, dynamic> json) {
    return BalanceResponse(
      meterAssignmentId: json['meter_assignment_id'] as int,
      totalDebits: (json['total_debits'] as num).toDouble(),
      totalCredits: (json['total_credits'] as num).toDouble(),
      netBalance: (json['net_balance'] as num).toDouble(),
      breakdown: BalanceBreakdown.fromJson(
        json['breakdown'] as Map<String, dynamic>,
      ),
    );
  }
}

class BalanceBreakdown {
  final double charges;
  final double penalties;
  final double payments;
  final double adjustmentsDebit;
  final double adjustmentsCredit;

  BalanceBreakdown({
    required this.charges,
    required this.penalties,
    required this.payments,
    required this.adjustmentsDebit,
    required this.adjustmentsCredit,
  });

  factory BalanceBreakdown.fromJson(Map<String, dynamic> json) {
    return BalanceBreakdown(
      charges: (json['charges'] as num).toDouble(),
      penalties: (json['penalties'] as num).toDouble(),
      payments: (json['payments'] as num).toDouble(),
      adjustmentsDebit: (json['adjustments_debit'] as num).toDouble(),
      adjustmentsCredit: (json['adjustments_credit'] as num).toDouble(),
    );
  }
}

class CreateLedgerEntryRequest {
  final int meterAssignmentId;
  final int cycleId;
  final String entryType;
  final double amount;
  final bool isCredit;
  final String description;
  final String createdBy;

  CreateLedgerEntryRequest({
    required this.meterAssignmentId,
    required this.cycleId,
    required this.entryType,
    required this.amount,
    required this.isCredit,
    required this.description,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'meter_assignment_id': meterAssignmentId,
      'cycle_id': cycleId,
      'entry_type': entryType,
      'amount': amount,
      'is_credit': isCredit,
      'description': description,
      'created_by': createdBy,
    };
  }
}

/// API client for Ledger endpoints
class LedgerApiClient {
  final Dio _dio;

  LedgerApiClient(String baseUrl, String token)
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

  /// List all ledger entries (with optional filters)
  Future<List<LedgerEntryResponse>> listLedgerEntries({
    int skip = 0,
    int limit = 100,
    int? meterAssignmentId,
    int? cycleId,
  }) async {
    try {
      final queryParams = <String, dynamic>{'skip': skip, 'limit': limit};
      if (meterAssignmentId != null) {
        queryParams['meter_assignment_id'] = meterAssignmentId;
      }
      if (cycleId != null) {
        queryParams['cycle_id'] = cycleId;
      }

      final response = await _dio.get(
        '/billing/ledger',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map(
              (json) =>
                  LedgerEntryResponse.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw ApiException(
          'Failed to fetch ledger entries: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get single ledger entry by ID
  Future<LedgerEntryResponse> getLedgerEntry(int entryId) async {
    try {
      final response = await _dio.get('/billing/ledger/$entryId');

      if (response.statusCode == 200) {
        return LedgerEntryResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
      } else {
        throw ApiException(
          'Failed to fetch ledger entry: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Create a new ledger entry (manual adjustment)
  Future<LedgerEntryResponse> createLedgerEntry(
    CreateLedgerEntryRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/billing/ledger',
        data: request.toJson(),
      );

      if (response.statusCode == 201) {
        return LedgerEntryResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
      } else {
        throw ApiException(
          'Failed to create ledger entry: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get balance for a meter assignment
  Future<BalanceResponse> getBalance(int meterAssignmentId) async {
    try {
      final response = await _dio.get('/billing/balance/$meterAssignmentId');

      if (response.statusCode == 200) {
        return BalanceResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ApiException('Failed to fetch balance: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiException _handleDioError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode ?? 0;
      final message = e.response!.data.toString();

      switch (statusCode) {
        case 401:
          return ApiException('Unauthorized: Please login again');
        case 403:
          return ApiException('Forbidden: Insufficient permissions');
        case 404:
          return ApiException('Not found: $message');
        case 400:
          return ApiException('Bad request: $message');
        default:
          return ApiException('Server error ($statusCode): $message');
      }
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiException('Connection timeout');
    } else if (e.type == DioExceptionType.unknown) {
      return ApiException('Network error: ${e.message}');
    } else {
      return ApiException('Request failed: ${e.message}');
    }
  }
}
