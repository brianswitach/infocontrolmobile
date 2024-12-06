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
  List<Map<String, dynamic>> gruposFiltrados = [];
  List<Map<String, dynamic>> grupos = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> empresasFiltradas = [];

  @override
  void initState() {
    super.initState();
    bearerToken = widget.bearerToken;
    empresas = widget.empresas;
    empresasFiltradas = widget.empresas;
    _startTokenRefreshTimer();
    _initializeData();
    _setupConnectivityListener();
    _searchController.addListener(_onSearchChanged);
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.none) {
        _loadLocalData();
      } else {
        _refreshBearerToken();
      }
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _searchQuery = query;
      _filterData();
    });
  }

  void _filterData() {
    setState(() {
      if (_searchQuery.isEmpty) {
        empresasFiltradas = List.from(empresas);
        gruposFiltrados = List.from(grupos);
        return;
      }
      empresasFiltradas = empresas.where((empresa) {
        return empresa['nombre']
            .toString()
            .toLowerCase()
            .startsWith(_searchQuery);
      }).toList();
      gruposFiltrados = grupos.where((grupo) {
        return grupo['nombre']
            .toString()
            .toLowerCase()
            .startsWith(_searchQuery);
      }).toList();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      await _loadLocalData();
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        await _updateDataFromServer();
      }
    } catch (e) {
      print('Error initializing data: $e');
      if (empresas.isEmpty) {
        _showErrorSnackBar('Error cargando datos: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _filterData();
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _startTokenRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(minutes: 4, seconds: 50),
      (_) => _refreshBearerToken(),
    );
  }

  Future<void> _refreshBearerToken() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('No hay conexión. No se puede refrescar el token.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("https://www.infocontrol.tech/web/api/web/workers/login"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('${widget.username}:${widget.password}'))}',
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
        
        if (mounted) {
          setState(() {
            bearerToken = newToken;
          });
        }
        await _updateDataFromServer();
      } else {
        throw Exception('Error al actualizar el token: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al refrescar el token: $e');
      _showErrorSnackBar('Error al refrescar el token');
    }
  }

  Future<void> _loadLocalData() async {
    try {
      List<Map<String, dynamic>> localEmpresas = HiveHelper.getEmpresas();
      List<Map<String, dynamic>> localGrupos = HiveHelper.getGrupos();
      
      if (mounted) {
        setState(() {
          empresas = localEmpresas;
          grupos = localGrupos;
          gruposFiltrados = localGrupos;
        });
      }
    } catch (e) {
      print('Error loading local data: $e');
      throw Exception('Error cargando datos locales');
    }
  }

  Future<void> _updateDataFromServer() async {
    try {
      final response = await http.get(
        Uri.parse("https://www.infocontrol.tech/web/api/mobile/empresas/listar"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
          'Cookie': 'ci_session_infocontrolweb1=4ohde8tg4j314flf237b2v7c6l1u6a1i; cookie_sistema=9403e26ba93184a3aafc6dd61404daed'
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        List<Map<String, dynamic>> empresasData = List<Map<String, dynamic>>.from(responseData['data']);
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

        List<Future<void>> instalacionesFutures = [];
        for (var empresa in empresasData) {
          instalacionesFutures.add(
            _fetchAndStoreInstalaciones(empresa['id_empresa_asociada'])
              .catchError((e) => print('Error fetching instalaciones: $e'))
          );
        }
        await Future.wait(instalacionesFutures);

        if (mounted) {
          setState(() {
            empresas = empresasData;
            empresasFiltradas = empresasData;
            grupos = gruposData;
            gruposFiltrados = gruposData;
            _filterData();
          });
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating server data: $e');
      throw Exception('Error actualizando datos del servidor');
    }
  }

  Future<void> _fetchAndStoreInstalaciones(String empresaId) async {
    try {
      final response = await http.get(
        Uri.parse("https://www.infocontrol.tech/web/api/mobile/empresas/empresasinstalaciones?id_empresas=$empresaId"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $bearerToken',
          'auth-type': 'no-auth',
          'Cookie': 'ci_session_infocontrolweb1=4ohde8tg4j314flf237b2v7c6l1u6a1i; cookie_sistema=9403e26ba93184a3aafc6dd61404daed'
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        List<Map<String, dynamic>> instalaciones = [];
        
        if (responseData['data']['instalaciones'] != null) {
          instalaciones = List<Map<String, dynamic>>.from(
            responseData['data']['instalaciones'].map((instalacion) => {
              'id_instalacion': instalacion['id_instalacion'],
              'nombre': instalacion['nombre'],
            })
          );
        }

        await HiveHelper.insertInstalaciones(empresaId, instalaciones);
      } else {
        throw Exception('Error al obtener instalaciones: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching instalaciones: $e');
      throw Exception('Error obteniendo instalaciones');
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
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2a3666)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _updateDataFromServer,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
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
                          style: TextStyle(color: Color(0xFF363f77),
                            fontFamily: 'Montserrat',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _searchController,
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
                      for (var empresa in empresasFiltradas)
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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
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
                      for (var grupo in gruposFiltrados)
                        Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(12),
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
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