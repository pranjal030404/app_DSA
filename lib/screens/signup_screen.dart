import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../services/services.dart';
import '../services/signup_verification.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Native account creation. Asks the backend for an email code first; when
/// email verification is switched off (`skipped`) it registers immediately,
/// otherwise it reveals a code field and registers once the code is entered.
///
/// Also handles the admin-configurable extras the website supports: phone
/// (SMS) verification via the native Firebase SDK. The website's reCAPTCHA
/// is skipped for the app by the backend, so nothing here uses a WebView.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _awaitingCode = false;

  // Admin-configured extras; null until loaded (treated as "none required").
  SignupRequirements? _requirements;

  // Phone (SMS) verification
  final _phone = TextEditingController();
  final _phoneCode = TextEditingController();
  final _phoneVerifier = PhoneVerifier();
  bool _phoneCodeSent = false;
  String? _phoneIdToken;
  bool _phoneBusy = false;

  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_-]+$');
  static final _passwordPattern = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)');

  @override
  void initState() {
    super.initState();
    SignupRequirements.load(context.read<ApiClient>()).then((r) {
      if (mounted) setState(() => _requirements = r);
    }).catchError((_) {
      // Settings unreachable: carry on; the backend still enforces its rules.
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _phoneCode.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));

  Future<void> _sendPhoneCode() async {
    final phone = _phone.text.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\+\d{7,15}$').hasMatch(phone)) {
      _toast('Use international format, e.g. +919876543210.');
      return;
    }
    setState(() => _phoneBusy = true);
    try {
      // Non-null when Android auto-verified the number without a code.
      final idToken = await _phoneVerifier.sendCode(phone);
      if (!mounted) return;
      setState(() {
        _phoneCodeSent = true;
        _phoneIdToken = idToken;
      });
      if (idToken == null) _toast('Code sent by SMS.');
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _phoneBusy = false);
    }
  }

  Future<void> _confirmPhoneCode() async {
    if (!_phoneCodeSent) return;
    if (_phoneCode.text.trim().isEmpty) {
      _toast('Enter the code from the SMS.');
      return;
    }
    setState(() => _phoneBusy = true);
    try {
      final idToken = await _phoneVerifier.confirmCode(_phoneCode.text.trim());
      if (mounted) setState(() => _phoneIdToken = idToken);
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _phoneBusy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    if ((_requirements?.phoneOtpRequired ?? false) && _phoneIdToken == null) {
      _toast('Verify your phone number to continue.');
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthController>();
    final username = _username.text.trim();
    final email = _email.text.trim();
    try {
      if (!_awaitingCode) {
        final codeSent = await context.read<AuthService>().requestSignupOtp(email, username);
        if (codeSent) {
          setState(() => _awaitingCode = true);
          messenger.showSnackBar(const SnackBar(
            content: Text('We emailed you a verification code.'),
            behavior: SnackBarBehavior.floating,
          ));
          return;
        }
      }
      await auth.register(
        username,
        email,
        _password.text,
        otp: _otp.text.trim(),
        firebaseIdToken: _phoneIdToken,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 56)),
                    const SizedBox(height: 22),
                    Text(
                      'Create your account.',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Free, and the same account works on the website.',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160)),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _username,
                      enabled: !_awaitingCode,
                      autofillHints: const [AutofillHints.newUsername],
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.length < 3 || s.length > 30) return '3–30 characters';
                        if (!_usernamePattern.hasMatch(s)) return 'Letters, numbers, _ and - only';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      enabled: !_awaitingCode,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      enabled: !_awaitingCode,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: '8+ characters with upper, lower case and a number',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (v) {
                        final s = v ?? '';
                        if (s.length < 8) return 'At least 8 characters';
                        if (!_passwordPattern.hasMatch(s)) return 'Needs upper case, lower case and a number';
                        return null;
                      },
                    ),
                    if (_requirements?.phoneOtpRequired ?? false) ...[
                      const SizedBox(height: 14),
                      _PhoneVerification(
                        phone: _phone,
                        code: _phoneCode,
                        codeSent: _phoneCodeSent,
                        verified: _phoneIdToken != null,
                        busy: _phoneBusy,
                        onSend: _sendPhoneCode,
                        onConfirm: _confirmPhoneCode,
                        onChangeNumber: () => setState(() {
                          _phoneCodeSent = false;
                          _phoneIdToken = null;
                          _phoneCode.clear();
                        }),
                      ),
                    ],
                    if (_awaitingCode) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _otp,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Verification code',
                          helperText: 'Sent to ${_email.text.trim()}',
                          prefixIcon: const Icon(Icons.mark_email_read_outlined),
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the code from your email' : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : () => setState(() => _awaitingCode = false),
                          child: const Text('Change details'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_awaitingCode ? 'Verify & create account' : 'Create account'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Phone number → SMS code → verified, shown only when the admin requires it.
class _PhoneVerification extends StatelessWidget {
  const _PhoneVerification({
    required this.phone,
    required this.code,
    required this.codeSent,
    required this.verified,
    required this.busy,
    required this.onSend,
    required this.onConfirm,
    required this.onChangeNumber,
  });

  final TextEditingController phone;
  final TextEditingController code;
  final bool codeSent;
  final bool verified;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onConfirm;
  final VoidCallback onChangeNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const spinner = SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));

    if (verified) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.verified_rounded, color: theme.colorScheme.primary),
          title: const Text('Phone verified'),
          subtitle: Text(phone.text.trim()),
          trailing: TextButton(onPressed: onChangeNumber, child: const Text('Change')),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: phone,
          enabled: !codeSent,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: InputDecoration(
            labelText: 'Phone number',
            hintText: '+919876543210',
            helperText: 'Required — we\'ll text you a code',
            prefixIcon: const Icon(Icons.phone_iphone_rounded),
            suffixIcon: codeSent
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: TextButton(onPressed: busy ? null : onSend, child: busy ? spinner : const Text('Send code')),
                  ),
          ),
        ),
        if (codeSent) ...[
          const SizedBox(height: 14),
          TextField(
            controller: code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: InputDecoration(
              labelText: 'SMS code',
              prefixIcon: const Icon(Icons.sms_outlined),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton(onPressed: busy ? null : onConfirm, child: busy ? spinner : const Text('Verify')),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: busy ? null : onChangeNumber, child: const Text('Change number')),
          ),
        ],
      ],
    );
  }
}
