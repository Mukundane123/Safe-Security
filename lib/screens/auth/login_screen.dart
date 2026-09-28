import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/app_user.dart';
import '../../repositories/demo_repository.dart';
import '../../state/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _resetting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.primary : null,
      ),
    );
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthController>();
    final ok = await auth.signIn(_email.text, _password.text);
    if (ok) {
      _showMessage('Signed in successfully.');
    } else if (auth.error != null) {
      _showMessage(auth.error!, error: true);
    }
  }

  Future<void> _forgotPassword() async {
    final auth = context.read<AuthController>();
    final controller = TextEditingController(text: _email.text);
    setState(() => _resetting = true);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) {
      setState(() => _resetting = false);
      return;
    }
    final ok = await auth.resetPassword(result);
    if (!mounted) return;
    setState(() => _resetting = false);
    _showMessage(
      ok
          ? 'Password reset email sent. Check your inbox.'
          : auth.error ?? 'Could not reset password.',
      error: !ok,
    );
  }

  void _fillDemo(UserRole role) {
    final email = switch (role) {
      UserRole.citizen => 'citizen@demo.safeguard',
      UserRole.responder => 'responder@demo.safeguard',
      UserRole.administrator => 'admin@demo.safeguard',
    };
    setState(() {
      _email.text = email;
      _password.text = DemoRepository.demoPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: auth.busy
                ? const LoadingScreen(message: 'Signing in...')
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.shield,
                                color: Colors.white, size: 40),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'SafeGuard',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Community Security & Emergency Response',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (value) =>
                              (value == null || !value.contains('@'))
                                  ? 'Enter a valid email'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (value) => (value == null || value.length < 6)
                              ? 'Password must be at least 6 characters'
                              : null,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetting ? null : _forgotPassword,
                            child: Text(_resetting
                                ? 'Check inbox...'
                                : 'Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _signIn,
                          child: const Text('Sign in'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account?",
                              style: TextStyle(color: AppColors.muted),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                              child: const Text('Create one'),
                            ),
                          ],
                        ),
                        if (auth.repo is DemoRepository) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Demo mode: choose a role to autofill credentials.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton(
                                onPressed: () => _fillDemo(UserRole.citizen),
                                child: const Text('Citizen demo'),
                              ),
                              OutlinedButton(
                                onPressed: () => _fillDemo(UserRole.responder),
                                child: const Text('Responder demo'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    _fillDemo(UserRole.administrator),
                                child: const Text('Admin demo'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Case study: ${AppConfig.defaultArea}, Mbarara City',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
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