import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:hive/hive.dart'; // <--- Import necesario para usar Hive localmente
import './lupa_empresa.dart';
import 'hive_helper.dart';
import 'package:path_provider/path_provider.dart';

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
  // Eliminamos _showPendingMessages (unused_field) si ya no se usa
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

    // Inicializamos Hive
    _initHive();

    // Recibimos el token inicial y la lista de empresas
    bearerToken = widget.bearerToken;
    empresas = widget.empresas;
    empresasFiltradas = widget.empresas;

    cookieJar = CookieJar();
    dio = Dio();
    dio.interceptors.add(CookieManager(cookieJar));

    // Guardamos el token inicial en Hive (para offline)
    HiveHelper.storeBearerToken(bearerToken);

    // Inicia la rutina de refresco cada 4min 10s (250s aprox)
    _startTokenRefreshTimer();

    // Chequeamos la conexión ANTES de todo
    _checkConnectionAndLoadData();

    // Configuramos el listener de conectividad
    _setupConnectivityListener();

    // Escuchamos cambios en el texto de búsqueda
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initHive() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);
  }

  // ---------------------------------------------
  // DETECTA SI HAY CONEXIÓN Y CARGA DATOS
  // ---------------------------------------------
  Future<void> _checkConnectionAndLoadData() async {
    final connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      // No hay conexión -> cargamos datos locales
      await _loadLocalData();
      if (!mounted) return;
      setState(() {
        _filterData();
        _isLoading = false;
      });
    } else {
      // Hay conexión -> traemos datos del servidor
      _updateDataFromServer();
    }
  }

  // ---------------------------------------------
  // LISTENER DE CONECTIVIDAD
  // ---------------------------------------------
  void _setupConnectivityListener() {
    Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) async {
      if (result == ConnectivityResult.none) {
        // No hay conexión -> cargamos datos locales
        await _loadLocalData();
        if (!mounted) return;
        setState(() {
          _filterData();
          _isLoading = false;
        });
      } else {
        // Hay conexión -> refrescar token (y traer data si corresponde)
        await _refreshBearerToken();
      }
    });
  }

  // ---------------------------------------------
  // MANEJO DE BÚSQUEDAS
  // ---------------------------------------------
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
      final nombre = (empresa['nombre'] ?? '').toString().toLowerCase();
      return nombre.startsWith(_searchQuery);
    }).toList();

    gruposFiltrados = grupos.where((grupo) {
      final gNombre = (grupo['nombre'] ?? '').toString().toLowerCase();
      return gNombre.startsWith(_searchQuery);
    }).toList();
  }

  // ---------------------------------------------
  // DISPOSE
  // ---------------------------------------------
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------
  // RUTINA PARA REFRESCAR TOKEN
  // ---------------------------------------------
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
        // Si no puede ser nulo, quitamos ?? ''
        String newToken = (loginData['data']['Bearer']).toString();

        if (mounted) {
          setState(() {
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

  // ---------------------------------------------
  // SNACK BAR DE ERROR
  // ---------------------------------------------
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ---------------------------------------------
  // CARGA DATOS LOCALES (OFFLINE)
  // ---------------------------------------------
  Future<void> _loadLocalData() async {
    try {
      // Asumiendo que getEmpresas() y getGrupos() retornan List<Map<String, dynamic>>
      List<Map<String, dynamic>> localEmpresas = HiveHelper.getEmpresas();
      localEmpresas =
          localEmpresas.map((e) => Map<String, dynamic>.from(e)).toList();

      List<Map<String, dynamic>> localGrupos = HiveHelper.getGrupos();
      localGrupos =
          localGrupos.map((e) => Map<String, dynamic>.from(e)).toList();

      empresas = localEmpresas;
      grupos = localGrupos;
      gruposFiltrados = localGrupos;
      empresasFiltradas = localEmpresas;
    } catch (e) {
      print('Error loading local data: $e');
      empresas = [];
      grupos = [];
      empresasFiltradas = [];
      gruposFiltrados = [];
    }
  }

  // ---------------------------------------------
  // ACTUALIZA DATOS DESDE EL SERVIDOR
  // ---------------------------------------------
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

        // Si data no puede ser null, removemos ?? []
        List<dynamic> rawData = responseData['data'];
        List<Map<String, dynamic>> empresasData =
            rawData.map((e) => Map<String, dynamic>.from(e)).toList();

        Set<String> gruposUnicos = {};
        List<Map<String, dynamic>> gruposData = [];

        empresas.clear();
        empresasFiltradas.clear();
        grupos.clear();
        gruposFiltrados.clear();

        // Agrupamos según "grupo"
        for (var empresa in empresasData) {
          // Quitamos ?? '' si no puede ser null
          final grupoNombre = empresa['grupo'].toString();
          final grupoId = empresa['id_grupos'].toString();

          if (grupoNombre.isNotEmpty && grupoId.isNotEmpty) {
            if (!gruposUnicos.contains(grupoId)) {
              gruposUnicos.add(grupoId);
              gruposData.add({
                'id': grupoId,
                'nombre': grupoNombre,
              });
            }
          }
        }

        // Guardamos grupos y empresas en Hive
        await HiveHelper.insertGrupos(gruposData);
        gruposData =
            gruposData.map((g) => Map<String, dynamic>.from(g)).toList();
        grupos = gruposData;
        gruposFiltrados = gruposData;

        await HiveHelper.insertEmpresas(empresasData);
        empresasData =
            empresasData.map((e) => Map<String, dynamic>.from(e)).toList();
        empresas = empresasData;
        empresasFiltradas = empresasData;

        // Control de grupos expandibles
        _expandedGroups.clear();
        for (var g in grupos) {
          final gId = g['id']?.toString() ?? '';
          if (gId.isNotEmpty) {
            _expandedGroups[gId] = false;
          }
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
            _filterData();
          });
        }

        // Prefetch instalaciones en background
        _prefetchInstallationsInBackground();
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating server data: $e');
      _showErrorSnackBar('Error al actualizar datos del servidor');

      // Si falla, volvemos a cargar local
      await _loadLocalData();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _filterData();
        });
      }
    }
  }

  // ---------------------------------------------
  // PREFETCH DE INSTALACIONES (SINCRONIZA EN BG)
  // ---------------------------------------------
  Future<void> _prefetchInstallationsInBackground() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return;
    }

    List<Map<String, dynamic>> empresasSinInstalaciones = [];
    for (var empresa in empresas) {
      final eId = (empresa['id_empresas'] ?? '').toString();
      if (eId.isEmpty) continue;

      List<Map<String, dynamic>> instLocal = HiveHelper.getInstalaciones(eId);
      instLocal = instLocal.map((ee) => Map<String, dynamic>.from(ee)).toList();

      if (instLocal.isEmpty) {
        empresasSinInstalaciones.add(empresa);
      }
    }

    int batchSize = 5;
    for (int i = 0; i < empresasSinInstalaciones.length; i += batchSize) {
      final batch = empresasSinInstalaciones.skip(i).take(batchSize).toList();
      await Future.wait(
        batch.map((emp) {
          final eId = (emp['id_empresas'] ?? '').toString();
          return _fetchAndStoreInstalaciones(eId);
        }),
      );
    }
  }

  // Descarga e inserta instalaciones de una empresa específica
  Future<void> _fetchAndStoreInstalaciones(String empresaId) async {
    if (empresaId.isEmpty) return;

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
        final rawInst = responseData['data']['instalaciones'] ?? [];
        List<Map<String, dynamic>> instalacionesData = rawInst
            .map<Map<String, dynamic>>(
                (inst) => Map<String, dynamic>.from(inst))
            .toList();

        // Filtrar solo las que coincidan con la empresa
        instalacionesData = instalacionesData.where((inst) {
          return (inst['id_empresas']?.toString() ?? '') == empresaId;
        }).toList();

        if (instalacionesData.isNotEmpty) {
          await HiveHelper.insertInstalaciones(empresaId, instalacionesData);
        }
      }
    } catch (e) {
      print(
          'Error fetching installations in background for empresa $empresaId: $e');
    }
  }

  // ---------------------------------------------
  // WIDGETS DE UI
  // ---------------------------------------------
  Widget _buildTipoClienteBadge(String tipoCliente) {
    final text = (tipoCliente == 'directo') ? 'Integral' : 'Renting';
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
    return empresas.where((emp) {
      final empGrupoId = (emp['id_grupos'] ?? '').toString();
      final empGrupoName = (emp['grupo'] ?? '').toString().trim();
      return (empGrupoId == grupoId && empGrupoName.isNotEmpty);
    }).toList();
  }

  List<Map<String, dynamic>> _getEmpresasSinGrupo() {
    return empresas.where((emp) {
      final empGrupo = (emp['grupo'] ?? '').toString().trim();
      return empGrupo.isEmpty;
    }).toList();
  }

  // ---------------------------------------------
  // GUARDAR id_empresas EN HIVE (box: id_empresas2)
  // ---------------------------------------------
  Future<void> _saveIdEmpresasLocally(String idEmpresas) async {
    var box = await Hive.openBox('id_empresas2');
    await box.put('id_empresas_key', idEmpresas);
  }

  // ---------------------------------------------
  // BUILD
  // ---------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Filtra las empresas sin grupo que coincidan con la búsqueda
    List<Map<String, dynamic>> empresasSinGrupoFiltradas =
        _getEmpresasSinGrupo();
    if (_searchQuery.isNotEmpty) {
      empresasSinGrupoFiltradas = empresasSinGrupoFiltradas.where((empresa) {
        final nombre = (empresa['nombre'] ?? '').toString().toLowerCase();
        return nombre.startsWith(_searchQuery);
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
                          prefixIcon:
                              Icon(Icons.search, color: Color(0xFF363f77)),
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

                      // EMPRESAS SIN GRUPO
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

                      // Renderizamos las empresas sin grupo
                      for (var empresa in empresasSinGrupoFiltradas)
                        GestureDetector(
                          onTap: () async {
                            id_empresas =
                                (empresa['id_empresas'] ?? '').toString();
                            // Guardamos el id_empresas en el box "id_empresas2"
                            await _saveIdEmpresasLocally(id_empresas);

                            final String idEmpresaAsociada =
                                (empresa['id_empresa_asociada'] ?? '')
                                    .toString();

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LupaEmpresaScreen(
                                  empresa: empresa,
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
                                  // Reemplazamos withOpacity(0.05) => Color.fromRGBO(0,0,0,0.05)
                                  color: Color.fromRGBO(0, 0, 0, 0.05),
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
                                    (empresa['nombre'] ?? 'Empresa sin nombre')
                                        .toString(),
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 16,
                                      color: Colors.black,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                _buildTipoClienteBadge(
                                    empresa['tipo_cliente'] ?? ''),
                              ],
                            ),
                          ),
                        ),

                      SizedBox(height: 30),

                      // GRUPOS
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

                      // Renderizamos los grupos
                      for (var grupo in gruposFiltrados)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                final gId = (grupo['id'] ?? '').toString();
                                if (gId.isEmpty) return;

                                setState(() {
                                  _expandedGroups[gId] = !_expandedGroups[gId]!;
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
                                      color: Color.fromRGBO(0, 0, 0, 0.05),
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
                                        "Grupo ${grupo['nombre'] ?? 'Sin nombre'}",
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 16,
                                          color: Colors.black,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      (_expandedGroups[(grupo['id'] ?? '')
                                                  .toString()] ??
                                              false)
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Expandible: mostrará las empresas de este grupo
                            if (_expandedGroups[
                                    (grupo['id'] ?? '').toString()] ==
                                true)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 16, bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var emp in _getEmpresasDelGrupo(
                                        (grupo['id'] ?? '').toString()))
                                      GestureDetector(
                                        onTap: () async {
                                          id_empresas =
                                              (emp['id_empresas'] ?? '')
                                                  .toString();
                                          // Guardamos el id_empresas en el box "id_empresas2"
                                          await _saveIdEmpresasLocally(
                                              id_empresas);

                                          final String idEmpresaAsociada =
                                              (emp['id_empresa_asociada'] ?? '')
                                                  .toString();

                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  LupaEmpresaScreen(
                                                empresa: emp,
                                                bearerToken: bearerToken,
                                                idEmpresaAsociada:
                                                    idEmpresaAsociada,
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
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black,
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              _buildEmpresaAvatar(
                                                  emp['nombre']),
                                              SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  (emp['nombre'] ??
                                                          'Empresa sin nombre')
                                                      .toString(),
                                                  style: TextStyle(
                                                    fontFamily: 'Montserrat',
                                                    fontSize: 16,
                                                    color: Colors.black,
                                                    decoration:
                                                        TextDecoration.none,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              _buildTipoClienteBadge(
                                                  emp['tipo_cliente'] ?? ''),
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
