import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import './empresa_screen.dart';
import './lupa_empresa.dart';
import 'hive_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

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

  late Dio dio;
  late CookieJar cookieJar;

  @override
  void initState() {
    super.initState();
    bearerToken = widget.bearerToken;
    empresas = widget.empresas;
    empresasFiltradas = widget.empresas;

    cookieJar = CookieJar();
    dio = Dio();
    dio.interceptors.add(CookieManager(cookieJar));

    _startTokenRefreshTimer();
    _setupConnectivityListener();

    _updateDataFromServer();

    _searchController.addListener(_onSearchChanged);
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.none) {
        // Sin conexión cargamos locales
        _loadLocalData().then((_) {
          setState(() {
            _filterData();
            _isLoading = false;
          });
        });
      } else {
        // Con conexión refrescamos token y datos
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
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
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
      final response = await dio.post(
        "https://www.infocontrol.tech/web/api/mobile/service/login",
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization':
                'Basic ${base64Encode(utf8.encode('${widget.username}:${widget.password}'))}',
          },
        ),
        data: jsonEncode({
          'username': widget.username,
          'password': widget.password,
        }),
      );

      if (response.statusCode == 200) {
        final loginData = response.data;
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
    } on DioException catch (e) {
      print('Error al refrescar el token: $e');
      _showErrorSnackBar('Error al refrescar el token');
    } catch (e) {
      print('Error al refrescar el token: $e');
      _showErrorSnackBar('Error al refrescar el token');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadLocalData() async {
    try {
      List<Map<String, dynamic>> localEmpresas = HiveHelper.getEmpresas();
      List<Map<String, dynamic>> localGrupos = HiveHelper.getGrupos();

      empresas = localEmpresas;
      grupos = localGrupos;
      gruposFiltrados = localGrupos;
      empresasFiltradas = localEmpresas;
    } catch (e) {
      print('Error loading local data: $e');
      throw Exception('Error cargando datos locales');
    }
  }

  Future<void> _updateDataFromServer() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await dio.get(
        "https://www.infocontrol.tech/web/api/mobile/empresas/listar",
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $bearerToken',
          },
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = response.data;

        List<Map<String, dynamic>> empresasData =
            List<Map<String, dynamic>>.from(responseData['data']);

        Set<String> gruposUnicos = {};
        List<Map<String, dynamic>> gruposData = [];

        empresas.clear();
        empresasFiltradas.clear();
        grupos.clear();
        gruposFiltrados.clear();

        // Procesar grupos
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

        await HiveHelper.insertGrupos(gruposData);
        grupos = gruposData;
        gruposFiltrados = gruposData;

        // Obtener instalaciones por empresa
        for (var empresa in empresasData) {
          // Usaremos 'id_empresas' como identificador principal
          // para relacionar con instalaciones.
          final empresaId = empresa['id_empresas'];

          // Pedimos las instalaciones de esta empresa
          await _fetchAndStoreInstalaciones(empresaId);

          // Guardamos la empresa localmente
          await HiveHelper.insertEmpresas([empresa]);

          empresas.add(empresa);
          empresasFiltradas.add(empresa);

          setState(() {
            _isLoading = false;
            _filterData();
          });
        }

      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('Error updating server data: $e');
      throw Exception('Error actualizando datos del servidor');
    } catch (e) {
      print('Error updating server data: $e');
      throw Exception('Error actualizando datos del servidor');
    }
  }

  Future<void> _fetchAndStoreInstalaciones(String empresaId) async {
    try {
      final response = await dio.get(
        "https://www.infocontrol.tech/web/api/mobile/empresas/empresasinstalaciones?id_empresas=$empresaId",
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $bearerToken',
            'auth-type': 'no-auth',
          },
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        List<Map<String, dynamic>> instalaciones = [];

        if (responseData['data']['instalaciones'] != null) {
          instalaciones = List<Map<String, dynamic>>.from(
            responseData['data']['instalaciones'].map((instalacion) => {
                  'id_instalacion': instalacion['id_instalaciones'],
                  'nombre': instalacion['nombre'],
                  'id_empresas': instalacion['id_empresas'], // Vincula la instalación con la empresa
                }),
          );
        }

        // Guardar las instalaciones bajo la clave de esta empresa
        await HiveHelper.insertInstalaciones(empresaId, instalaciones);
      } else {
        throw Exception('Error al obtener instalaciones: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('Error fetching instalaciones: $e');
      throw Exception('Error obteniendo instalaciones');
    } catch (e) {
      print('Error fetching instalaciones: $e');
      throw Exception('Error obteniendo instalaciones');
    }
  }

  void navigateToEmpresaScreen(String empresaId, Map<String, dynamic> empresaData) {
    // Ahora pasamos empresaId = empresa['id_empresas'] (no 'id_empresa_asociada')
    // Para que en EmpresaScreen se filtren las instalaciones de esa empresa
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmpresaScreen(
          empresaId: empresaData['id_empresas'], // Usamos id_empresas
          bearerToken: bearerToken,
          empresaData: empresaData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Container(),
      ),
      body: _isLoading && empresas.isEmpty
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
                            // Llamamos con empresa['id_empresas'] como empresaId
                            navigateToEmpresaScreen(empresa['id_empresas'], empresa);
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
                                  backgroundImage: AssetImage('assets/company_logo.png'),
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
}