import 'package:flutter/material.dart';
import 'empresa_screen.dart'; // Asegúrate de que este archivo esté bien importado
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  final String bearerToken;
  final List<Map<String, dynamic>> empresas;

  HomeScreen({required this.bearerToken, required this.empresas});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showPendingMessages = false;

  @override
  void initState() {
    super.initState();
  }

  // Método para obtener las instalaciones de una empresa
  Future<void> getEmpresaDetails(String empresaId) async {
    // URL del endpoint
    String url = "https://www.infocontrol.com.ar/desarrollo_v2/api/mobile/empresas/empresasinstalaciones?id_empresas=$empresaId";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          HttpHeaders.contentTypeHeader: "application/json",
          HttpHeaders.authorizationHeader: "Bearer ${widget.bearerToken}",
          'auth-type': 'no-auth',  // Se asegura de que se manda 'no-auth'
        },
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);

        // Extraemos los nombres de las instalaciones de la respuesta
        List<String> nombresInstalaciones = [];
        if (responseData['data']['instalaciones'] != null) {
          for (var instalacion in responseData['data']['instalaciones']) {
            nombresInstalaciones.add(instalacion['nombre'].toString());  // Aseguramos que sea String
          }
        }

        // Ahora solo guardamos los nombres de las instalaciones
        // En este caso, solo se van a guardar los nombres en la lista
        setState(() {
          if (nombresInstalaciones.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmpresaScreen(
                  empresa: widget.empresas.firstWhere(
                    (empresa) => empresa['id_empresa_asociada'] == empresaId,
                  ),
                  instalaciones: nombresInstalaciones,  // Se pasa la lista de instalaciones
                ),
              ),
            );
          } else {
            print("No hay instalaciones disponibles.");
          }
        });
      } else {
        // Manejar error de solicitud si es necesario
        print('Error al obtener detalles de la empresa: ${response.statusCode}');
      }
    } catch (e) {
      // Manejar error de conexión si es necesario
      print('Error de conexión: $e');
    }
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
            children: [
              Spacer(),
              IconButton(
                icon: Icon(Icons.notifications, color: Color(0xFF2a3666)),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.message, color: Color(0xFF2a3666)),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.settings, color: Color(0xFF2a3666)),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.people, color: Color(0xFF2a3666)),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.info, color: Color(0xFF2a3666)),
                onPressed: () {},
              ),
              Container(
                height: 24,
                width: 1,
                color: Colors.grey[300],
                margin: EdgeInsets.symmetric(horizontal: 10),
              ),
              CircleAvatar(
                backgroundColor: Color(0xFF2a3666),
                radius: 15,
              ),
              SizedBox(width: 5),
              Icon(
                Icons.arrow_drop_down,
                color: Color(0xFF2a3666),
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
                        'Switach, Brian',
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
      body: SingleChildScrollView(
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
              for (var empresa in widget.empresas)
                GestureDetector(
                  onTap: () {
                    // Hacer la solicitud cuando se presione el nombre de la empresa
                    getEmpresaDetails(empresa['id_empresa_asociada']);
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
              for (int i = 0; i < 5; i++)
                Container(
                  margin: EdgeInsets.only(bottom: 12),
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
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
