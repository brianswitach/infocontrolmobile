import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      drawer: Drawer(
        child: Container(
          color: Color(0xFF232e5f), // Color de fondo único
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Encabezado del Drawer sin separación
              Container(
                color: Color(0xFF232e5f),
                padding: EdgeInsets.only(top: 20), // Ajuste superior del logo
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/infocontrol_logo.png',
                        width: 200, // Tamaño ajustado del logo
                      ),
                    ),
                    SizedBox(height: 25),
                    Center(
                      child: Text(
                        'Switach, Brian', // Nombre de usuario
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 20, // Tamaño de fuente ajustado
                          color: Color(0xFF3d77e9), // Color personalizado
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              // Botón Seleccionar Empresa
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
              // Opciones del Drawer sin línea divisoria
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
      body: Center(
        child: Text(
          'Home Screen Content',
          style: TextStyle(fontFamily: 'Montserrat', fontSize: 20),
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
