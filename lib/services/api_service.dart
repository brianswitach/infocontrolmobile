// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://www.infocontrol.tech';

  Future<String?> login(String username, String password) async {
    final url = Uri.parse('$_baseUrl/web/api/web/workers/login');

    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == true) {
        return data['data']['Bearer'];
      } else {
        throw Exception(data['message']);
      }
    } else {
      throw Exception('Código de error: ${response.statusCode} - ${response.reasonPhrase}');
    }
  }

  Future<List<String>> fetchEmpresas(String bearerToken) async {
    final url = Uri.parse('$_baseUrl/web/api/mobile/empresas/listar');

    final response = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Cache-Control': 'no-cache',
        'User-Agent': 'PostmanRuntime/7.42.0',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<String> empresas = [];
      for (var item in data['data']) {
        empresas.add(item['nombre']);
      }
      return empresas;
    } else {
      throw Exception('Código de error: ${response.statusCode} - ${response.reasonPhrase}');
    }
  }
}
