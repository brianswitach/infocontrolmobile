// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://www.infocontrol.com.ar/desarrollo_v2';
  
  Future<String?> login(String username, String password) async {
    final url = Uri.parse('$_baseUrl/api/web/workers/login');
    
    final response = await http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == true) {
        return data['data']['Bearer'];
      } else {
        throw Exception(data['message']);
      }
    } else {
      throw Exception('Error al hacer login');
    }
  }
}
