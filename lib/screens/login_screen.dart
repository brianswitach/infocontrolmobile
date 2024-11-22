import 'dart:convert';
import 'package:flutter/material.dart';
import './home_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import './hive_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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

  @override
  void initState() {
    super.initState();
    _usernameController.text = 'API.30511190238';
    _passwordController.text = 'Inf0C0ntr0l2023';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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
    String loginUrl = "https://www.infocontrol.com.ar/desarrollo_v2/api/web/workers/login";
    String username = _usernameController.text;
    String password = _passwordController.text;
    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));

    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        // Sin conexión, intentar cargar datos locales
        List<Map<String, dynamic>> localEmpresas = HiveHelper.getEmpresas();

        if (localEmpresas.isNotEmpty) {
          // Si hay datos locales, continuar a HomeScreen
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
          // No hay datos locales y no hay conexión
          print('No hay conexión y no hay datos locales disponibles.');
          // Mostrar mensaje al usuario
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No hay conexión y no hay datos locales disponibles.'),
            ),
          );
        }
        return;
      }

      final loginResponse = await http.post(
        Uri.parse(loginUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': basicAuth,
        },
      );

      if (loginResponse.statusCode == 200) {
        final loginData = jsonDecode(loginResponse.body);
        bearerToken = loginData['data']['Bearer'];
        setState(() {
          _showPendingMessages = true;
        });

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
        // Manejar error de login si es necesario
        print('Error en login: ${loginResponse.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en login: ${loginResponse.statusCode}'),
          ),
        );
      }
    } catch (e) {
      // Manejar error de conexión si es necesario
      print('Error de conexión en login: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión en login'),
        ),
      );
    }
  }

  Future<void> sendRequest() async {
    String listarUrl = "https://www.infocontrol.com.ar/desarrollo_v2/api/mobile/empresas/listar";

    try {
      final response = await http.get(
        Uri.parse(listarUrl),
        headers: {
          HttpHeaders.contentTypeHeader: "application/json",
          HttpHeaders.authorizationHeader: "Bearer $bearerToken",
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        empresas = List<Map<String, dynamic>>.from(responseData['data']);

        // Guardar en Hive
        await HiveHelper.insertEmpresas(empresas);

        // Guardamos el nombre y el ID de la primera empresa en la lista
        setState(() {
          empresaNombre = empresas[0]['nombre'];
          empresaId = empresas[0]['id_empresa_asociada'];
        });
      } else {
        // Manejar error de solicitud si es necesario
        print('Error en sendRequest: ${response.statusCode}');
      }
    } catch (e) {
      // Manejar error de conexión si es necesario
      print('Error de conexión en sendRequest: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: constraints.maxHeight < 600
                ? AlwaysScrollableScrollPhysics()
                : NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}