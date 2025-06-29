import 'package:flutter/material.dart';
import './lupa_empresa.dart';
import 'hive_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import './home_screen.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class EmpresaScreen extends StatefulWidget {
  final String empresaId;
  final String bearerToken;
  final Map<String, dynamic> empresaData;

  EmpresaScreen({
    required this.empresaId,
    required this.bearerToken,
    required this.empresaData,
  });

  @override
  _EmpresaScreenState createState() => _EmpresaScreenState();
}

class _EmpresaScreenState extends State<EmpresaScreen> {
  List<Map<String, dynamic>> instalaciones = [];
  String empresaNombre = '';
  String empresaInicial = '';
  bool _isLoading = true;

  late Dio dio;
  late CookieJar cookieJar;

  @override
  void initState() {
    super.initState();
    cookieJar = CookieJar();
    dio = Dio();
    dio.interceptors.add(CookieManager(cookieJar));

    Map<String, dynamic> empresaData = widget.empresaData;
    if (empresaData.isNotEmpty) {
      empresaNombre = empresaData['nombre'] ?? 'Nombre de la empresa';
      empresaInicial =
          empresaNombre.isNotEmpty ? empresaNombre[0].toUpperCase() : 'E';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLoadingDialog();
      _loadEmpresaData();
    });
  }

  Future<void> _showLoadingDialog() async {
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
  }

  Future<void> _loadEmpresaData() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await _fetchInstalacionesFromServer();
    } else {
      _loadInstalacionesFromHive();
    }
  }

  Future<void> _fetchInstalacionesFromServer() async {
    try {
      final response = await dio.get(
        "https://www.infocontrol.tech/web/api/mobile/empresas/empresasinstalaciones?id_empresas=${widget.empresaId}",
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.bearerToken}',
            'auth-type': 'no-auth',
          },
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        List<Map<String, dynamic>> instalacionesData = [];

        if (responseData['data']['instalaciones'] != null) {
          instalacionesData = List<Map<String, dynamic>>.from(
              responseData['data']['instalaciones']
                  .map((inst) => Map<String, dynamic>.from(inst)));
        }

        instalacionesData = instalacionesData
            .where((inst) => inst['id_empresas'].toString() == widget.empresaId)
            .toList();

        await HiveHelper.insertInstalaciones(
            widget.empresaId, instalacionesData);

        setState(() {
          instalaciones = instalacionesData;
          _isLoading = false;
        });

        Navigator.pop(context);
      } else {
        _loadInstalacionesFromHive();
      }
    } catch (e) {
      _loadInstalacionesFromHive();
    }
  }

  void _loadInstalacionesFromHive() {
    List<Map<String, dynamic>> instalacionesData =
        HiveHelper.getInstalaciones(widget.empresaId);
    instalacionesData =
        instalacionesData.map((e) => Map<String, dynamic>.from(e)).toList();
    instalacionesData = instalacionesData
        .where((inst) => inst['id_empresas'].toString() == widget.empresaId)
        .toList();

    setState(() {
      instalaciones = instalacionesData;
      _isLoading = false;
    });

    Navigator.pop(context);
  }

  Widget _buildTipoClienteBadge(String tipoCliente) {
    final text = tipoCliente == 'directo' ? 'Integral' : 'Renting';
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFE2EAFB),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          color: Color(0xFF2a3666),
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.none,
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
          iconTheme: IconThemeData(color: Colors.black),
          actions: [
            IconButton(
              icon: Icon(Icons.search, color: Color(0xFF2a3666)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LupaEmpresaScreen(
                      empresa: widget.empresaData,
                      bearerToken: widget.bearerToken,
                      idEmpresaAsociada: widget.empresaId,
                      empresaId: widget.empresaId,
                      username: '',
                      password: '',
                    ),
                  ),
                );
              },
            ),
            Container(
              height: 24,
              width: 1,
              color: Colors.grey[300],
              margin: EdgeInsets.symmetric(horizontal: 10),
            ),
            CircleAvatar(
              backgroundColor: Color(0xFF232e63),
              radius: 15,
              child: Text(
                empresaInicial,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            SizedBox(width: 10),
          ],
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
                    SizedBox(height: 15),
                    CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      radius: 30,
                      child: Text(
                        empresaInicial,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 15),
                    Center(
                      child: Text(
                        empresaNombre,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 20,
                          color: Color(0xFF3d77e9),
                          decoration: TextDecoration.none,
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
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomeScreen(
                          bearerToken: widget.bearerToken,
                          empresas: [],
                          username: '',
                          password: '',
                          puedeEntrarLupa: false,
                        ),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
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
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
      body: Container(
        color: Color(0xFFF2F5FE),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Row(
                children: [
                  Icon(Icons.arrow_back, color: Color(0xFF9dbdfd)),
                  SizedBox(width: 8),
                  Text(
                    'Seleccionar contratista',
                    style: TextStyle(
                      color: Color(0xFF9dbdfd),
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  empresaNombre,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF232e5f),
                    decoration: TextDecoration.none,
                  ),
                ),
                _buildTipoClienteBadge(
                    widget.empresaData['tipo_cliente'] ?? ''),
              ],
            ),
            SizedBox(height: 30),
            Expanded(
              child: _isLoading
                  ? Container()
                  : (instalaciones.isNotEmpty
                      ? ListView.builder(
                          itemCount: instalaciones.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                instalaciones[index]['nombre'] ??
                                    'Nombre de la instalación',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 14,
                                  color: Colors.black,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            'No hay instalaciones disponibles.',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              color: Colors.black,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        )),
            ),
          ],
        ),
      ),
    );
  }
}
