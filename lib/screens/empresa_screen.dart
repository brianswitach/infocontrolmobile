import 'package:flutter/material.dart';

class EmpresaScreen extends StatefulWidget {
  @override
  _EmpresaScreenState createState() => _EmpresaScreenState();
}

class _EmpresaScreenState extends State<EmpresaScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
        title: Text(
          'Detalles de la Empresa',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Montserrat',
          ),
        ),
        elevation: 0,
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
                    // Logo de InfoControl
                    Center(
                      child: Image.asset(
                        'assets/infocontrol_logo.png',
                        width: 200,
                      ),
                    ),
                    SizedBox(height: 15),
                    // Logo temporal de la empresa "BANCOR S.A." con la letra "B"
                    CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      radius: 30,
                      child: Text(
                        'B',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 15),
                    // Nombre del usuario
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
              // Opciones debajo de "Cambiar Empresa" eliminadas
            ],
          ),
        ),
      ),
      body: Center(
        child: Text(
          'Pantalla de detalles para BANCOR S.A.',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 20,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
