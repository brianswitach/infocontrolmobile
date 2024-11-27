import 'package:flutter/material.dart';
import './lupa_empresa.dart';
import 'hive_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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

  @override
  void initState() {
    super.initState();
    _loadEmpresaData();
  }

  Future<void> _loadEmpresaData() async {
    // Obtener los datos de la empresa desde widget.empresaData
    Map<String, dynamic> empresaData = widget.empresaData;

    if (empresaData.isNotEmpty) {
      setState(() {
        empresaNombre = empresaData['nombre'] ?? 'Nombre de la empresa';
        empresaInicial = empresaNombre.isNotEmpty ? empresaNombre[0].toUpperCase() : 'E';
      });
    }

    // Obtener instalaciones desde Hive
    List<Map<String, dynamic>> instalacionesData =
        HiveHelper.getInstalaciones(widget.empresaId);

    setState(() {
      instalaciones = instalacionesData;
      _isLoading = false;
    });
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
                      empresaId: widget.empresaId,
                      bearerToken: widget.bearerToken,
                      idEmpresaAsociada: widget.empresaId,
                      empresa: widget.empresaData,
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
                ),
              ),
            ),
            SizedBox(width: 5),
            Icon(
              Icons.arrow_drop_down,
              color: Color(0xFF232e63),
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
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Text(
                  empresaNombre,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF232e5f),
                  ),
                ),
                SizedBox(width: 8),
                Image.asset(
                  'assets/integral_icon.png',
                  width: 100,
                ),
              ],
            ),
            SizedBox(height: 30),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : instalaciones.isNotEmpty
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
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}