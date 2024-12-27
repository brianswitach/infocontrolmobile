import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'hive_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

// Eliminamos import de empresa_screen.dart
// import './empresa_screen.dart';

// Importamos lupa_empresa.dart para ir directo a LupaEmpresaScreen
import './lupa_empresa.dart';

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

  String id_empresas = "";

  // Control de expansión de grupos
  Map<String, bool> _expandedGroups = {};

  @override
  void initState() {
    super.initState();

    // Recibimos el token inicial y la lista de empresas, username y password
    bearerToken = widget.bearerToken;
    empresas = widget.empresas;
    empresasFiltradas = widget.empresas;

    cookieJar = CookieJar();
    dio = Dio();
    dio.interceptors.add(CookieManager(cookieJar));

    // Guardamos el token inicial en Hive (para offline si se requiere)
    HiveHelper.storeBearerToken(bearerToken);

    // Inicia la rutina de refresco cada 4min 10s (250s aprox)
    _startTokenRefreshTimer();
    _setupConnectivityListener();
    _updateDataFromServer();
    _searchController.addListener(_onSearchChanged);
  }

  // Configura oyente de conectividad
  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.none) {
        // No hay conexión -> cargamos datos locales
        _loadLocalData().then((_) {
          if (!mounted) return;
          setState(() {
            _filterData();
            _isLoading = false;
          });
        });
      } else {
        // Hay conexión -> refrescar token
        _refreshBearerToken();
      }
    });
  }

  // Cada vez que cambie el texto de búsqueda, filtramos
  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _searchQuery = query;
      _filterData();
    });
  }

  // Filtra empresas y grupos según el texto de _searchQuery
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

  // Inicia el Timer para refrescar el token cada 4min 10s (250s)
  void _startTokenRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(minutes: 4, seconds: 10),
      (_) => _refreshBearerToken(),
    );
  }

  // Lógica de refresco del token usando username y password
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
            'Authorization': 'Basic ${base64Encode(utf8.encode('${widget.username}:${widget.password}'))}',
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
            // Actualizamos la variable local para que
            // se pase correctamente a LupaEmpresaScreen
            bearerToken = newToken;
          });
        }

        // Guardamos el nuevo token en Hive (para offline)
        await HiveHelper.storeBearerToken(newToken);

        // Volvemos a actualizar datos con el nuevo token
        await _updateDataFromServer();
      } else {
        throw Exception('Error al actualizar el token: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al refrescar el token: $e');
      _showErrorSnackBar('Error al refrescar el token');
    }
  }

  // Muestra un snackBar en caso de error
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Carga datos locales (empresas, grupos) si no hay internet
  Future<void> _loadLocalData() async {
    try {
      List<Map<String, dynamic>> localEmpresas = HiveHelper.getEmpresas();
      localEmpresas = localEmpresas.map((e) => Map<String,dynamic>.from(e)).toList();

      List<Map<String, dynamic>> localGrupos = HiveHelper.getGrupos();
      localGrupos = localGrupos.map((e) => Map<String,dynamic>.from(e)).toList();

      empresas = localEmpresas;
      grupos = localGrupos;
      gruposFiltrados = localGrupos;
      empresasFiltradas = localEmpresas;
    } catch (e) {
      print('Error loading local data: $e');
      throw Exception('Error cargando datos locales');
    }
  }

  // Actualiza datos desde el servidor usando siempre el token actual (bearerToken)
  Future<void> _updateDataFromServer() async {
    if (!mounted) return;
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
            List<Map<String, dynamic>>.from(responseData['data'].map((e) => Map<String,dynamic>.from(e)));

        Set<String> gruposUnicos = {};
        List<Map<String, dynamic>> gruposData = [];

        empresas.clear();
        empresasFiltradas.clear();
        grupos.clear();
        gruposFiltrados.clear();

        // Agrupamos según "grupo"
        for (var empresa in empresasData) {
          String? grupoNombre = empresa['grupo'];
          String? grupoId = empresa['id_grupos'];

          if (grupoNombre != null && grupoNombre.isNotEmpty && grupoId != null && grupoId.isNotEmpty) {
            if (!gruposUnicos.contains(grupoId)) {
              gruposUnicos.add(grupoId);
              gruposData.add({
                'id': grupoId,
                'nombre': grupoNombre,
              });
            }
          }
        }

        // Guardamos en Hive para offline
        await HiveHelper.insertGrupos(gruposData);
        gruposData = gruposData.map((g) => Map<String,dynamic>.from(g)).toList();
        grupos = gruposData;
        gruposFiltrados = gruposData;

        await HiveHelper.insertEmpresas(empresasData);
        empresasData = empresasData.map((e) => Map<String,dynamic>.from(e)).toList();
        empresas = empresasData;
        empresasFiltradas = empresasData;

        // Control de grupos expandibles
        _expandedGroups.clear();
        for (var g in grupos) {
          _expandedGroups[g['id']] = false;
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
            _filterData();
          });
        }

        _prefetchInstallationsInBackground();
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating server data: $e');
      _showErrorSnackBar('Error al actualizar datos del servidor');
      await _loadLocalData();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _filterData();
        });
      }
    }
  }

  // Prefetch instalaciones en segundo plano, usando siempre bearerToken actual
  Future<void> _prefetchInstallationsInBackground() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return;
    }

    List<Map<String, dynamic>> empresasSinInstalaciones = [];
    for (var empresa in empresas) {
      String eId = empresa['id_empresas'].toString();
      List<Map<String, dynamic>> instLocal = HiveHelper.getInstalaciones(eId);
      instLocal = instLocal.map((ee) => Map<String,dynamic>.from(ee)).toList();

      if (instLocal.isEmpty) {
        empresasSinInstalaciones.add(empresa);
      }
    }

    int batchSize = 5;
    for (int i = 0; i < empresasSinInstalaciones.length; i += batchSize) {
      final batch = empresasSinInstalaciones.skip(i).take(batchSize).toList();
      await Future.wait(batch.map((emp) => _fetchAndStoreInstalaciones(emp['id_empresas'].toString())));
    }
  }

  // Descarga e inserta instalaciones de una empresa específica, usando bearerToken actual
  Future<void> _fetchAndStoreInstalaciones(String empresaId) async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return;
    }

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
        List<Map<String, dynamic>> instalacionesData = [];
        if (responseData['data']['instalaciones'] != null) {
          instalacionesData = List<Map<String, dynamic>>.from(
            responseData['data']['instalaciones'].map((inst) => Map<String,dynamic>.from(inst))
          );
        }

        instalacionesData = instalacionesData.where((inst) => inst['id_empresas'].toString() == empresaId).toList();

        if (instalacionesData.isNotEmpty) {
          await HiveHelper.insertInstalaciones(empresaId, instalacionesData);
        }
      }
    } catch (e) {
      print('Error fetching installations in background for empresa $empresaId: $e');
    }
  }

  // Badge para mostrar tipo de cliente (directo=Integral, renting=Renting)
  Widget _buildTipoClienteBadge(String tipoCliente) {
    final text = tipoCliente == 'directo' ? 'Integral' : 'Renting';
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFE2EAFB),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 11,
          color: Color(0xFF2a3666),
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildEmpresaAvatar(String? nombreEmpresa) {
    String inicial = 'E';
    if (nombreEmpresa != null && nombreEmpresa.isNotEmpty) {
      inicial = nombreEmpresa[0].toUpperCase();
    }
    return CircleAvatar(
      backgroundColor: Color(0xFF2a3666),
      radius: 15,
      child: Text(
        inicial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildGrupoAvatar(String? nombreGrupo) {
    String inicial = 'G';
    if (nombreGrupo != null && nombreGrupo.isNotEmpty) {
      inicial = nombreGrupo[0].toUpperCase();
    }
    return CircleAvatar(
      backgroundColor: Color(0xFF2a3666),
      radius: 15,
      child: Text(
        inicial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getEmpresasDelGrupo(String grupoId) {
    return empresas.where((emp) =>
      emp['id_grupos'] == grupoId &&
      emp['grupo'] != null &&
      emp['grupo'].toString().isNotEmpty
    ).toList();
  }

  List<Map<String, dynamic>> _getEmpresasSinGrupo() {
    return empresas.where((emp) =>
      emp['grupo'] == null || emp['grupo'].toString().trim().isEmpty
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Filtra las empresas sin grupo que coincidan con la búsqueda
    List<Map<String, dynamic>> empresasSinGrupoFiltradas = _getEmpresasSinGrupo();
    if (_searchQuery.isNotEmpty) {
      empresasSinGrupoFiltradas = empresasSinGrupoFiltradas.where((empresa) {
        return empresa['nombre']
            .toString()
            .toLowerCase()
            .startsWith(_searchQuery);
      }).toList();
    }

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
                            decoration: TextDecoration.none,
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
                            decoration: TextDecoration.none,
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
                      SizedBox(height: 20),
                      Text(
                        'Empresas',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Todas las empresas:',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          color: Colors.black,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: 20),
                      for (var empresa in empresasSinGrupoFiltradas)
                        GestureDetector(
                          onTap: () {
                            // Vamos directo a LupaEmpresaScreen
                            id_empresas = empresa['id_empresas'].toString();
                            final String idEmpresaAsociada =
                                empresa['id_empresa_asociada']?.toString() ?? '';

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LupaEmpresaScreen(
                                  empresa: empresa,
                                  bearerToken: bearerToken,
                                  idEmpresaAsociada: idEmpresaAsociada,
                                  empresaId: id_empresas,
                                  // AÑADIMOS username y password para no romper la firma
                                  username: widget.username,
                                  password: widget.password,
                                ),
                              ),
                            );
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
                                _buildEmpresaAvatar(empresa['nombre']),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    empresa['nombre'] ?? 'Empresa sin nombre',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 16,
                                      color: Colors.black,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                _buildTipoClienteBadge(empresa['tipo_cliente'] ?? ''),
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
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Todos los grupos:',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          color: Colors.black,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: 20),
                      for (var grupo in gruposFiltrados)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _expandedGroups[grupo['id']] = !_expandedGroups[grupo['id']]!;
                                });
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
                                    _buildGrupoAvatar(grupo['nombre']),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Grupo ${grupo['nombre']}",
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 16,
                                          color: Colors.black,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _expandedGroups[grupo['id']]! ? Icons.expand_less : Icons.expand_more,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_expandedGroups[grupo['id']]!)
                              Padding(
                                padding: const EdgeInsets.only(left: 16, bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var emp in _getEmpresasDelGrupo(grupo['id']))
                                      GestureDetector(
                                        onTap: () {
                                          id_empresas = emp['id_empresas'].toString();
                                          final String idEmpresaAsociada =
                                              emp['id_empresa_asociada']?.toString() ?? '';

                                          // Vamos directo a LupaEmpresaScreen
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => LupaEmpresaScreen(
                                                empresa: emp,
                                                bearerToken: bearerToken,
                                                idEmpresaAsociada: idEmpresaAsociada,
                                                empresaId: id_empresas,
                                                username: widget.username,
                                                password: widget.password,
                                              ),
                                            ),
                                          );
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
                                              _buildEmpresaAvatar(emp['nombre']),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  emp['nombre'] ?? 'Empresa sin nombre',
                                                  style: TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 16,
                                                    color: Colors.black,
                                                    decoration: TextDecoration.none,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              _buildTipoClienteBadge(emp['tipo_cliente'] ?? ''),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
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
