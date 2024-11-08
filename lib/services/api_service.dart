// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://www.infocontrol.tech';

  Future<String?> login(String username, String password) async {
    final url = Uri.parse('$_baseUrl/web/api/web/workers/login');
    
    // Modificación a POST con envío de datos en el cuerpo
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
}
