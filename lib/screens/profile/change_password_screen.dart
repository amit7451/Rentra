import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../app/theme.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/glass_card.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw 'User not logged in';

      if (_authService.hasPassword) {
        // 1. Regular Password Update (Requires re-auth with old password)
        await _authService.reauthenticateWithEmail(_oldPasswordController.text);
        await _authService.updatePassword(_newPasswordController.text);
      } else {
        // 2. Setting password for the first time (e.g., Google User)
        try {
          // Try to link directly first (works if session is fresh)
          await _authService.linkEmailPassword(
            user.email!,
            _newPasswordController.text,
          );
        } catch (e) {
          // If session is old, Firebase will throw 'requires-recent-login'
          if (e.toString().contains('requires-recent-login') ||
              e.toString().contains('recent-login')) {
            // ONLY now ask for Google re-auth
            await _authService.reauthenticateWithGoogle();
            // Try linking again after re-auth
            await _authService.linkEmailPassword(
              user.email!,
              _newPasswordController.text,
            );
          } else {
            rethrow;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.darkTeal,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPassword = _authService.hasPassword;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          hasPassword ? 'Change Password' : 'Set Password',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F2F31), Color(0xFF184A4C)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hasPassword
                    ? 'Enter your current password and choose a new one.'
                    : 'Your account is linked with Google. You can set a password to log in with email too.',
                style: const TextStyle(color: AppTheme.grey, fontSize: 15),
              ),
              const SizedBox(height: 32),
              GlassCard(
                borderRadius: 16,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (hasPassword) ...[
                      TextFormField(
                        controller: _oldPasswordController,
                        obscureText: _obscureOld,
                        cursorColor: AppTheme.getPriceColor(context),
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          labelStyle: const TextStyle(color: AppTheme.grey),
                          floatingLabelStyle: TextStyle(color: AppTheme.getPriceColor(context)),
                          prefixIcon: const Icon(Icons.lock_outline),
                          filled: false,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureOld ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _obscureOld = !_obscureOld),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter current password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      cursorColor: AppTheme.getPriceColor(context),
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      decoration: InputDecoration(
                        labelText: hasPassword ? 'New Password' : 'Password',
                        labelStyle: const TextStyle(color: AppTheme.grey),
                        floatingLabelStyle: TextStyle(color: AppTheme.getPriceColor(context)),
                        prefixIcon: const Icon(Icons.lock_outline),
                        filled: false,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNew ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      cursorColor: AppTheme.getPriceColor(context),
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        labelStyle: const TextStyle(color: AppTheme.grey),
                        floatingLabelStyle: TextStyle(color: AppTheme.getPriceColor(context)),
                        prefixIcon: const Icon(Icons.lock_reset),
                        filled: false,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              PrimaryButton(
                text: hasPassword ? 'Update Password' : 'Set Password',
                onPressed: _handleSubmit,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


