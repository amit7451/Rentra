import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../app/theme.dart';
import '../../app/routes.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/app_background.dart';
import '../../widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.main);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.darkTeal,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.main);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: $e'),
            backgroundColor: AppTheme.darkTeal,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final AuthService authService = AuthService();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'Enter your registered email',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();

              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your email')),
                );
                return;
              }

              try {
                await authService.resetPassword(email);
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password reset email sent. Please check your inbox.',
                    ),
                  ),
                );

                Navigator.pop(context);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.black;
    final subTextColor = isDark ? Colors.white70 : AppTheme.grey;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Squircle Logo Section
                  Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(44),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(44),
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Title Section
                  Text(
                    'Welcome Back!',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: subTextColor,
                          letterSpacing: 0.2,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // Glassmorphic Login Form
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: 24,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: textColor),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: subTextColor,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
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
                            onPressed: () => _showForgotPasswordDialog(context),
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(color: AppTheme.accentTeal),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          text: 'Sign In',
                          onPressed: _handleLogin,
                          isLoading: _isLoading,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Social Login Section
                  Row(
                    children: [
                      const Expanded(child: Divider(thickness: 0.5)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(color: subTextColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Expanded(child: Divider(thickness: 0.5)),
                    ],
                  ),

                  const SizedBox(height: 32),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      height: 22,
                    ),
                    label: Text(
                      'Continue with Google',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Footer Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: subTextColor),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed(AppRoutes.signup);
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
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
