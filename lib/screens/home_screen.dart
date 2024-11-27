import 'package:flutter/material.dart';
import './empresa_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import './lupa_empresa.dart';
import 'dart:async';
import 'hive_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class HomeScreen extends StatefulWidget {
  final String bearerToken;
  final List<Map<String, dynamic>> empresas;
  final String username;
  final String password;

  HomeScreen({
    required this.bearerToken,
    required this.empresas,
    required this.username,
    required this.password,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showPendingMessages = false;
  late String bearerToken;
  Timer? _refreshTimer;
  List<Map<String, dynamic>> empresas = [];
  List<Map<String, dynamic>> grupos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    bearerToken = widget.bearerToken;
    empresas = widget.empresas;
    _startTokenRefreshTimer();
    _initializeData();

    Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) {
        if (result == ConnectivityResult.none) {
          _loadLocalData();
        } else {
          _refreshBearerToken();
        }
      },
    );
  }

  Future<void> _initializeData() async {
    await _loadLocalData();
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await _updateDataFromServer();
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startTokenRefreshTimer() {
    _refreshTimer = Timer.periodic(
      Duration(seconds: 290),
      (_) {
        _refreshBearerToken();
      },
    );
  }

  Future<void> _refreshBearerToken() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('No hay conexión. No se puede refrescar el token.');
      return;
    }

    try {
      String loginUrl = "https://www.infocontrol.tech/web/api/web/workers/login";
      String basicAuth = 'Basic ' +
          base64Encode(utf8.encode('${widget.username}:${widget.password}'));

      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': basicAuth,
          'Cookie': 'ci_session_infocontrolweb1=4ohde8tg4j314flf237b2v7c6l1u6a1i; cookie_sistema=9403e26ba93184a3aafc6dd61404daed'
        },
        body: jsonEncode({
          'username': widget.username,
          'password': widget.password,
        }),
      );

      if (response.statusCode == 200) {
        final loginData = jsonDecode(response.body);
        String newToken = loginData['data']['Bearer'];
        setState(() {
          bearerToken = newToken;
        });
        print('Token actualizado');

        await _updateDataFromServer();
      } else {
        print('Error al actualizar el token: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al refrescar el token: $e');
    }
  }

  Future<void> _loadLocalData() async {
    List<Map<String, dynamic>> localEmpresas = HiveHelper.getEmpresas();
    List<Map<String, dynamic>> localGrupos = HiveHelper.getGrupos();
    
    setState(() {
      empresas = localEmpresas;
      grupos = localGrupos;
    });
  }

  Future<void> _updateDataFromServer() async {
    String listarUrl = "https://www.infocontrol.tech/web/api/mobile/empresas/listar";

    try {
      final response = await http.get(
        Uri.parse(listarUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
          'Cookie': 'ci_session_infocontrolweb1=4ohde8tg4j314flf237b2v7c6l1u6a1i; cookie_sistema=9403e26ba93184a3aafc6dd61404daed'
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        List<Map<String, dynamic>> empresasData =
            List<Map<String, dynamic>>.from(responseData['data']);

        // Extraer grupos únicos
        Set<String> gruposUnicos = {};
        List<Map<String, dynamic>> gruposData = [];
        
        for (var empresa in empresasData) {
          String? grupoNombre = empresa['grupo'];
          String? grupoId = empresa['id_grupos'];
          
          if (grupoNombre != null && grupoId != null && !gruposUnicos.contains(grupoId)) {
            gruposUnicos.add(grupoId);
            gruposData.add({
              'id': grupoId,
              'nombre': grupoNombre,
            });
          }
        }

        await HiveHelper.insertEmpresas(empresasData);
        await HiveHelper.insertGrupos(gruposData);

        // Descargar instalaciones para todas las empresas
        for (var empresa in empresasData) {
          String empresaId = empresa['id_empresa_asociada'];
          await _fetchAndStoreInstalaciones(empresaId);
        }

        setState(() {
          empresas = empresasData;
          grupos = gruposData;
        });
      } else {
        print('Error al obtener empresas: ${response.statusCode}');
      }
    } catch (e) {
      print('Error de conexión al actualizar datos: $e');
    }
  }

  Future<void> _fetchAndStoreInstalaciones(String empresaId) async {
    String url = "https://www.infocontrol.tech/web/api/mobile/empresas/empresasinstalaciones?id_empresas=$empresaId";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
          'auth-type': 'no-auth',
          'Cookie': 'ci_session_infocontrolweb1=4ohde8tg4j314flf237b2v7c6l1u6a1i; cookie_sistema=9403e26ba93184a3aafc6dd61404daed'
        },
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        List<Map<String, dynamic>> instalaciones = [];
        
        if (responseData['data']['instalaciones'] != null) {
          for (var instalacion in responseData['data']['instalaciones']) {
            instalaciones.add({
              'id_instalacion': instalacion['id_instalacion'],
              'nombre': instalacion['nombre'],
            });
          }
        }

        await HiveHelper.insertInstalaciones(empresaId, instalaciones);
      } else {
        print('Error al obtener instalaciones para empresa $empresaId: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al obtener instalaciones para empresa $empresaId: $e');
    }
  }

  void navigateToEmpresaScreen(String empresaId, Map<String, dynamic> empresaData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmpresaScreen(
          empresaId: empresaId,
          bearerToken: bearerToken,
          empresaData: empresaData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.notifications, color: Color(0xFF2a3666)),
                onPressed: () {},
                constraints: BoxConstraints(),
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
              IconButton(
                icon: Icon(Icons.message, color: Color(0xFF2a3666)),
                onPressed: () {},
                constraints: BoxConstraints(),
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
              IconButton(
                icon: Icon(Icons.settings, color: Color(0xFF2a3666)),
                onPressed: () {},
                constraints: BoxConstraints(),
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
              IconButton(
                icon: Icon(Icons.people, color: Color(0xFF2a3666)),
                onPressed: () {},
                constraints: BoxConstraints(),
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
              IconButton(
                icon: Icon(Icons.info, color: Color(0xFF2a3666)),
                onPressed: () {},
                constraints: BoxConstraints(),
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ),
        ),
      ),
      drawer: Drawer(
        child: Container(
          color: Color(0xFF232e5f),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: EdgeInsets.only(top: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/infocontrol_logo.png',
                        width: 200,
                      ),
                    ),
                    SizedBox(height: 25),
                    Center(
                      child: Text(
                        widget.username,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 20,
                          color: Color(0xFF3d77e9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Center(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: Text(
                    'Seleccionar empresa',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30),
              _buildDrawerItem(Icons.home, 'Inicio'),
              _buildDrawerItem(Icons.settings, 'Configuración'),
              _buildDrawerItem(Icons.swap_horiz, 'Control de Cambios'),
              _buildDrawerItem(Icons.message, 'Mensajes'),
              _buildDrawerItem(Icons.link, 'Vinculación de Contratistas'),
              _buildDrawerItem(Icons.lock, 'Accesos Restringidos'),
              _buildDrawerItem(Icons.history, 'Historial de Contratistas'),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Container(
                color: Color(0xFFF1F3FF),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Derivador de empresas',
                        style: TextStyle(
                          color: Color(0xFF86aefe),
                          fontFamily: 'Montserrat',
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    Center(
                      child: Text(
                        'Seleccione una opción para continuar',
                        style: TextStyle(
                          color: Color(0xFF363f77),
                          fontFamily: 'Montserrat',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search, color: Color(0xFF363f77)),
                        hintText: 'Buscar empresa o grupo',
                        hintStyle: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
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
                        Text(
                          'Ver pendientes y mensajes',
                          style: TextStyle(
                            color: Color(0xFF363f77),
                            fontFamily: 'Montserrat',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Empresas',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Todas las empresas:',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 20),
                    for (var empresa in empresas)
                      GestureDetector(
                        onTap: () {
                          navigateToEmpresaScreen(
                              empresa['id_empresa_asociada'], empresa);
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(12),
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Color(0xFF2a3666),
                                radius: 15,
                                backgroundImage:
                                    AssetImage('assets/company_logo.png'),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  empresa['nombre'] ?? 'Empresa sin nombre',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Image.asset(
                                'assets/integral_icon.png',
                                width: 50,
                              ),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(height: 30),
                    Text(
                      'Grupos',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Todos los grupos:',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 20),
                    for (var grupo in grupos)
                      Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(12),
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Color(0xFF2a3666),
                              radius: 15,
                              child: Text(
                                grupo['nombre'].toString().isNotEmpty 
                                    ? grupo['nombre'][0].toUpperCase()
                                    : 'G',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                grupo['nombre'] ?? 'Grupo sin nombre',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Image.asset(
                              'assets/integral_icon.png',
                              width: 50,
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  ListTile _buildDrawerItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 16,
          color: Colors.white,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }
}