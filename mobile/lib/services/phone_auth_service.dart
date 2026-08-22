import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_api.dart';
import '../state/session.dart';

/// Firebase Phone Auth wrapper. Google delivers the OTP SMS worldwide (incl.
/// India) with no DLT, then hands us an ID token which the backend verifies and
/// exchanges for a Millimore session (POST /auth/firebase).
///
/// Flow:
///   start(phone)  → SMS sent; onCodeSent(verificationId) fires
///   confirm(code) → signs into Firebase, gets the ID token, calls the backend
///
/// On Android, verification can auto-resolve (instant, no code) — [onAutoSignedIn]
/// fires with the finished [UserProfile] in that case.
class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  int? _resendToken;

  /// Send an SMS code to [e164Phone] (must be full E.164, e.g. +919000000000).
  Future<void> start(
    String e164Phone, {
    required void Function() onCodeSent,
    required void Function(String message) onError,
    void Function(UserProfile profile)? onAutoSignedIn,
    bool resend = false,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: e164Phone,
      forceResendingToken: resend ? _resendToken : null,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential cred) async {
        // Android instant/auto verification.
        try {
          final profile = await _signInWithCredential(cred);
          onAutoSignedIn?.call(profile);
        } catch (e) {
          onError(_msg(e));
        }
      },
      verificationFailed: (FirebaseAuthException e) => onError(_msg(e)),
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        onCodeSent();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  /// Confirm the SMS [code] the user typed, then exchange for a backend session.
  Future<UserProfile> confirm(String code) async {
    final vid = _verificationId;
    if (vid == null) {
      throw 'Request a code first.';
    }
    final cred = PhoneAuthProvider.credential(verificationId: vid, smsCode: code);
    return _signInWithCredential(cred);
  }

  Future<UserProfile> _signInWithCredential(PhoneAuthCredential cred) async {
    final result = await _auth.signInWithCredential(cred);
    final idToken = await result.user?.getIdToken();
    if (idToken == null) throw 'Could not complete phone sign-in.';
    final profile = await AuthApi.firebaseSignIn(idToken);
    // We don't need the Firebase session after the exchange.
    await _auth.signOut();
    return profile;
  }

  String _msg(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'That phone number looks invalid.';
        case 'invalid-verification-code':
          return 'Incorrect code — check and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        case 'session-expired':
          return 'The code expired — request a new one.';
        default:
          return e.message ?? 'Phone verification failed.';
      }
    }
    return e.toString();
  }
}
