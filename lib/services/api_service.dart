import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String _baseUrl = 'https://www.infocontrol.com.ar/desarrollo_v2';

  Future<String?> login(String username, String password) async {
    final url = Uri.parse("$_baseUrl/api/web/workers/login");
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': '*/*',
          'Cache-Control': 'no-cache',
          'User-Agent': 'PostmanRuntime/7.42.0',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'keep-alive',
          'Cookie': 'ci_session_infocontrolweb1=4ohde8tg4j314flf237b2v7c6l1u6a1i; cookie_sistema=9403e26ba93184a3aafc6dd61404daed'
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          final token = data['data']['Bearer'];
          return token;
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Código de error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error en login: $e');
    }
  }

  Future<Map<String, dynamic>> fetchEmpresas(String bearerToken) async {
    final url = Uri.parse("$_baseUrl/api/mobile/empresas/listar");
    var headers = {
      'Authorization': 'Bearer $bearerToken',
      'Content-Type': 'application/json',
      'Cookie': 'ci_session_infocontrolweb1=4ohde8tg4j314flf237b2v7c6l1u6a1i; cookie_sistema=9403e26ba93184a3aafc6dd61404daed'
    };
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return {
          'statusCode': response.statusCode,
          'body': jsonDecode(response.body),
        };
      } else {
        return {
          'statusCode': response.statusCode,
          'body': response.reasonPhrase ?? 'Error desconocido',
        };
      }
    } catch (e) {
      return {
        'statusCode': 500,
        'body': 'Error al realizar la solicitud: $e',
      };
    }
  }
}