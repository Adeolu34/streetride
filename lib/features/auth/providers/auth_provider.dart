import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/background_poll_service.dart';

class AuthResult {
  final String? error;
  final bool? isDriver;

  const AuthResult({this.error, this.isDriver});
}

class AuthState {
  final bool isLoading;
  const AuthState({this.isLoading = false});
}

class AuthNotifier extends Notifier<AuthState> {
  // Held briefly between signup → OTP → auto-login
  String? _pendingPhone;
  String? _pendingPassword;

  @override
  AuthState build() => const AuthState();

  Future<AuthResult> signIn({
    required String phone,
    required String password,
  }) async {
    state = const AuthState(isLoading: true);
    try {
      final data = await AuthApi.instance.signIn(
        phone: phone,
        password: password,
        lat: '0',
        lng: '0',
      );

      final isValid = data['IsValid'] == true;
      if (!isValid) {
        state = const AuthState();
        return AuthResult(error: data['Message']?.toString() ?? 'Invalid credentials.');
      }

      final profileJson = data['Profile'] as Map<String, dynamic>? ?? {};
      final isDriver = data['IsDriver'] == true;
      final isSuspended = data['Suspended'] == true;

      if (isSuspended) {
        state = const AuthState();
        return const AuthResult(error: 'Your account has been suspended. Contact support.');
      }

      final profile = UserProfile.fromJson({...profileJson, 'IsDriver': isDriver});
      await SessionService.instance.save(
        profile: profile,
        isDriver: isDriver,
        token: phone,
      );
      await BackgroundPollService.start();

      state = const AuthState();
      return AuthResult(isDriver: isDriver);
    } catch (e) {
      state = const AuthState();
      return AuthResult(error: 'Connection error. Please try again.');
    }
  }

  // Called from signup screen — registers account and sends OTP in one call
  Future<AuthResult> register({
    required String phone,
    required String firstName,
    required String surname,
    required String password,
  }) async {
    state = const AuthState(isLoading: true);
    try {
      final data = await AuthApi.instance.register(
        phone: phone,
        firstName: firstName,
        surname: surname,
        password: password,
      );

      final ok = data['success'] == true || data['Success'] == true || data['IsValid'] == true;
      if (!ok) {
        state = const AuthState();
        return AuthResult(
          error: data['message']?.toString() ?? data['Message']?.toString() ?? 'Registration failed.',
        );
      }

      _pendingPhone = phone;
      _pendingPassword = password;
      state = const AuthState();
      return const AuthResult();
    } catch (e) {
      state = const AuthState();
      return AuthResult(error: 'Connection error. Please try again.');
    }
  }

  Future<AuthResult> requestOtp({required String phone}) async {
    state = const AuthState(isLoading: true);
    try {
      await AuthApi.instance.requestOtp(phone: phone);
      state = const AuthState();
      return const AuthResult();
    } catch (e) {
      state = const AuthState();
      return AuthResult(error: 'Failed to send OTP. Check your number and try again.');
    }
  }

  // After OTP verified for a new signup, auto-signs in to get session
  Future<AuthResult> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    state = const AuthState(isLoading: true);
    try {
      final data = await AuthApi.instance.verifyPhone(
        phone: phone,
        otp: otp,
      );

      final ok = data['Status'] == true || data['status'] == true;
      if (!ok) {
        state = const AuthState();
        return AuthResult(
          error: data['Message']?.toString() ?? 'Invalid OTP. Please try again.',
        );
      }

      // Auto-login after successful OTP so session is created immediately
      final password = _pendingPassword;
      if (password != null) {
        _pendingPhone = null;
        _pendingPassword = null;
        return await signIn(phone: phone, password: password);
      }

      state = const AuthState();
      return const AuthResult();
    } catch (e) {
      state = const AuthState();
      return AuthResult(error: 'Verification failed. Please try again.');
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
