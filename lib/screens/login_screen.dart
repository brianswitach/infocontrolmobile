import 'dart:convert';
import 'package:flutter/material.dart';
import './home_screen.dart';
import 'hive_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String bearerToken = "";
  String id_usuarios = ""; // Variable para almacenar el id_usuarios obtenido del login
  String _language = 'es'; // Solo idioma español
  bool _showPendingMessages = false;
  List<Map<String, dynamic>> empresas = [];
  String? empresaNombre;
  String? empresaId;
  final ScrollController _scrollController = ScrollController();

  late Dio dio;
  late CookieJar cookieJar;

  @override
  void initState() {
    super.initState();
    _usernameController.text = '';
    _passwordController.text = '';

    // Configuración de Dio + CookieJar
    cookieJar = CookieJar();
    dio = Dio();
    dio.interceptors.add(CookieManager(cookieJar));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
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

    return _spanishText[key] ?? '';
  }

  Future<void> login(BuildContext context) async {
    // Mostrar el diálogo de "Cargando..."
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text(
                'Cargando...',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: Colors.black,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    String loginUrl = "https://www.infocontrol.tech/web/api/mobile/service/login"; 
    String username = _usernameController.text;
    String password = _passwordController.text;
    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$username:$password'));

    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        // SIN CONEXIÓN: Comprobamos credenciales offline
        Navigator.pop(context); // Cerramos el diálogo de "Cargando..."

        // Recuperamos username y password guardados en Hive
        final storedUser = HiveHelper.getUsernameOffline();
        final storedPass = HiveHelper.getPasswordOffline();

        if (storedUser == username && storedPass == password) {
          // Coinciden: Buscamos empresas locales
          List<Map<String, dynamic>> localEmpresas = HiveHelper.getEmpresas();
          if (localEmpresas.isNotEmpty) {
            // Hay datos locales, navegamos
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
            // No hay empresas guardadas
            _showAlertDialog(context, 'No hay conexión y no hay datos locales disponibles.');
          }
        } else {
          // Credenciales incorrectas en modo offline
          _showAlertDialog(context, 'Credenciales incorrectas en modo offline.');
        }
        return;
      }

      // CON CONEXIÓN: Intentamos login con el servidor
      final loginResponse = await dio.post(
        loginUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': basicAuth,
          },
        ),
        data: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final statusCode = loginResponse.statusCode;
      final responseData = loginResponse.data;

      if (statusCode == 200) {
        bearerToken = responseData['data']['Bearer'];

        // Guardar id_usuarios en variable local
        id_usuarios = responseData['data']['userData']['id_usuarios'] ?? '';
        // Guardar id_usuarios en Hive
        await HiveHelper.storeIdUsuarios(id_usuarios);

        // GUARDAMOS username y password OFFLINE
        await HiveHelper.storeUsernameOffline(username);
        await HiveHelper.storePasswordOffline(password);

        setState(() {
          _showPendingMessages = true;
        });

        await sendRequest();

        // Cerrar el dialogo de "Cargando..." antes de navegar
        Navigator.pop(context);

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
      } else if (statusCode == 404) {
        // Cerrar el dialogo de "Cargando..."
        Navigator.pop(context);
        _showAlertDialog(context, 'Usuario o Contraseña incorrectos');
      } else {
        // Cerrar el dialogo de "Cargando..."
        Navigator.pop(context);
        _showAlertDialog(context, 'Usuario o Contraseña incorrectos');
      }
    } on DioException catch (e) {
      // Cerrar el dialogo de "Cargando..."
      Navigator.pop(context);
      _showAlertDialog(context, 'Error de conexión en login');
    } catch (e) {
      // Cerrar el dialogo de "Cargando..."
      Navigator.pop(context);
      _showAlertDialog(context, 'Error de conexión en login');
    }
  }

  Future<void> sendRequest() async {
    String listarUrl = "https://www.infocontrol.tech/web/api/mobile/empresas/listar";

    try {
      final response = await dio.get(
        listarUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $bearerToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        empresas = List<Map<String, dynamic>>.from(responseData['data']);

        await HiveHelper.insertEmpresas(empresas);

        setState(() {
          empresaNombre = empresas.isNotEmpty ? empresas[0]['nombre'] : null;
          empresaId = empresas.isNotEmpty ? empresas[0]['id_empresa_asociada'] : null;
        });
      } else {
        print('Error en sendRequest: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('Error de conexión en sendRequest: $e');
    } catch (e) {
      print('Error inesperado en sendRequest: $e');
    }
  }

  void _showAlertDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Atención'),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _launchForgotPassword() async {
    final url = 'https://www.infocontrol.tech/web/usuarios/recuperar_contrasena?lg=arg';
    await _launchURL(url);
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
                padding: const EdgeInsets.only(bottom: 20, top: 60),
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
                        decoration: TextDecoration.none,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      getText('subtitle'),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        color: Colors.black54,
                        decoration: TextDecoration.none,
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
                          color: Colors.black54,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.person, color: Colors.black54),
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
                          color: Colors.black54,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.lock, color: Colors.black54),
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
                        Text(
                          getText('rememberData'),
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            color: Colors.black54,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _launchForgotPassword,
                        child: Text(
                          getText('forgotPassword'),
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            color: Colors.blue,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => login(context),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 12,
                        ),
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
                          decoration: TextDecoration.none,
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
                        decoration: TextDecoration.none,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      getText('promoSubtitle'),
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        color: Colors.white70,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => _launchURL('https://www.infocontrolweb.com/inteligencia_artificial'),
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
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
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
