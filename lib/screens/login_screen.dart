import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _language = 'es'; // Idioma predeterminado: español

  void _changeLanguage(String language) {
    setState(() {
      _language = language;
    });
  }

  String getText(String key) {
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

  // Diccionarios de textos para cada idioma
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

  // Función para abrir el enlace en el navegador
  Future<void> _launchURL() async {
  final Uri url = Uri.parse('https://www.infocontrolweb.com/inteligencia_artificial');
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    print('Error al abrir el enlace $url');
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/background.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Íconos de bandera para cambiar de idioma
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
            // Logo Infocontrol
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Image.asset(
                'assets/infocontrol_logo.png',
                width: 165,
              ),
            ),
            // Cuadro de inicio de sesión
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
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[200],
                      labelText: getText('userField'),
                      labelStyle: TextStyle(fontFamily: 'Montserrat', color: Colors.black54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.person, color: Colors.black54),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[200],
                      labelText: getText('passwordField'),
                      labelStyle: TextStyle(fontFamily: 'Montserrat', color: Colors.black54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.lock, color: Colors.black54),
                    ),
                    obscureText: true,
                  ),
                  SizedBox(height: 16),
                  // Recordar datos y olvidaste tu contraseña
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 20,
                            width: 20,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.black54, width: 1),
                            ),
                            child: Checkbox(
                              value: false,
                              onChanged: (value) {},
                              activeColor: Colors.grey,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(getText('rememberData'), style: TextStyle(fontFamily: 'Montserrat', color: Colors.black54)),
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
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
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
            // Cuadro promocional
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
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _launchURL,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      getText('learnMore'),
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
          ],
        ),
      ),
    );
  }
}
