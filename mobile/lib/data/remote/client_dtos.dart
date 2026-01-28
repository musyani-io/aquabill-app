/// DTO for client creation request
class ClientCreateRequest {
  final String firstName;
  final String? otherNames;
  final String surname;
  final String phoneNumber;
  final String? clientCode;
  final String meterSerialNumber;
  final double initialMeterReading;

  ClientCreateRequest({
    required this.firstName,
    this.otherNames,
    required this.surname,
    required this.phoneNumber,
    this.clientCode,
    required this.meterSerialNumber,
    required this.initialMeterReading,
  });

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'other_names': otherNames,
    'surname': surname,
    'phone_number': phoneNumber,
    'client_code': clientCode,
    'meter_serial_number': meterSerialNumber,
    'initial_meter_reading': initialMeterReading,
  };
}

/// DTO for client response
class ClientResponse {
  final int id;
  final String firstName;
  final String? otherNames;
  final String surname;
  final String phoneNumber;
  final String? clientCode;
  final String meterSerialNumber;
  final double initialMeterReading;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClientResponse({
    required this.id,
    required this.firstName,
    this.otherNames,
    required this.surname,
    required this.phoneNumber,
    this.clientCode,
    required this.meterSerialNumber,
    required this.initialMeterReading,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClientResponse.fromJson(Map<String, dynamic> json) => ClientResponse(
    id: json['id'] as int,
    firstName: json['first_name'] as String,
    otherNames: json['other_names'] as String?,
    surname: json['surname'] as String,
    phoneNumber: json['phone_number'] as String,
    clientCode: json['client_code'] as String?,
    meterSerialNumber: json['meter_serial_number'] as String,
    initialMeterReading: (json['initial_meter_reading'] as num).toDouble(),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  String get fullName {
    if (otherNames != null && otherNames!.isNotEmpty) {
      return '$firstName $otherNames $surname';
    }
    return '$firstName $surname';
  }
}

/// DTO for clients list response
class ClientsListResponse {
  final List<ClientResponse> clients;

  ClientsListResponse({required this.clients});

  factory ClientsListResponse.fromJson(List<dynamic> json) =>
      ClientsListResponse(
        clients: json
            .map((e) => ClientResponse.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
