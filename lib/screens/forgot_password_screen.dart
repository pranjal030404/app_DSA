import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../services/services.dart';

/// Signed-out password reset: email → one-time code → new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _devHint;

  static final _passwordPattern = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)');

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthService>();
    final email = _email.text.trim();
    try {
      if (!_codeSent) {
        final devCode = await auth.requestPasswordCode(email);
        setState(() {
          _codeSent = true;
          _devHint = devCode != null ? 'Development code: $devCode' : null;
        });
        messenger.showSnackBar(const SnackBar(content: Text('If that account exists, a code is on its way.')));
      } else {
        await auth.resetPassword(email, _code.text.trim(), _password.text);
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Password updated. Sign in with your new password.')));
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Reset password', style: theme.textTheme.titleLarge)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _codeSent
                  ? 'Enter the code we emailed you and choose a new password.'
                  : 'Enter your account email and we\'ll send you a one-time code.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withAlpha(170)),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email)),
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            if (_codeSent) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Code',
                  helperText: _devHint,
                  prefixIcon: const Icon(Icons.pin_outlined),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the code' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  helperText: '8+ characters with upper, lower case and a number',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) {
                  final s = v ?? '';
                  if (s.length < 8) return 'At least 8 characters';
                  if (!_passwordPattern.hasMatch(s)) return 'Needs upper case, lower case and a number';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 26),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_codeSent ? 'Update password' : 'Send code'),
            ),
          ],
        ),
      ),
    );
  }
}
