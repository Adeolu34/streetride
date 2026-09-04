import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baseUrl = 'https://streetrideplus.com/sr';
const _authEndpoint = 'http://streetrideplus.com/sr/AuthSP';
const _handlerEndpoint = '$_baseUrl/myhandler';

const _authUserId = 'Paysp1010\$i.i';
const _authSecretKey = r'$2a$10$3JK3bVeSVXW0xrVzqmvUmu/tX.XLoUqbwPxTYqZdDz1QHMB2jhDxm';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  String? _bearerToken;

  Future<String> _getToken() async {
    if (_bearerToken != null) return _bearerToken!;
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('sr_bearer_token');
    if (cached != null) {
      _bearerToken = cached;
      return cached;
    }
    return _refreshToken();
  }

  Future<String> _refreshToken() async {
    final res = await _dio.post(_authEndpoint,
        data: {'userId': _authUserId, 'secretKey': _authSecretKey},
        options: Options(contentType: 'application/json'));
    final token = res.data['token'] as String;
    _bearerToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sr_bearer_token', token);
    return token;
  }

  Future<Map<String, dynamic>> post(
    Map<String, dynamic> body, {
    bool multipart = false,
  }) async {
    final token = await _getToken();
    final headers = {
      'Authorization': 'Bearer $token',
    };

    try {
      final Response res;
      if (multipart) {
        res = await _dio.post(
          _handlerEndpoint,
          data: FormData.fromMap(body),
          options: Options(headers: headers),
        );
      } else {
        res = await _dio.post(
          _handlerEndpoint,
          data: body,
          options: Options(
            headers: headers,
            contentType: 'application/json',
          ),
        );
      }
      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      return {'raw': res.data};
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _bearerToken = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('sr_bearer_token');
        await _refreshToken();
        return post(body, multipart: multipart);
      }
      rethrow;
    }
  }
}
