import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../services/services.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';

/// Full account settings — profile fields, resume, and password change.
/// Mirrors the web's Settings page (`dashboard/client/settings`), which
/// `profile_screen.dart` deliberately keeps separate from (that screen stays
/// the quick summary card + theme switch + sign out).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: theme.textTheme.titleLarge)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _ProfileSection(),
          SizedBox(height: 16),
          _ResumeSection(),
          SizedBox(height: 16),
          _PasswordSection(),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ Profile */

class _ProfileSection extends StatefulWidget {
  const _ProfileSection();

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  late final TextEditingController _username;
  late final TextEditingController _bio;
  late final TextEditingController _phone;
  late final TextEditingController _github;
  late final TextEditingController _linkedin;
  late final TextEditingController _skills;
  late final TextEditingController _experience;
  late final TextEditingController _education;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().user;
    _username = TextEditingController(text: user?.username ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _github = TextEditingController(text: user?.github ?? '');
    _linkedin = TextEditingController(text: user?.linkedin ?? '');
    _skills = TextEditingController(text: (user?.skills ?? const []).join(', '));
    _experience = TextEditingController(text: user?.experience ?? '');
    _education = TextEditingController(text: user?.education ?? '');
  }

  @override
  void dispose() {
    for (final c in [_username, _bio, _phone, _github, _linkedin, _skills, _experience, _education]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AuthService>().updateProfile(
            username: _username.text.trim(),
            bio: _bio.text.trim(),
            phone: _phone.text.trim(),
            github: _github.text.trim(),
            linkedin: _linkedin.text.trim(),
            skills: _skills.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
            experience: _experience.text.trim(),
            education: _education.text.trim(),
          );
      if (!mounted) return;
      await context.read<AuthController>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Profile'),
            const SizedBox(height: 4),
            Text('How you appear across the platform, plus the background used to tailor roadmaps and interview questions.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username')),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            const SizedBox(height: 4),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 12),
            TextField(controller: _github, decoration: const InputDecoration(labelText: 'GitHub URL')),
            const SizedBox(height: 12),
            TextField(controller: _linkedin, decoration: const InputDecoration(labelText: 'LinkedIn URL')),
            const SizedBox(height: 12),
            TextField(
              controller: _skills,
              decoration: const InputDecoration(labelText: 'Skills (comma-separated)'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _experience, decoration: const InputDecoration(labelText: 'Experience')),
            const SizedBox(height: 12),
            TextField(controller: _education, decoration: const InputDecoration(labelText: 'Education')),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ Resume */

class _ResumeSection extends StatefulWidget {
  const _ResumeSection();

  @override
  State<_ResumeSection> createState() => _ResumeSectionState();
}

class _ResumeSectionState extends State<_ResumeSection> {
  bool _busy = false;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<AuthService>().uploadResume(file.bytes!, file.name);
      if (!mounted) return;
      await context.read<AuthController>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Resume uploaded — it now informs your interviews and roadmaps.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().deleteResume();
      if (!mounted) return;
      await context.read<AuthController>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resume removed.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthController>().user;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Resume'),
            const SizedBox(height: 4),
            Text('Upload a PDF to fill in your background automatically.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            if (user?.hasResume ?? false)
              Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      user!.resumeUploadedAt != null
                          ? 'Uploaded ${user.resumeUploadedAt!.day}/${user.resumeUploadedAt!.month}/${user.resumeUploadedAt!.year}'
                          : 'Resume on file',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _delete,
                    style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    child: const Text('Remove'),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickAndUpload,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file_outlined),
                label: const Text('Upload PDF'),
              ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ Password */

class _PasswordSection extends StatefulWidget {
  const _PasswordSection();

  @override
  State<_PasswordSection> createState() => _PasswordSectionState();
}

class _PasswordSectionState extends State<_PasswordSection> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _devHint;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = context.read<AuthController>().user?.email;
    if (email == null) return;
    setState(() => _busy = true);
    try {
      final devCode = await context.read<AuthService>().requestPasswordCode(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _devHint = devCode != null ? 'Development code: $devCode' : null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('If email is set up, a code is on its way.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final email = context.read<AuthController>().user?.email;
    if (email == null) return;
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords don't match.")));
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().resetPassword(email, _code.text.trim(), _password.text);
      if (!mounted) return;
      // Resetting the password bumps the backend's securityVersion, which
      // invalidates every access token issued before it — including the one
      // this session is holding. Sign out cleanly rather than let the next
      // API call surprise the user with an auth failure.
      final navigator = Navigator.of(context);
      await context.read<AuthController>().logout();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = context.watch<AuthController>().user?.email ?? 'your address';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Password'),
            const SizedBox(height: 4),
            Text("We'll email a one-time code to $email to confirm it's you.",
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            if (!_codeSent)
              OutlinedButton(
                onPressed: _busy ? null : _sendCode,
                child: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Email me a code'),
              )
            else ...[
              if (_devHint != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_devHint!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                ),
              TextField(controller: _code, decoration: const InputDecoration(labelText: 'Code from email')),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Update password'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
