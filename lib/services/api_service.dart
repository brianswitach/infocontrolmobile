// lib/services/api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String _baseUrl = 'https://www.infocontrol.com.ar';

  Future<String?> login(String username, String password) async {
    final url = Uri.parse("$_baseUrl/desarrollo_v2/api/web/workers/login");

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
    final url = Uri.parse("$_baseUrl/desarrollo_v2/api/mobile/empresas/listar");

    var headers = {
      'Authorization': 'Bearer $bearerToken',
      'Content-Type': 'application/json',
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