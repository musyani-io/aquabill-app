/// DTO for admin registration request
class AdminRegisterRequest {
  final String username;
  final String password;
  final String confirmPassword;
  final String companyName;
  final String companyPhone;
  final String roleAtCompany;
  final int estimatedClients;

  AdminRegisterRequest({
    required this.username,
    required this.password,
    required this.confirmPassword,
    required this.companyName,
    required this.companyPhone,
    required this.roleAtCompany,
    required this.estimatedClients,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'confirm_password': confirmPassword,
    'company_name': companyName,
    'company_phone': companyPhone,
    'role_at_company': roleAtCompany,
    'estimated_clients': estimatedClients,
  };
}

/// DTO for admin login request
class AdminLoginRequest {
  final String username;
  final String password;

  AdminLoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() => {'username': username, 'password': password};
}

/// DTO for login response (admin or collector)
class LoginResponse {
  final String token;
  final int userId;
  final String name;
  final String role;

  LoginResponse({
    required this.token,
    required this.userId,
    required this.name,
    required this.role,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    token: json['token'] as String,
    userId: json['user_id'] ?? json['collector_id'] as int,
    name: json['username'] ?? json['name'] as String,
    role: json['role'] as String? ?? 'collector',
  );
}

/// DTO for collector creation request
class CollectorCreateRequest {
  final String name;
  final String password;

  CollectorCreateRequest({required this.name, required this.password});

  Map<String, dynamic> toJson() => {'name': name, 'password': password};
}

/// DTO for collector login request
class CollectorLoginRequest {
  final String name;
  final String password;

  CollectorLoginRequest({required this.name, required this.password});

  Map<String, dynamic> toJson() => {'name': name, 'password': password};
}

/// DTO for collector response
class CollectorResponse {
  final int id;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  CollectorResponse({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });

  factory CollectorResponse.fromJson(Map<String, dynamic> json) =>
      CollectorResponse(
        id: json['id'] as int,
        name: json['name'] as String,
        isActive: json['is_active'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// DTO for collectors list response
class CollectorListResponse {
  final int total;
  final List<CollectorResponse> collectors;

  CollectorListResponse({required this.total, required this.collectors});

  factory CollectorListResponse.fromJson(Map<String, dynamic> json) =>
      CollectorListResponse(
        total: json['total'] as int,
        collectors: (json['collectors'] as List<dynamic>)
            .map((e) => CollectorResponse.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
