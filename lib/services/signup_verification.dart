import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/api_client.dart';

/// Which signup checks the admin has switched on, read from
/// GET /platform-settings/public (the same source the website uses).
///
/// The website's reCAPTCHA check is not listed: it needs a WebView, so the
/// backend skips it for requests carrying the app's `X-Client-App` header.
class SignupRequirements {
  const SignupRequirements({this.phoneOtpRequired = false});

  final bool phoneOtpRequired;

  static Future<SignupRequirements> load(ApiClient api) async {
    final decoded = await api.get('/platform-settings/public');
    final data = api.unwrap(decoded);
    if (data is! Map) return const SignupRequirements();

    final verification = data['verification'] is Map ? data['verification'] as Map : const {};
    return SignupRequirements(
      phoneOtpRequired:
          verification['smsOtpEnabled'] == true && verification['requirePhoneOtpForSignup'] == true,
    );
  }
}

/// Firebase phone sign-in through the native SDK. Android proves the app is
/// genuine with Play Integrity, so there is no reCAPTCHA WebView; the result
/// is a Firebase ID token the backend verifies via `accounts:lookup`.
///
///   1. [sendCode] → SMS sent (or the code is auto-read from the SMS)
///   2. [confirmCode] → Firebase ID token for /auth/register
class PhoneVerifier {
  /// Set by `main()` once `Firebase.initializeApp()` succeeds — false when
  /// the build has no google-services.json.
  static bool firebaseReady = false;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
    } catch (_) {
      firebaseReady = false;
    }
  }

  String? _verificationId;

  /// Sends the SMS. Resolves to an ID token straight away when Android
  /// auto-verifies the number, otherwise to null (then call [confirmCode]).
  Future<String?> sendCode(String phoneNumber) {
    _ensureReady();
    final done = Completer<String?>();
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        if (done.isCompleted) return;
        try {
          done.complete(await _idTokenFor(credential));
        } catch (e) {
          done.completeError(e);
        }
      },
      verificationFailed: (e) {
        if (!done.isCompleted) done.completeError(ApiException(_friendly(e.code)));
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        if (!done.isCompleted) done.complete(null);
      },
      codeAutoRetrievalTimeout: (verificationId) => _verificationId = verificationId,
    );
    return done.future;
  }

  Future<String> confirmCode(String code) async {
    _ensureReady();
    final id = _verificationId;
    if (id == null) throw ApiException('Request a code first.');
    try {
      return await _idTokenFor(PhoneAuthProvider.credential(verificationId: id, smsCode: code));
    } on FirebaseAuthException catch (e) {
      throw ApiException(_friendly(e.code));
    }
  }

  Future<String> _idTokenFor(PhoneAuthCredential credential) async {
    final auth = FirebaseAuth.instance;
    final result = await auth.signInWithCredential(credential);
    final idToken = await result.user?.getIdToken();
    // The app's session is the backend's JWT, not Firebase's.
    await auth.signOut();
    if (idToken == null || idToken.isEmpty) throw ApiException('Could not verify the code.');
    return idToken;
  }

  void _ensureReady() {
    if (!firebaseReady) {
      throw ApiException('Phone verification is not set up in this build. Please contact support.');
    }
  }

  static String _friendly(String code) => switch (code) {
        'invalid-phone-number' => 'That phone number looks invalid. Use international format, e.g. +919876543210.',
        'missing-phone-number' => 'Enter your phone number.',
        'too-many-requests' || 'quota-exceeded' => 'Too many attempts. Please wait a while and try again.',
        'invalid-verification-code' || 'invalid-verification-id' => 'That code is incorrect.',
        'session-expired' || 'code-expired' => 'The code expired. Request a new one.',
        'app-not-authorized' || 'missing-client-identifier' =>
          'This app is not authorised for phone sign-in. Please contact support.',
        'operation-not-allowed' => 'Phone sign-in is not enabled for this app. Please contact support.',
        'network-request-failed' => 'No connection. Check your internet and try again.',
        _ => 'Phone verification failed ($code).',
      };
}
