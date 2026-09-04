import 'api_client.dart';

class AuthApi {
  AuthApi._();
  static final AuthApi instance = AuthApi._();

  final _client = ApiClient.instance;

  Future<Map<String, dynamic>> register({
    required String phone,
    required String firstName,
    required String surname,
    required String password,
  }) =>
      _client.post({
        'theKey': 'R10',
        'firstname': firstName,
        'surname': surname,
        'phone': phone,
        'password': password,
      });

  Future<Map<String, dynamic>> registerDriver({
    required String phone,
    required String firstName,
    required String surname,
    required String password,
    required String vehicleType,
    required String vehicleMake,
    required String vehicleModel,
    required String vehicleYear,
    required String vehicleColor,
  }) =>
      _client.post({
        'theKey': 'R10.1',
        'firstname': firstName,
        'surname': surname,
        'phone': phone,
        'password': password,
        'vtype': vehicleType,
        'vmake': vehicleMake,
        'vmodel': vehicleModel,
        'vyear': vehicleYear,
        'vcolor': vehicleColor,
      });

  Future<Map<String, dynamic>> signIn({
    required String phone,
    required String password,
    required String lat,
    required String lng,
  }) =>
      _client.post({
        'theKey': 'R11.1',
        'phone': phone,
        'password': password,
        'longitude': lng,
        'latitude': lat,
      });

  Future<Map<String, dynamic>> verifyPhone({
    required String phone,
    required String otp,
  }) =>
      _client.post({
        'theKey': 'R11',
        'phone': phone,
        'otp': otp,
      });

  Future<Map<String, dynamic>> requestOtp({
    required String phone,
  }) =>
      _client.post({
        'theKey': 'R11.7',
        'Phone': phone,
        'OldPhone': phone,
      });

  Future<Map<String, dynamic>> resetPassword({
    required String phone,
    required String otp,
    required String password,
  }) =>
      _client.post({
        'theKey': 'R11.8',
        'Phone': phone,
        'Otp': otp,
        'NewPassword': password,
      });
}
