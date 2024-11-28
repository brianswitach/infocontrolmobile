import 'dart:convert';
import 'package:flutter/material.dart';
import './home_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import './hive_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String bearerToken = "";
  String _language = 'es';
  bool _showPendingMessages = false;
  List<Map<String, dynamic>> empresas = [];
  String? empresaNombre;
  String? empresaId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _usernameController.text = '';
    _passwordController.text = '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://www.infocontrolweb.com/inteligencia_artificial');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  void _changeLanguage(String language) {
    setState(() {
      _language = language;
    });
  }

  String getText(String key) {
    final Map<String, String> _spanishText = {
      'login': 'Iniciar sesión',
      'subtitle': 'Complete con sus datos para continuar',
      'userField': 'Usuario / Nº Identidad',
      'passwordField': 'Contraseña',
      'rememberData': 'Recordar datos',
      'forgotPassword': '¿Olvidaste tu contraseña?',
      'loginButton': 'Ingresar',
      'promoTitle': 'Optimizá la gestión de tus contratistas con IA',
      'promoSubtitle': 'Control integral, resultados sobresalientes.',
      'learnMore': 'Conocer más',
    };

    final Map<String, String> _englishText = {
      'login': 'Log in',
      'subtitle': 'Fill in your details to continue',
      'userField': 'User / ID Number',
      'passwordField': 'Password',
      'rememberData': 'Remember me',
      'forgotPassword': 'Forgot your password?',
      'loginButton': 'Log in',
      'promoTitle': 'Optimize contractor management with AI',
      'promoSubtitle': 'Comprehensive control, outstanding results.',
      'learnMore': 'Learn more',
    };

    final Map<String, String> _portugueseText = {
      'login': 'Iniciar sessão',
      'subtitle': 'Complete com seus dados para continuar',
      'userField': 'Usuário / Nº Identidade',
      'passwordField': 'Senha',
      'rememberData': 'Lembrar dados',
      'forgotPassword': 'Esqueceu sua senha?',
      'loginButton': 'Entrar',
      'promoTitle': 'Otimize a gestão de seus contratados com IA',
      'promoSubtitle': 'Controle integral, resultados excelentes.',
      'learnMore': 'Saiba mais',
    };

    switch (_language) {
      case 'es':
        return _spanishText[key] ?? '';
      case 'en':
        return _englishText[key] ?? '';
      case 'pt':
        return _portugueseText[key] ?? '';
      default:
        return '';
    }
  }

  Future<void> login(BuildContext context) async {
    String loginUrl = "https://www.infocontrol.tech/web/api/web/workers/login";
    String username = _usernameController.text;
    String password = _passwordController.text;
    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));

    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        List<Map<String, dynamic>> localEmpresas = HiveHelper.getEmpresas();

        if (localEmpresas.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                bearerToken: bearerToken,
                empresas: localEmpresas,
                username: username,
                password: password,
              ),
            ),
          );
        } else {
          print('No hay conexión y no hay datos locales disponibles.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No hay conexión y no hay datos locales disponibles.'),
            ),
          );
        }
        return;
      }

      print('Realizando solicitud de login a: $loginUrl');
      print('Headers de la solicitud:');
      print({
        'Content-Type': 'application/json',
        'Authorization': basicAuth,
        'Cookie': 'ci_session_infocontrolweb1=4ohde8tg4j314flf237b2v7c6l1u6a1i; cookie_sistema=9403e26ba93184a3aafc6dd61404daed'
      });
      print('Cuerpo de la solicitud:');
      print(jsonEncode({
        'username': username,
        'password': password,
      }));

      final loginResponse = await http.post(
        Uri.parse(loginUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': basicAuth,
          'Cookie': 'ci_session_infocontrolweb1=4ohde8tg4j314flf237b2v7c6l1u6a1i; cookie_sistema=9403e26ba93184a3aafc6dd61404daed'
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      print('\nRespuesta del servidor:');
      print('Código de estado: ${loginResponse.statusCode}');
      print('Headers de respuesta:');
      loginResponse.headers.forEach((key, value) {
        print('$key: $value');
      });
      print('\nCuerpo de la respuesta:');
      print(loginResponse.body);
      
      try {
        print('\nRespuesta JSON parseada:');
        final parsedJson = jsonDecode(loginResponse.body);
        print(JsonEncoder.withIndent('  ').convert(parsedJson));
      } catch (e) {
        print('\nError al parsear JSON: $e');
      }

      if (loginResponse.statusCode == 200) {
        final loginData = jsonDecode(loginResponse.body);
        bearerToken = loginData['data']['Bearer'];
        setState(() {
          _showPendingMessages = true;
        });

        print('\nToken obtenido: $bearerToken');

        await sendRequest();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              bearerToken: bearerToken,
              empresas: empresas,
              username: username,
              password: password,
            ),
          ),
        );
      } else {
        print('Error en login: ${loginResponse.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en login: ${loginResponse.statusCode}'),
          ),
        );
      }
    } catch (e) {
      print('Error de conexión en login: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión en login'),
        ),
      );
    }
  }

  Future<void> sendRequest() async {
    String listarUrl = "https://www.infocontrol.tech/web/api/mobile/empresas/listar";

    try {
      print('\nRealizando solicitud de empresas a: $listarUrl');
      print('Headers de la solicitud:');
      print({
        HttpHeaders.contentTypeHeader: "application/json",
        HttpHeaders.authorizationHeader: "Bearer $bearerToken",
        'Cookie': 'ci_session_infocontrolweb1=4ohde8tg4j314flf237b2v7c6l1u6a1i; cookie_sistema=9403e26ba93184a3aafc6dd61404daed'
      });

      final response = await http.get(
        Uri.parse(listarUrl),
        headers: {
          HttpHeaders.contentTypeHeader: "application/json",
          HttpHeaders.authorizationHeader: "Bearer $bearerToken",
          'Cookie': 'ci_session_infocontrolweb1=4ohde8tg4j314flf237b2v7c6l1u6a1i; cookie_sistema=9403e26ba93184a3aafc6dd61404daed'
        },
      );

      print('\nRespuesta del servidor (listar empresas):');
      print('Código de estado: ${response.statusCode}');
      print('Headers de respuesta:');
      response.headers.forEach((key, value) {
        print('$key: $value');
      });
      print('\nCuerpo de la respuesta:');
      print(response.body);
      
      try {
        print('\nRespuesta JSON parseada:');
        final parsedJson = jsonDecode(response.body);
        print(JsonEncoder.withIndent('  ').convert(parsedJson));
      } catch (e) {
        print('\nError al parsear JSON: $e');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        empresas = List<Map<String, dynamic>>.from(responseData['data']);

        await HiveHelper.insertEmpresas(empresas);

        setState(() {
          empresaNombre = empresas[0]['nombre'];
          empresaId = empresas[0]['id_empresa_asociada'];
        });

        print('\nEmpresas obtenidas:');
        print(JsonEncoder.withIndent('  ').convert(empresas));
      } else {
        print('Error en sendRequest: ${response.statusCode}');
      }
    } catch (e) {
      print('Error de conexión en sendRequest: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/background.png"),
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 40, right: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Image.asset('assets/flag_arg.png'),
                      iconSize: 40,
                      onPressed: () => _changeLanguage('es'),
                    ),
                    IconButton(
                      icon: Image.asset('assets/flag_us.png'),
                      iconSize: 40,
                      onPressed: () => _changeLanguage('en'),
                    ),
                    IconButton(
                      icon: Image.asset('assets/flag_br.png'),
                      iconSize: 40,
                      onPressed: () => _changeLanguage('pt'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Image.asset(
                  'assets/infocontrol_logo.png',
                  width: 165,
                ),
              ),
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      getText('login'),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      getText('subtitle'),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[200],
                        labelText: getText('userField'),
                        labelStyle: TextStyle(
                            fontFamily: 'Montserrat',
                            color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon:
                            Icon(Icons.person, color: Colors.black54),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[200],
                        labelText: getText('passwordField'),
                        labelStyle: TextStyle(
                            fontFamily: 'Montserrat',
                            color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon:
                            Icon(Icons.lock, color: Colors.black54),
                      ),
                      obscureText: true,
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _showPendingMessages,
                          onChanged: (bool? value) {
                            setState(() {
                              _showPendingMessages = value ?? false;
                            });
                          },
                        ),
                        SizedBox(width: 8),
                        Text(getText('rememberData'),
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                color: Colors.black54)),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {},
                        child: Text(
                          getText('forgotPassword'),
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            color: Colors.blue, 
                            ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => login(context),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: 40, vertical: 12),
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        getText('loginButton'),
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getText('promoTitle'),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      getText('promoSubtitle'),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: _launchURL,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3D77E9),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          getText('learnMore'),
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 40), // Espacio adicional al final para el scroll
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}