import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'user/discover_events_screen.dart';
import 'organizer/organizer_dashboard_screen.dart';
import '../services/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  String _signInErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return 'Your password is incorrect. Please try again.';
      case 'invalid-credential':
        return 'Your email or password is incorrect.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Sign in failed. Please check your credentials and try again.';
    }
  }

  Future<void> _showSignInAlert(String message) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Sign In Failed',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: const Color(0xFF0DF233),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLoginSuccessAlert() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Login Successful',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Welcome back!',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: const Color(0xFF0DF233),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  String _normalizedRole(String? role) {
    final value = role?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return '';

    if (value == 'organizer' || value == 'org') return 'organizer';
    if (value.contains('organizer')) return 'organizer';
    if (value.contains('admin')) return 'organizer';

    if (value == 'volunteer' || value == 'user') return 'volunteer';
    if (value.contains('volunteer')) return 'volunteer';

    return value;
  }

  String _roleFromUserData(Map<String, dynamic>? userData) {
    if (userData == null) return '';

    final directRole = _normalizedRole(userData['role']?.toString());
    if (directRole == 'organizer' || directRole == 'volunteer') {
      return directRole;
    }

    final userType = _normalizedRole(userData['userType']?.toString());
    if (userType == 'organizer' || userType == 'volunteer') {
      return userType;
    }

    final roles = userData['roles'];
    if (roles is List) {
      for (final rawRole in roles) {
        final role = _normalizedRole(rawRole?.toString());
        if (role == 'organizer') return 'organizer';
      }
      for (final rawRole in roles) {
        final role = _normalizedRole(rawRole?.toString());
        if (role == 'volunteer') return 'volunteer';
      }
    }

    return '';
  }

  Future<String> _resolveRoleForCurrentUser() async {
    final user = _firebaseService.currentUser;
    if (user == null) return '';

    // Retry a few times in case profile document is slightly delayed.
    for (var attempt = 0; attempt < 3; attempt++) {
      final userData = await _firebaseService.getUserData(user.uid);
      final role = _roleFromUserData(userData);
      if (role == 'organizer' || role == 'volunteer') {
        return role;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    return '';
  }

  void _navigateForRole(NavigatorState navigator, String role) {
    if (role == 'organizer') {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()),
        (route) => false,
      );
      return;
    }

    if (role == 'volunteer') {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DiscoverEventsScreen()),
        (route) => false,
      );
      return;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'GoodDeeds',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 900 ? 32.0 : 24.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0DF233,
                            ).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.volunteer_activism,
                            size: 48,
                            color: Color(0xFF0DF233),
                          ),
                        ),
                        const Text(
                          'Welcome back',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to continue your journey of impact.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: const Icon(Icons.mail),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF0DF233),
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF0DF233),
                              ),
                            ),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Color(0xFF757575),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    if (_formKey.currentState!.validate()) {
                                      setState(() => _isLoading = true);
                                      final navigator = Navigator.of(context);

                                      try {
                                        await _firebaseService.signIn(
                                          email: _emailController.text.trim(),
                                          password: _passwordController.text,
                                        );
                                        if (!mounted) return;

                                        String role = '';
                                        try {
                                          role =
                                              await _resolveRoleForCurrentUser();
                                        } catch (e, st) {
                                          debugPrint(
                                            'Login role lookup failed: $e\n$st',
                                          );
                                        }

                                        if (!mounted) return;
                                        await _showLoginSuccessAlert();
                                        if (!mounted) return;

                                        debugPrint(
                                          'Login routing role resolved as: $role',
                                        );

                                        if (role.isEmpty) {
                                          await _showSignInAlert(
                                            'Login succeeded, but your role is missing in your profile. Please contact support or sign in again after profile setup.',
                                          );
                                          return;
                                        }

                                        _navigateForRole(navigator, role);
                                      } on FirebaseAuthException catch (e) {
                                        if (!mounted) return;
                                        await _showSignInAlert(
                                          _signInErrorMessage(e),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        await _showSignInAlert(
                                          'Unable to sign in right now. Please try again.',
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isLoading = false);
                                        }
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0DF233),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              shadowColor: const Color(
                                0xFF0DF233,
                              ).withValues(alpha: 0.3),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.black,
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
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                "Don't have an account?",
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0DF233)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0DF233),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          height: 200,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCm3zD-5MNeMHcMbIXqKYABJPruP8A8aO_JZXiuXMkAcG7KBwM5Ot9WiLJQj_o7YgJagzR-RlxOnpr8Zlk7I_cI8wgwKHihCfv9IW0BzljK5kO2MlCc0UkBKjo0gjrmH3JvwOPGlkP-QVr5YiRdTya7CI9ddooACiLUiI-aZON2z9zpnTmmLbKGVhpJM65W0hMTkrRFtrVvkSELJOgGoxUD9PwnjVjTI2HrZLzrtPD-lI2YYusl5bWGBDj98fx62vxLVyCLW_DwqWY',
                                  fit: BoxFit.cover,
                                  alignment: const Alignment(0, -0.5),
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported,
                                          size: 44,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.35),
                                      ],
                                    ),
                                  ),
                                ),
                                const Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'Join over 10,000 volunteers',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          '© 2026 GoodDeeds. All rights reserved.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
