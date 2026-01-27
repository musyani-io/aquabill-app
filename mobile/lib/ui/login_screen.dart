import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../core/config.dart';
import '../data/remote/auth_api_client.dart';
import '../data/remote/auth_dtos.dart';
import 'signup_screen.dart';

/// Login screen for admin and collector authentication
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  UserRole _selectedRole = UserRole.collector;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      final authClient = AuthApiClient(baseUrl: Config.apiBaseUrl);

      late LoginResponse response;

      if (_selectedRole == UserRole.admin) {
        // Admin login
        final request = AdminLoginRequest(
          username: username,
          password: password,
        );
        response = await authClient.loginAdmin(request);
      } else {
        // Collector login - name and password
        final request = CollectorLoginRequest(
          name: username,
          password: password,
        );
        response = await authClient.loginCollector(request);
      }

      await AuthService().login(
        token: response.token,
        role: _selectedRole,
        username: response.name,
      );

      if (mounted) {
        // Navigate to home and remove login screen from stack
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Title
                  const Icon(Icons.water_drop, size: 80, color: Colors.blue),
                  const SizedBox(height: 16),
                  Text(
                    'AquaBill',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Water Meter Reading & Billing',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 48),

                  // Role Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Login as:',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<UserRole>(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Collector'),
                                  subtitle: const Text('Field readings'),
                                  value: UserRole.collector,
                                  groupValue: _selectedRole,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedRole = value);
                                    }
                                  },
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<UserRole>(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Admin'),
                                  subtitle: const Text('Management'),
                                  value: UserRole.admin,
                                  groupValue: _selectedRole,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedRole = value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Username/Name Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: _selectedRole == UserRole.admin
                          ? 'Username'
                          : 'Collector Name',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                      helperText: _selectedRole == UserRole.collector
                          ? 'Enter your name as assigned by admin'
                          : null,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return _selectedRole == UserRole.admin
                            ? 'Username is required'
                            : 'Collector name is required';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      helperText: _selectedRole == UserRole.collector
                          ? 'Enter your collector password'
                          : 'Enter your admin password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Password is required';
                      }
                      if (value.trim().length < 4) {
                        return 'Password must be at least 4 characters';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: 24),

                  // Login Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Admin Sign Up Option
                  if (_selectedRole == UserRole.admin) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an admin account? ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: const Text('Sign Up'),
                        ),
                      ],
                    ),
                  ],

                  // Help Text
                  if (_selectedRole == UserRole.collector)
                    Text(
                      'Contact your administrator if you forgot your password',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
